(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs. <contact@nomadic-labs.com>               *)
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

open Parameters

module Events = struct
  include Internal_event.Simple

  let section = ["octez_rpc_server"]

  let daemon_error =
    declare_1
      ~section
      ~name:"octez_rpc_server_daemon_error"
      ~msg:"Daemon thrown an error: {error}"
      ~level:Notice
      ~pp1:Error_monad.pp_print_trace
      ("error", Error_monad.trace_encoding)

  let new_head =
    declare_1
      ~section
      ~name:"new_head"
      ~msg:"New head received ({level})"
      ~level:Notice
      ("level", Data_encoding.int32)

  let synchronized =
    declare_2
      ~section
      ~name:"synchronized"
      ~msg:"Store synchronized up to level {level} ({hash})"
      ~level:Notice
      ("level", Data_encoding.int32)
      ~pp2:Block_hash.pp_short
      ("hash", Block_hash.encoding)
end

module Daemon = struct
  (** [make_stream_daemon handler streamed_call] calls [handler] on
      each newly received value from [streamed_call].

      It returns a couple [(p, stopper)] where [p] is a promise
      resolving when the stream closes and [stopper] a function
      closing the stream. *)
  let make_stream_daemon handle streamed_call =
    let open Lwt_result_syntax in
    let* stream, stopper = streamed_call in
    let rec go () =
      let*! tok = Lwt_stream.get stream in
      match tok with
      | None -> return_unit
      | Some element ->
          let*! r = handle stopper element in
          let*! () =
            match r with
            | Ok () -> Lwt.return_unit
            | Error trace ->
                let*! () = Events.(emit daemon_error) trace in
                Lwt.return_unit
          in
          go ()
    in
    return (go (), stopper)
end

let init_store ~allow_testchains ~readonly parameters =
  let open Lwt_result_syntax in
  (* Warning: the Store.init must be called after the Store.init
     of the node is finished.*)
  let store_dir = Data_version.store_dir parameters.data_dir in
  let context_dir = Data_version.context_dir parameters.data_dir in
  let* store =
    Store.init
      ?history_mode:parameters.history_mode
      ~store_dir
      ~context_dir
      ~allow_testchains
      ~readonly
      parameters.genesis
  in
  return store

let handle_new_head (dynamic_store : Store.t option ref) last_status parameters
    (watcher : (Block_hash.t * Block_header.t) Lwt_watcher.input) _stopper
    (block_hash, (header : Tezos_base.Block_header.t)) =
  let open Lwt_result_syntax in
  let block_level = header.shell.level in
  let*! () = Events.(emit new_head) block_level in
  let* () =
    match !dynamic_store with
    | Some store ->
        let* store, current_status, cleanups =
          Store.sync ~last_status:!last_status ~trigger_hash:block_hash store
        in
        last_status := current_status ;
        dynamic_store := Some store ;
        Lwt_watcher.notify watcher (block_hash, header) ;
        let*! () = cleanups () in
        let*! () = Events.(emit synchronized) (block_level, block_hash) in
        return_unit
    | None ->
        let* store =
          init_store ~allow_testchains:false ~readonly:true parameters
        in
        dynamic_store := Some store ;
        return_unit
  in
  return_unit

let init (dynamic_store : Store.t option ref) parameters
    (stream : (Block_hash.t * Block_header.t) Lwt_watcher.input) =
  let open Lwt_result_syntax in
  let ctx =
    Forward_handler.build_socket_redirection_ctx parameters.rpc_comm_socket_path
  in
  let module CustomRetryClient = struct
    include RPC_client_unix.RetryClient

    let call ?ctx:_ = call ~ctx
  end in
  let module Custom_rpc_client =
    RPC_client.Make (Resto_cohttp_client.Client.OfCohttp (CustomRetryClient)) in
  let rpc_config =
    Custom_rpc_client.
      {
        media_type = Media_type.Command_line.Any;
        endpoint = Uri.of_string Forward_handler.socket_forwarding_uri;
        logger = null_logger;
      }
  in
  let rpc_ctxt =
    new Custom_rpc_client.http_ctxt
      rpc_config
      (Media_type.Command_line.of_command_line rpc_config.media_type)
  in
  let store_dir = Data_version.store_dir parameters.data_dir in
  let store_directory = Naming.store_dir ~dir_path:store_dir in
  let chain_id = Chain_id.of_block_hash parameters.genesis.Genesis.block in
  let chain_dir = Naming.chain_dir store_directory chain_id in
  let status_file = Naming.block_store_status_file chain_dir in
  let* stored_status = Stored_data.load status_file in
  let*! initial_status = Stored_data.get stored_status in
  let* store = init_store ~allow_testchains:false ~readonly:true parameters in
  dynamic_store := Some store ;
  Daemon.make_stream_daemon
    (handle_new_head dynamic_store (ref initial_status) parameters stream)
    (Tezos_shell_services.Monitor_services.heads rpc_ctxt `Main)
