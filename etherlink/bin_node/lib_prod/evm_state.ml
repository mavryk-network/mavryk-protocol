(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

open Ethereum_types

module Bare_context = struct
  module Tree = Irmin_context.Tree

  type t = Irmin_context.rw

  type index = Irmin_context.rw_index

  type nonrec tree = Irmin_context.tree

  let init ?patch_context:_ ?readonly:_ ?index_log_size:_ path =
    let open Lwt_syntax in
    let* res = Irmin_context.load ~cache_size:100_000 Read_write path in
    match res with
    | Ok res -> return res
    | Error _ -> Lwt.fail_with "could not initialize the context"

  let empty index = Irmin_context.empty index
end

type t = Irmin_context.PVMState.value

module Wasm_utils =
  Wasm_utils.Make (Tezos_tree_encoding.Encodings_util.Make (Bare_context))
module Wasm = Wasm_debugger.Make (Wasm_utils)

let kernel_logs_directory ~data_dir = Filename.concat data_dir "kernel_logs"

let level_prefix = function
  | Events.Debug -> "[Debug]"
  | Info -> "[Info]"
  | Error -> "[Error]"
  | Fatal -> "[Fatal]"

let event_kernel_log ~kind ~msg =
  let is_level ~level msg =
    let prefix = level_prefix level in
    String.remove_prefix ~prefix msg |> Option.map (fun msg -> (level, msg))
  in
  let level_and_msg =
    Option.either_f (is_level ~level:Debug msg) @@ fun () ->
    Option.either_f (is_level ~level:Info msg) @@ fun () ->
    Option.either_f (is_level ~level:Error msg) @@ fun () ->
    is_level ~level:Fatal msg
  in
  Option.iter_s
    (fun (level, msg) -> Events.event_kernel_log ~level ~kind ~msg)
    level_and_msg

let execute ?(kind = Events.Application) ~data_dir ?(log_file = "kernel_log")
    ?(wasm_entrypoint = Tezos_scoru_wasm.Constants.wasm_entrypoint) ~config
    evm_state inbox =
  let open Lwt_result_syntax in
  let path = Filename.concat (kernel_logs_directory ~data_dir) log_file in
  let inbox = List.map (function `Input s -> s) inbox in
  let inbox = List.to_seq [inbox] in
  let messages = ref [] in
  let write_debug =
    Tezos_scoru_wasm.Builtins.Printer
      (fun msg ->
        messages := msg :: !messages ;
        event_kernel_log ~kind ~msg)
  in
  let* evm_state, _, _, _ =
    Wasm.Commands.eval
      ~write_debug
      ~wasm_entrypoint
      0l
      inbox
      config
      Inbox
      evm_state
  in
  (* The messages are accumulated during the execution and stored
     atomatically at the end to preserve their order. *)
  let*! () =
    Lwt_io.with_file
      ~flags:Unix.[O_WRONLY; O_CREAT; O_APPEND]
      ~perm:0o644
      ~mode:Output
      path
    @@ fun chan ->
    Lwt_io.atomic
      (fun chan ->
        let msgs = List.rev !messages in
        let*! () = List.iter_s (Lwt_io.write chan) msgs in
        Lwt_io.flush chan)
      chan
  in
  return evm_state

let modify ~key ~value evm_state = Wasm.set_durable_value evm_state key value

let flag_local_exec evm_state =
  modify evm_state ~key:Durable_storage_path.evm_node_flag ~value:""

let init ~kernel =
  let open Lwt_result_syntax in
  let evm_state = Irmin_context.PVMState.empty () in
  let* evm_state =
    Wasm.start ~tree:evm_state Tezos_scoru_wasm.Wasm_pvm_state.V3 kernel
  in
  let*! evm_state = flag_local_exec evm_state in
  return evm_state

let inspect evm_state key =
  let open Lwt_syntax in
  let key = Tezos_scoru_wasm.Durable.key_of_string_exn key in
  let* value = Wasm.Commands.find_key_in_durable evm_state key in
  Option.map_s Tezos_lazy_containers.Chunked_byte_vector.to_bytes value

let subkeys evm_state key =
  let open Lwt_syntax in
  let key = Tezos_scoru_wasm.Durable.key_of_string_exn key in
  let* durable = Wasm_utils.wrap_as_durable_storage evm_state in
  let durable = Tezos_scoru_wasm.Durable.of_storage_exn durable in
  Tezos_scoru_wasm.Durable.list durable key

let current_block_height evm_state =
  let open Lwt_syntax in
  let* current_block_number =
    inspect evm_state Durable_storage_path.Block.current_number
  in
  match current_block_number with
  | None ->
      (* No block has been created yet and we are waiting for genesis,
         whose number will be [zero]. Since the semantics of [apply_blueprint]
         is to verify the block height has been incremented once, we default to
         [-1]. *)
      return (Block_height Z.(pred zero))
  | Some current_block_number ->
      let (Qty current_block_number) = decode_number current_block_number in
      return (Block_height current_block_number)

let current_block_hash evm_state =
  let open Lwt_result_syntax in
  let*! current_hash =
    inspect evm_state Durable_storage_path.Block.current_hash
  in
  match current_hash with
  | Some h -> return (decode_block_hash h)
  | None -> return genesis_parent_hash

let execute_and_inspect ~data_dir ?wasm_entrypoint ~config
    ~input:
      Simulation.Encodings.
        {messages; insight_requests; log_kernel_debug_file; _} ctxt =
  let open Lwt_result_syntax in
  let keys =
    List.map
      (function
        | Simulation.Encodings.Durable_storage_key l ->
            "/" ^ String.concat "/" l
        (* We use only `Durable_storage_key` in simulation. *)
        | _ -> assert false)
      insight_requests
  in
  (* Messages from simulation requests are already valid inputs. *)
  let messages = List.map (fun s -> `Input s) messages in
  let* evm_state =
    execute
      ~kind:Simulation
      ?log_file:log_kernel_debug_file
      ~data_dir
      ?wasm_entrypoint
      ~config
      ctxt
      messages
  in
  let*! values = List.map_p (fun key -> inspect evm_state key) keys in
  return values

type apply_result =
  | Apply_success of t * block_height * block_hash
  | Apply_failure

let apply_blueprint ~data_dir ~config evm_state
    (blueprint : Blueprint_types.payload) =
  let open Lwt_result_syntax in
  let exec_inputs =
    List.map
      (function `External payload -> `Input ("\001" ^ payload))
      blueprint
  in
  let*! (Block_height before_height) = current_block_height evm_state in
  let* evm_state =
    execute
      ~data_dir
      ~wasm_entrypoint:Tezos_scoru_wasm.Constants.wasm_entrypoint
      ~config
      evm_state
      exec_inputs
  in
  let*! (Block_height after_height) = current_block_height evm_state in
  let* block_hash = current_block_hash evm_state in
  if Z.(equal (succ before_height) after_height) then
    return (Apply_success (evm_state, Block_height after_height, block_hash))
  else return Apply_failure

let clear_delayed_inbox evm_state =
  let open Lwt_syntax in
  let delayed_inbox_path =
    Tezos_scoru_wasm.Durable.key_of_string_exn
      Durable_storage_path.delayed_inbox
  in
  let* pvm_state =
    Wasm_utils.Ctx.Tree_encoding_runner.decode
      Tezos_scoru_wasm.Wasm_pvm.pvm_state_encoding
      evm_state
  in
  let* durable =
    Tezos_scoru_wasm.Durable.delete
      ~kind:Directory
      pvm_state.durable
      delayed_inbox_path
  in
  Wasm_utils.Ctx.Tree_encoding_runner.encode
    Tezos_scoru_wasm.Wasm_pvm.pvm_state_encoding
    {pvm_state with durable}
    evm_state
