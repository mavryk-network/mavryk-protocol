(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(*                                                                           *)
(*****************************************************************************)

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
  let* _head = check_head store context in
  (* Closing context and stores after checks *)
  let*! () = Context.close context in
  let* () = Store.close store in
  return_unit

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
    let* () = pre_export_checks ~data_dir in
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
