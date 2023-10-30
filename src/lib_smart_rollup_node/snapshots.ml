(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(*                                                                           *)
(*****************************************************************************)

module Tgz = Tar.Make (Gzip)

module type Reader = sig
  type in_channel

  val really_input : in_channel -> bytes -> int -> int -> unit

  val input : in_channel -> bytes -> int -> int -> int
end

module type Writer = sig
  type out_channel

  val output : out_channel -> bytes -> int -> int -> unit

  val close_out : out_channel -> unit
end

module Stdlib_reader : Reader with type in_channel = Stdlib.in_channel = Stdlib

module Stdlib_writer : Writer with type out_channel = Stdlib.out_channel =
  Stdlib

module Gzip_reader : Reader with type in_channel = Gzip.in_channel = Gzip

module Gzip_writer : Writer with type out_channel = Gzip.out_channel = Gzip

module Tgz_writer = Tar.Make (struct
  include Stdlib_reader
  include Gzip_writer
end)

module Tgz_reader = Tar.Make (struct
  include Gzip_reader
  include Stdlib_writer
end)

let check_store_version store_dir =
  let open Lwt_result_syntax in
  let* store_version = Store_version.read_version_file ~dir:store_dir in
  let*? () =
    match store_version with
    | None -> error_with "Unversionned store, cannot produce snapshot."
    | Some v when v <> Store.version ->
        error_with
          "Incompatible store version %a, expected %a. Cannot produce snapshot."
          Store_version.pp
          v
          Store_version.pp
          Store.version
    | Some _ -> Ok ()
  in
  return_unit

let check_head (store : _ Store.t) context =
  let open Lwt_result_syntax in
  let* head = Store.L2_head.read store.l2_head in
  let*? head =
    match head with
    | None ->
        error_with
          "There is no head in the rollup node store, cannot produce snapshot."
    | Some head -> Ok head
  in
  (* Ensure head context is available. *)
  let*! head_ctxt = Context.checkout context head.header.context in
  let*? _head_ctxt =
    match head_ctxt with
    | None ->
        error_with "Head context cannot be checkouted, won't produce snapshot."
    | Some head_ctxt -> Ok head_ctxt
  in
  return head

let pre_export_checks ~data_dir =
  let open Lwt_result_syntax in
  let store_dir = Configuration.default_storage_dir data_dir in
  let context_dir = Configuration.default_context_dir data_dir in
  (* Load context and stores in read-only to check they are valid. *)
  let* () = check_store_version store_dir in
  let* context = Context.load ~cache_size:1 Read_only context_dir in
  let* store =
    Store.load Read_only ~index_buffer_size:0 ~l2_blocks_cache_size:1 store_dir
  in
  let* head = check_head store context in
  (* Closing context and stores after checks *)
  let*! () = Context.close context in
  let* () = Store.close store in
  return head

let remove_operator_local_data (store : Store.rw) =
  let open Lwt_result_syntax in
  (* Remove LPC *)
  let* () = Store.Lpc.delete store.lpc in
  (* Delete commitments publication information.  *)
  Store.Commitments_published_at_level.gc
    ~async:false
    store.commitments_published_at_level
    (Retain [])

let first_available_level ~data_dir cctxt store =
  let open Lwt_result_syntax in
  let* gc_levels = Store.Gc_levels.read store.Store.gc_levels in
  match gc_levels with
  | Some {first_available_level; _} -> return first_available_level
  | None -> (
      let* {current_protocol; _} =
        Tezos_shell_services.Shell_services.Blocks.protocols
          cctxt
          ~block:(`Head 0)
          ()
      in
      let*? (module Plugin) =
        Protocol_plugins.proto_plugin_for_protocol current_protocol
      in
      let* metadata = Metadata.read_metadata_file ~dir:data_dir in
      match metadata with
      | None -> failwith "No metadata (needs rollup node address)."
      | Some {rollup_address; _} ->
          let+ {level; _} =
            Plugin.Layer1_helpers.retrieve_genesis_info cctxt rollup_address
          in
          level)

let check_l2_chain cctxt ~data_dir (store : Store.rw) context head =
  let open Lwt_result_syntax in
  let check_some hash what = function
    | Some x -> Ok x
    | None ->
        error_with
          "Could not read %s at %a after export."
          what
          Block_hash.pp
          hash
  in
  let* first_available_level = first_available_level cctxt ~data_dir store in
  let rec check_block hash =
    let* b = Store.L2_blocks.read store.l2_blocks hash in
    let*? _b, header = check_some hash "L2 block" b in
    let* messages = Store.Messages.read store.messages header.inbox_witness in
    let*? _messages = check_some hash "messages" messages in
    let* inbox = Store.Inboxes.read store.inboxes header.inbox_hash in
    let*? _inbox = check_some hash "inbox" inbox in
    let* () =
      match header.commitment_hash with
      | None -> return_unit
      | Some commitment_hash ->
          let* commitment =
            Store.Commitments.read store.commitments commitment_hash
          in
          let*? _commitment = check_some hash "commitment" commitment in
          return_unit
    in
    (* Ensure head context is available. *)
    let*! head_ctxt = Context.checkout context header.context in
    let*? _head_ctxt = check_some hash "context" head_ctxt in
    if header.level <= first_available_level then return_unit
    else check_block header.predecessor
  in
  check_block head

let post_export_checks cctxt ~dest =
  let open Lwt_result_syntax in
  let store_dir = Configuration.default_storage_dir dest in
  let context_dir = Configuration.default_context_dir dest in
  (* Load context and stores in read-write to run checks. *)
  let* () = check_store_version store_dir in
  let* context = Context.load ~cache_size:100 Read_write context_dir in
  let* store =
    Store.load
      Read_write
      ~index_buffer_size:1000
      ~l2_blocks_cache_size:100
      store_dir
  in
  let* () = remove_operator_local_data store in
  let* head = check_head store context in
  let* () =
    check_l2_chain cctxt ~data_dir:dest store context head.header.block_hash
  in
  let*! () = Context.close context in
  let* () = Store.close store in
  return_unit

let export cctxt ~data_dir ~dest =
  let open Lwt_result_syntax in
  let* () =
    Utils.with_lockfile (Node_context.gc_lockfile_path ~data_dir) @@ fun () ->
    (* Take GC lock first in order to not prevent progression of rollup node. *)
    Utils.with_lockfile (Node_context.processing_lockfile_path ~data_dir)
    @@ fun () ->
    let* _ = pre_export_checks ~data_dir in
    let store_dir = Configuration.default_storage_dir data_dir in
    let context_dir = Configuration.default_context_dir data_dir in
    let export_store_dir = Configuration.default_storage_dir dest in
    let export_context_dir = Configuration.default_context_dir dest in
    let*! () =
      let open Lwt_syntax in
      let* () = Lwt_utils_unix.create_dir dest in
      let* () = Lwt_utils_unix.create_dir store_dir in
      let* () = Lwt_utils_unix.create_dir context_dir in
      let* () = Lwt_utils_unix.copy_dir store_dir export_store_dir
      and* () = Lwt_utils_unix.copy_dir context_dir export_context_dir in
      let* () =
        Lwt_utils_unix.copy_file
          ~src:(Metadata.path ~dir:data_dir)
          ~dst:(Metadata.path ~dir:dest)
      in
      return_unit
    in
    return_unit
  in
  let* () = post_export_checks cctxt ~dest in
  return_unit

let list_files dir ~include_file f =
  let rec list stream dir prefix =
    let dh = Unix.opendir dir in
    let rec list_dir stream =
      match Unix.readdir dh with
      | "." | ".." -> list_dir stream
      | basename ->
          let file = Filename.concat dir basename in
          let file_base = Filename.concat prefix basename in
          let stream =
            if Sys.is_directory file then list stream file file_base
            else if include_file ~file ~file_base then
              Stream.icons (f ~file ~file_base) stream
            else stream
          in
          list_dir stream
      | exception End_of_file ->
          Unix.closedir dh ;
          stream
    in
    list_dir stream
  in
  list Stream.sempty dir ""

let write_file_to_compressed file (out_chan : Gzip.out_channel) =
  let fd = Unix.openfile file [O_RDONLY] 0o755 in
  let buffer_size = 128 * 1024 in
  let buf = Bytes.create buffer_size in
  let rec copy () =
    let read_bytes = Unix.read fd buf 0 buffer_size in
    Gzip.output out_chan buf 0 read_bytes ;
    if read_bytes >= buffer_size then copy ()
  in
  copy () ;
  Gzip.flush_continue out_chan ;
  Unix.close fd

let export_files_tgz dir ~include_file ~dest =
  let file_stream =
    list_files dir ~include_file @@ fun ~file ~file_base ->
    let {Unix.st_perm; st_size; st_mtime; _} = Unix.lstat file in
    let header =
      Tar.Header.make
        ~file_mode:st_perm
        ~mod_time:(Int64.of_float st_mtime)
        file_base
        (Int64.of_int st_size)
    in
    let writer = write_file_to_compressed file in
    (header, writer)
  in
  let out_chan = Gzip.open_out dest in
  Tgz_writer.Archive.create_gen file_stream out_chan ;
  Gzip.close_out out_chan

let operator_local_file_regexp =
  Re.Str.regexp "^storage/\\(commitments_published_at_level.*\\|lpc$\\)"

let snapshotable_files_regexp =
  Re.Str.regexp "^\\(storage/.*\\|context/.*\\|metadata$\\)"

let rec create_dir ?(perm = 0o755) dir =
  let stat =
    try Some (Unix.stat dir) with Unix.Unix_error (ENOENT, _, _) -> None
  in
  match stat with
  | Some {st_kind = S_DIR; _} -> ()
  | Some _ -> Stdlib.failwith "Not a directory"
  | None -> (
      create_dir ~perm (Filename.dirname dir) ;
      try Unix.mkdir dir perm
      with Unix.Unix_error (EEXIST, _, _) ->
        (* This is the case where the directory has been created at the same
           time. *)
        ())

let cpt = ref 0

let out_channel_of_header ~data_dir (header : Tar.Header.t) =
  incr cpt ;
  let dest = Filename.concat data_dir header.file_name in
  create_dir (Filename.dirname dest) ;
  Stdlib.open_out_gen
    [Open_wronly; Open_trunc; Open_creat; Open_binary]
    header.file_mode
    dest

let import_tgz ~data_dir ~snapshot_file =
  let in_chan = Gzip.open_in snapshot_file in
  Tgz_reader.Archive.extract_gen (out_channel_of_header ~data_dir) in_chan ;
  Gzip.close_in in_chan

let post_export_tgz_checks cctxt ~snapshot_file =
  Lwt_utils_unix.with_tempdir "snapshot_checks" @@ fun dest ->
  let open Lwt_result_syntax in
  let*! () = Lwt_utils_unix.create_dir dest in
  import_tgz ~data_dir:dest ~snapshot_file ;
  post_export_checks cctxt ~dest

let export_tgz cctxt ~data_dir ~dest =
  let open Lwt_result_syntax in
  let* dest_tgz =
    Utils.with_lockfile (Node_context.gc_lockfile_path ~data_dir) @@ fun () ->
    (* Take GC lock first in order to not prevent progression of rollup node. *)
    Utils.with_lockfile (Node_context.processing_lockfile_path ~data_dir)
    @@ fun () ->
    let* head = pre_export_checks ~data_dir in
    let dest_tgz =
      Filename.concat dest
      @@ Format.asprintf
           "snapshot-%ld-%a.tgz"
           head.header.level
           Block_hash.pp
           head.header.block_hash
    in
    let*! () =
      let open Lwt_syntax in
      let* () = Lwt_utils_unix.create_dir dest in
      let include_file ~file:_ ~file_base =
        Re.Str.string_match snapshotable_files_regexp file_base 0
        && not (Re.Str.string_match operator_local_file_regexp file_base 0)
      in
      export_files_tgz data_dir ~include_file ~dest:dest_tgz ;
      return_unit
    in
    return dest_tgz
  in
  Format.eprintf "Checking snapshot@." ;
  let* () = post_export_tgz_checks cctxt ~snapshot_file:dest_tgz in
  return dest_tgz
