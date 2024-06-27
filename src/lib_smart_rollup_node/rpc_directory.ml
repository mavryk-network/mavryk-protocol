(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs, <contact@nomadic-labs.com>               *)
(* Copyright (c) 2022-2023 TriliTech <contact@trili.tech>                    *)
(* Copyright (c) 2023 Functori, <contact@functori.com>                       *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

open Rpc_directory_helpers

(* Add extra services which must live in the rollup node library *)
module Rollup_node_services = struct
  include Rollup_node_services

  module Root = struct
    include Root

    let config =
      Mavryk_rpc.Service.get_service
        ~description:"Returns the rollup node configuration"
        ~query:Mavryk_rpc.Query.empty
        ~output:Configuration.encoding_no_default
        Mavryk_rpc.Path.(root / "config")
  end
end

let get_head_hash_opt node_ctxt =
  let open Lwt_result_syntax in
  let+ res = Node_context.last_processed_head_opt node_ctxt in
  Option.map
    (fun Sc_rollup_block.{header = {block_hash; _}; _} -> block_hash)
    res

let get_head_level_opt node_ctxt =
  let open Lwt_result_syntax in
  let+ res = Node_context.last_processed_head_opt node_ctxt in
  Option.map (fun Sc_rollup_block.{header = {level; _}; _} -> level) res

module Root_directory = Make_directory (struct
  include Rollup_node_services.Root

  type context = Node_context.rw

  type subcontext = Node_context.ro

  let context_of_prefix node_ctxt () =
    Lwt_result.return (Node_context.readonly node_ctxt)
end)

module Global_directory = Make_directory (struct
  include Rollup_node_services.Global

  type context = Node_context.rw

  type subcontext = Node_context.ro

  let context_of_prefix node_ctxt () =
    Lwt_result.return (Node_context.readonly node_ctxt)
end)

module Local_directory = Make_directory (struct
  include Rollup_node_services.Local

  type context = Node_context.rw

  type subcontext = Node_context.ro

  let context_of_prefix node_ctxt () =
    Lwt_result.return (Node_context.readonly node_ctxt)
end)

module Admin_directory = Make_directory (struct
  include Rollup_node_services.Admin

  type context = Node_context.rw

  type subcontext = Node_context.ro

  let context_of_prefix node_ctxt () =
    Lwt_result.return (Node_context.readonly node_ctxt)
end)

let () =
  Root_directory.register0 Rollup_node_services.Root.health
  @@ fun _node_ctxt () () -> Lwt_result_syntax.return_unit

let () =
  Root_directory.register0 Rollup_node_services.Root.version
  @@ fun _node_ctxt () () ->
  let open Lwt_result_syntax in
  let version =
    Mavryk_version.Version.to_string
      Mavryk_version_value.Current_git_info.mavkit_version
  in
  let store_version = Format.asprintf "%a" Store_version.pp Store.version in
  let context_version = Context.Version.(to_string version) in
  return Rollup_node_services.{version; store_version; context_version}

let () =
  Root_directory.register0 Rollup_node_services.Root.config
  @@ fun node_ctxt () () ->
  let open Lwt_result_syntax in
  let+ history_mode = Node_context.get_history_mode node_ctxt in
  {node_ctxt.config with history_mode = Some history_mode}

let () =
  Root_directory.register0 Rollup_node_services.Root.ocaml_gc
  @@ fun _node_ctxt () () -> Lwt_result_syntax.return @@ Gc.stat ()

let () =
  Root_directory.register0 Rollup_node_services.Root.memory
  @@ fun _node_ctxt () () ->
  let open Lwt_result_syntax in
  Sys_info.memory_stats () |> lwt_map_error TzTrace.make

let () =
  Global_directory.register0 Rollup_node_services.Global.sc_rollup_address
  @@ fun node_ctxt () () -> Lwt_result.return node_ctxt.config.sc_rollup_address

let () =
  Global_directory.register0 Rollup_node_services.Global.current_mavryk_head
  @@ fun node_ctxt () () -> get_head_hash_opt node_ctxt

let () =
  Global_directory.register0 Rollup_node_services.Global.current_mavryk_level
  @@ fun node_ctxt () () -> get_head_level_opt node_ctxt

let () =
  Global_directory.register0 Rollup_node_services.Global.last_stored_commitment
  @@ fun node_ctxt () () ->
  let open Lwt_result_syntax in
  let* head = Node_context.last_processed_head_opt node_ctxt in
  match head with
  | None -> return_none
  | Some head ->
      let commitment_hash =
        Sc_rollup_block.most_recent_commitment head.header
      in
      let+ commitment =
        Node_context.find_commitment node_ctxt commitment_hash
      in
      Option.map (fun c -> (c, commitment_hash)) commitment

(* Sets up a block watching service. It creates a stream to
   observe block events and asynchronously fetches the next
   block when available *)
let create_block_watcher_service (node_ctxt : _ Node_context.t) =
  let open Lwt_syntax in
  (* input source block creating a stream to observe the events *)
  let block_stream, stopper =
    Lwt_watcher.create_stream node_ctxt.global_block_watcher
  in
  let* head = Node_context.last_processed_head_opt node_ctxt in
  let shutdown () = Lwt_watcher.shutdown stopper in
  (* generate the next asynchronous event *)
  let next =
    let first_call = ref true in
    fun () ->
      if !first_call then (
        first_call := false ;
        return (Result.to_option head |> Option.join))
      else Lwt_stream.get block_stream
  in
  Mavryk_rpc.Answer.return_stream {next; shutdown}

let () =
  Global_directory.gen_register0
    Rollup_node_services.Global.global_block_watcher
  @@ fun node_ctxt () () -> create_block_watcher_service node_ctxt

let () =
  Local_directory.gen_register0
    Rollup_node_services.Local.synchronized
    (fun node_ctxt () () ->
      let open Lwt_syntax in
      let levels_stream, stopper =
        Lwt_watcher.create_stream node_ctxt.sync.sync_level_input
      in
      let first_call = ref true in
      let synced = ref false in
      let initial_processed_level = ref None in
      let get_percentage processed_mavryk_level known_mavryk_level =
        let initial =
          match !initial_processed_level with
          | Some l -> l
          | None ->
              initial_processed_level := Some processed_mavryk_level ;
              processed_mavryk_level
        in
        let total = Int32.sub known_mavryk_level initial in
        let done_ = Int32.sub processed_mavryk_level initial in
        Int32.to_float done_ *. 100. /. Int32.to_float total
      in
      let next () =
        if !synced then Lwt.return_none
        else
          let levels =
            let+ processed_level =
              if !first_call then (
                first_call := false ;
                Lwt.return_some node_ctxt.sync.processed_level)
              else Lwt_stream.get levels_stream
            in
            let l1_head = Layer1.get_latest_head node_ctxt.l1_ctxt in
            match (processed_level, l1_head) with
            | None, _ | _, None ->
                synced := true ;
                Rollup_node_services.Synchronized
            | Some processed_level, Some l1_head
              when processed_level = l1_head.level ->
                synced := true ;
                Rollup_node_services.Synchronized
            | Some processed_level, Some l1_head ->
                Synchronizing
                  {
                    processed_level;
                    l1_head_level = l1_head.level;
                    percentage_done =
                      get_percentage processed_level l1_head.level;
                  }
          in
          let synchronized =
            let+ () = Node_context.wait_synchronized node_ctxt in
            synced := true ;
            Rollup_node_services.Synchronized
          in
          let+ result = Lwt.pick [levels; synchronized] in
          Some result
      in
      let shutdown () = Lwt_watcher.shutdown stopper in
      Mavryk_rpc.Answer.return_stream {next; shutdown})

let () =
  Local_directory.register0 Rollup_node_services.Local.last_published_commitment
  @@ fun node_ctxt () () ->
  let open Lwt_result_syntax in
  match Reference.get node_ctxt.lpc with
  | None -> return_none
  | Some commitment ->
      let hash = Mavkit_smart_rollup.Commitment.hash commitment in
      (* The corresponding level in Store.Commitments.published_at_level is
         available only when the commitment has been published and included
         in a block. *)
      let* published_at_level_info =
        Node_context.commitment_published_at_level node_ctxt hash
      in
      let first_published, published =
        match published_at_level_info with
        | None -> (None, None)
        | Some {first_published_at_level; published_at_level} ->
            (Some first_published_at_level, published_at_level)
      in
      return_some (commitment, hash, first_published, published)

let () =
  Local_directory.register1 Rollup_node_services.Local.commitment
  @@ fun node_ctxt commitment_hash () () ->
  let open Lwt_result_syntax in
  let* commitment = Node_context.find_commitment node_ctxt commitment_hash in
  match commitment with
  | None -> return_none
  | Some commitment ->
      let hash = Mavkit_smart_rollup.Commitment.hash commitment in
      (* The corresponding level in Store.Commitments.published_at_level is
         available only when the commitment has been published and included
         in a block. *)
      let* published_at_level_info =
        Node_context.commitment_published_at_level node_ctxt hash
      in
      let first_published, published =
        match published_at_level_info with
        | None -> (None, None)
        | Some {first_published_at_level; published_at_level} ->
            (Some first_published_at_level, published_at_level)
      in
      return_some (commitment, hash, first_published, published)

let () =
  Local_directory.register0 Rollup_node_services.Local.gc_info
  @@ fun node_ctxt () () ->
  let open Lwt_result_syntax in
  let* {last_gc_level; first_available_level} =
    Node_context.get_gc_levels node_ctxt
  and* last_context_split_level =
    Node_context.get_last_context_split_level node_ctxt
  in
  return
    Rollup_node_services.
      {last_gc_level; first_available_level; last_context_split_level}

let () =
  Local_directory.register0 Rollup_node_services.Local.injection
  @@ fun _node_ctxt () messages -> Batcher.register_messages messages

let () =
  Local_directory.register0 Rollup_node_services.Local.batcher_queue
  @@ fun _node_ctxt () () ->
  let open Lwt_result_syntax in
  let*? queue = Batcher.get_queue () in
  return queue

(** [commitment_level_of_inbox_level node_ctxt inbox_level] returns the level
      of the commitment which should include the inbox of level
      [inbox_level].

      It is computed with the following formula:
      {v
      commitment_level(inbox_level) =
        last_commitment -
         ((last_commitment - inbox_level) / commitment_period
          * commitment_period)
      v}
*)
let commitment_level_of_inbox_level (node_ctxt : _ Node_context.t) inbox_level =
  let open Lwt_result_syntax in
  let last_published_commitment = Reference.get node_ctxt.lpc in
  let+ constants =
    Protocol_plugins.get_constants_of_level node_ctxt inbox_level
  in
  let commitment_period =
    Int32.of_int constants.sc_rollup.commitment_period_in_blocks
  in
  Option.map
    (fun last_published_commitment ->
      (* TODO: https://gitlab.com/mavryk/mavryk/-/issues/6246
         fix and test last_published_inbox_level in RPC dir. *)
      let last_published = last_published_commitment.Commitment.inbox_level in
      let open Int32 in
      div (sub last_published inbox_level) commitment_period
      |> mul commitment_period |> sub last_published)
    last_published_commitment

let inbox_info_of_level (node_ctxt : _ Node_context.t) inbox_level =
  let open Lwt_result_syntax in
  let+ finalized_level = Node_context.get_finalized_level node_ctxt in
  let finalized = Compare.Int32.(inbox_level <= finalized_level) in
  let lcc = Reference.get node_ctxt.lcc in
  let cemented = Compare.Int32.(inbox_level <= lcc.level) in
  (finalized, cemented)

let () =
  Local_directory.register1 Rollup_node_services.Local.batcher_message
  @@ fun node_ctxt hash () () ->
  let open Lwt_result_syntax in
  let*? batch_status = Batcher.message_status hash in
  let* status =
    match batch_status with
    | None -> return (None, Rollup_node_services.Unknown)
    | Some (batch_status, msg) -> (
        let return status = return (Some msg, status) in
        match batch_status with
        | Pending_batch -> return Rollup_node_services.Pending_batch
        | Batched l1_hash -> (
            match Injector.operation_status l1_hash with
            | None -> return Rollup_node_services.Unknown
            | Some (Pending op) ->
                return (Rollup_node_services.Pending_injection op)
            | Some (Injected {op; oph; op_index}) ->
                return
                  (Rollup_node_services.Injected
                     {op = op.operation; oph; op_index})
            | Some (Included {op; oph; op_index; l1_block; l1_level}) -> (
                let* finalized, cemented =
                  inbox_info_of_level node_ctxt l1_level
                in
                let* commitment_level =
                  commitment_level_of_inbox_level node_ctxt l1_level
                in
                match commitment_level with
                | None ->
                    return
                      (Rollup_node_services.Included
                         {
                           op = op.operation;
                           oph;
                           op_index;
                           l1_block;
                           l1_level;
                           finalized;
                           cemented;
                         })
                | Some commitment_level -> (
                    let* block =
                      Node_context.find_l2_block_by_level
                        node_ctxt
                        commitment_level
                    in
                    match block with
                    | None ->
                        (* Commitment not computed yet for inbox *)
                        return
                          (Rollup_node_services.Included
                             {
                               op = op.operation;
                               oph;
                               op_index;
                               l1_block;
                               l1_level;
                               finalized;
                               cemented;
                             })
                    | Some block -> (
                        let commitment_hash =
                          WithExceptions.Option.get
                            ~loc:__LOC__
                            block.header.commitment_hash
                        in
                        (* Commitment computed *)
                        let* published_at =
                          Node_context.commitment_published_at_level
                            node_ctxt
                            commitment_hash
                        in
                        match published_at with
                        | None | Some {published_at_level = None; _} ->
                            (* Commitment not published yet *)
                            return
                              (Rollup_node_services.Included
                                 {
                                   op = op.operation;
                                   oph;
                                   op_index;
                                   l1_block;
                                   l1_level;
                                   finalized;
                                   cemented;
                                 })
                        | Some
                            {
                              first_published_at_level;
                              published_at_level = Some published_at_level;
                            } ->
                            (* Commitment published *)
                            let* commitment =
                              Node_context.get_commitment
                                node_ctxt
                                commitment_hash
                            in
                            return
                              (Rollup_node_services.Committed
                                 {
                                   op = op.operation;
                                   oph;
                                   op_index;
                                   l1_block;
                                   l1_level;
                                   finalized;
                                   cemented;
                                   commitment;
                                   commitment_hash;
                                   first_published_at_level;
                                   published_at_level;
                                 }))))))
  in

  return status

let () =
  Admin_directory.register0 Rollup_node_services.Admin.injector_queues_total
  @@ fun _node_ctxt () () ->
  let open Lwt_result_syntax in
  let totals = Injector.total_queued_operations () in
  return totals

let () =
  Admin_directory.register0 Rollup_node_services.Admin.injector_queues
  @@ fun _node_ctxt tag () ->
  let open Lwt_result_syntax in
  let queues = Injector.get_queues ?tag () in
  let queues =
    List.map
      (fun (tags, ops) ->
        let rops =
          List.rev_map
            (fun Injector.Inj_operation.
                   {operation = op; errors = {count; last_error}; id = _} ->
              Rollup_node_services.{op; errors = count; last_error})
            ops
        in
        (tags, List.rev rops))
      queues
  in
  return queues

let () =
  Admin_directory.register0 Rollup_node_services.Admin.clear_injector_queues
  @@ fun _node_ctxt tag () -> Injector.clear_queues ?tag ()

let add_describe dir =
  Mavryk_rpc.Directory.register_describe_directory_service
    dir
    Mavryk_rpc.Service.description_service

let top_directory (node_ctxt : _ Node_context.t) =
  List.fold_left
    (fun dir f -> Mavryk_rpc.Directory.merge dir (f node_ctxt))
    Mavryk_rpc.Directory.empty
    [
      Root_directory.build_directory;
      Global_directory.build_directory;
      Local_directory.build_directory;
      Admin_directory.build_directory;
    ]

let block_prefix =
  Mavryk_rpc.Path.(
    open_root / "global" / "block" /: Rollup_node_services.Arg.block_id)

let protocol_directories = Protocol_hash.Table.create 3

let build_protocol_directory node_ctxt proto =
  let plugin =
    match Protocol_plugins.proto_plugin_for_protocol proto with
    | Error e ->
        Format.kasprintf
          Stdlib.failwith
          "Cannot build RPC directory for %a.\n%a"
          Protocol_hash.pp
          proto
          pp_print_trace
          e
    | Ok p -> p
  in
  let (module Plugin) = plugin in
  let block_directory = Plugin.RPC_directory.block_directory node_ctxt in
  let full_static_dir =
    Mavryk_rpc.Directory.merge
      (top_directory node_ctxt)
      (Mavryk_rpc.Directory.prefix block_prefix block_directory)
    |> add_describe
  in
  Protocol_hash.Table.replace
    protocol_directories
    proto
    (block_directory, full_static_dir) ;
  (block_directory, full_static_dir)

let build_protocol_directories node_ctxt =
  List.iter
    (fun p -> ignore (build_protocol_directory node_ctxt p))
    (Protocol_plugins.registered_protocols ())

let get_proto_dir ?protocol (node_ctxt : _ Node_context.t) =
  let current_protocol = Reference.get node_ctxt.current_protocol in
  let proto = Option.value protocol ~default:current_protocol.hash in
  match Protocol_hash.Table.find protocol_directories proto with
  | None -> error_with "Unknown protocol %a" Protocol_hash.pp proto
  | Some (block_dir, full_dir) -> Ok (block_dir, full_dir, proto)

let generate_openapi dir proto =
  let open Lwt_result_syntax in
  let*! descr =
    Mavryk_rpc.Directory.describe_directory ~recurse:true ~arg:() dir
  in
  let json_api =
    Data_encoding.Json.construct
      Mavryk_rpc.Encoding.description_answer_encoding
      descr
  in
  let open Mavryk_openapi in
  json_api
  |> Json.annotate ~origin:"description"
  |> Api.parse_tree |> Api.parse_services |> Api.flatten
  |> Convert.convert_api
       ~title:"Smart Rollup Node RPCs"
       ~description:
         (Format.asprintf
            "Smart Rollup Node RPC API for protocol %a"
            Protocol_hash.pp
            proto)
       Mavryk_version_value.Bin_version.mavkit_simple_version_string
  |> Openapi.to_json |> return

let () =
  Root_directory.register0 Rollup_node_services.Root.openapi
  @@ fun node_ctxt {protocol} () ->
  let open Lwt_result_syntax in
  let*? _, dir, proto = get_proto_dir ?protocol node_ctxt in
  generate_openapi dir proto

let directory node_ctxt =
  let dir = top_directory node_ctxt in
  build_protocol_directories node_ctxt ;
  let path =
    Mavryk_rpc.Path.(
      open_root / "global" / "block" /: Rollup_node_services.Arg.block_id)
  in
  let dir =
    Mavryk_rpc.Directory.register_dynamic_directory
      ~descr:"Dynamic protocol specific RPC directory for the rollup node"
      dir
      path
      (fun ((), block_id) ->
        let open Lwt_syntax in
        let+ dir =
          let open Lwt_result_syntax in
          let* level =
            Block_directory_helpers.block_level_of_id node_ctxt block_id
          in
          let* () = Node_context.check_level_available node_ctxt level in
          let* proto = Node_context.protocol_of_level node_ctxt level in
          let*? block_directory, _, _ =
            get_proto_dir ~protocol:proto.protocol node_ctxt
          in
          return block_directory
        in
        match dir with
        | Ok dir -> dir
        | Error e ->
            Format.kasprintf
              Stdlib.failwith
              "Could not load block directory for block %s: %a"
              (Rollup_node_services.Arg.construct_block_id block_id)
              pp_print_trace
              e)
  in
  add_describe dir

let generate_openapi ?protocol cctxt =
  let open Lwt_result_syntax in
  let protocol =
    Option.value_f protocol ~default:Protocol_plugins.last_registered
  in
  let* node_ctxt =
    Node_context_loader.Internal_for_tests.openapi_context cctxt protocol
  in
  let _, dir = build_protocol_directory node_ctxt protocol in
  generate_openapi dir protocol
