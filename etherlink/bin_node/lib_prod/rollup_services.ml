(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(* Copyright (c) 2023 Trilitech <contact@trili.tech>                         *)
(*                                                                           *)
(*****************************************************************************)

(* TODO: https://gitlab.com/tezos/tezos/-/issues/6953

   Make the sequencer node resilient to rollup node disconnect.

   RPC failures makes the sequencer stop or maybe fails to parse
   specific element.
*)

open Mavryk_rpc
open Path

type error += Lost_connection

let () =
  let description =
    "The EVM node is no longer able to communicate with the rollup node, the \
     communication was lost"
  in
  register_error_kind
    `Temporary
    ~id:"evm_node_prod_lost_connection"
    ~title:"Lost connection with rollup node"
    ~description
    ~pp:(fun ppf () -> Format.fprintf ppf "%s" description)
    Data_encoding.unit
    (function Lost_connection -> Some () | _ -> None)
    (fun () -> Lost_connection)

let is_connection_error trace =
  TzTrace.fold
    (fun yes error ->
      yes
      ||
      match error with
      | RPC_client_errors.(Request_failed {error = Connection_failed _; _}) ->
          true
      | _ -> false)
    false
    trace

let smart_rollup_address :
    ([`GET], unit, unit, unit, unit, bytes) Service.service =
  Service.get_service
    ~description:"Smart rollup address"
    ~query:Query.empty
    ~output:(Data_encoding.Fixed.bytes 20)
    (open_root / "global" / "smart_rollup_address")

let gc_info_encoding =
  Data_encoding.(
    obj3
      (req "last_gc_level" int32)
      (req "first_available_level" int32)
      (opt "last_context_split_level" int32))

let gc_info :
    ( [`GET],
      unit,
      unit,
      unit,
      unit,
      int32 * int32 * int32 option )
    Service.service =
  Service.get_service
    ~description:"Smart rollup address"
    ~query:Query.empty
    ~output:gc_info_encoding
    (open_root / "local" / "gc_info")

type state_value_query = {key : string}

module Block_id = struct
  type t = Head | Level of Int32.t

  let construct = function
    | Head -> "head"
    | Level level -> Int32.to_string level

  let destruct id =
    match id with
    | "head" -> Ok Head
    | n -> (
        match Int32.of_string_opt n with
        | Some n -> Ok (Level n)
        | None -> Error "Cannot parse block id")

  let arg : t Mavryk_rpc.Arg.t =
    Mavryk_rpc.Arg.make
      ~descr:"An L1 block identifier."
      ~name:"block_id"
      ~construct
      ~destruct
      ()
end

let state_value_query : state_value_query Mavryk_rpc.Query.t =
  let open Mavryk_rpc.Query in
  query (fun key -> {key})
  |+ field "key" Mavryk_rpc.Arg.string "" (fun t -> t.key)
  |> seal

let durable_state_value :
    ( [`GET],
      unit,
      unit * Block_id.t,
      state_value_query,
      unit,
      bytes option )
    Service.service =
  Mavryk_rpc.Service.get_service
    ~description:
      "Retrieve value by key from PVM durable storage. PVM state is taken with \
       respect to the specified block level. Value returned in hex format."
    ~query:state_value_query
    ~output:Data_encoding.(option bytes)
    (open_root / "global" / "block" /: Block_id.arg / "durable" / "wasm_2_0_0"
   / "value")

let batcher_injection :
    ([`POST], unit, unit, unit, string trace, string trace) Service.service =
  Mavryk_rpc.Service.post_service
    ~description:"Inject messages in the batcher's queue"
    ~query:Mavryk_rpc.Query.empty
    ~input:
      Data_encoding.(
        def "messages" ~description:"Messages to inject" (list (string' Hex)))
    ~output:
      Data_encoding.(
        def
          "message_ids"
          ~description:"Ids of injected L2 messages"
          (list string))
    (open_root / "local" / "batcher" / "injection")

let simulation :
    ( [`POST],
      unit,
      unit,
      unit,
      Simulation.Encodings.simulate_input,
      Data_encoding.json )
    Service.service =
  Mavryk_rpc.Service.post_service
    ~description:
      "Simulate messages evaluation by the PVM, and find result in durable \
       storage"
    ~query:Mavryk_rpc.Query.empty
    ~input:Simulation.Encodings.simulate_input
    ~output:Data_encoding.Json.encoding
    (open_root / "global" / "block" / "head" / "simulate")

let global_block_watcher :
    ([`GET], unit, unit, unit, unit, Sc_rollup_block.t) Service.service =
  Mavryk_rpc.Service.get_service
    ~description:"Monitor and streaming the L2 blocks"
    ~query:Mavryk_rpc.Query.empty
    ~output:Sc_rollup_block.encoding
    (open_root / "global" / "monitor_blocks")

let global_current_mavryk_level :
    ([`GET], unit, unit, unit, unit, int32 option) Service.service =
  Mavryk_rpc.Service.get_service
    ~description:"Current mavryk level of the rollup node"
    ~query:Mavryk_rpc.Query.empty
    ~output:Data_encoding.(option int32)
    (open_root / "global" / "mavryk_level")

let call_service ~base ?(media_types = Media_type.all_media_types) a b c d =
  let open Lwt_result_syntax in
  let*! res =
    Mavryk_rpc_http_client_unix.RPC_client_unix.call_service
      media_types
      ~base
      a
      b
      c
      d
  in
  match res with
  | Ok res -> return res
  | Error trace when is_connection_error trace -> fail (Lost_connection :: trace)
  | Error trace -> fail trace

let make_streamed_call ~rollup_node_endpoint =
  let open Lwt_result_syntax in
  let stream, push = Lwt_stream.create () in
  let on_chunk v = push (Some v) and on_close () = push None in
  let* spill_all =
    Mavryk_rpc_http_client_unix.RPC_client_unix.call_streamed_service
      [Media_type.json]
      ~base:rollup_node_endpoint
      global_block_watcher
      ~on_chunk
      ~on_close
      ()
      ()
      ()
  in
  let close () =
    spill_all () ;
    if Lwt_stream.is_closed stream then () else on_close ()
  in
  return (stream, close)

let publish :
    rollup_node_endpoint:Uri.t ->
    [< `External of string] list ->
    unit tzresult Lwt.t =
 fun ~rollup_node_endpoint inputs ->
  let open Lwt_result_syntax in
  let inputs = List.map (function `External s -> s) inputs in
  let* _answer =
    call_service ~base:rollup_node_endpoint batcher_injection () () inputs
  in
  return_unit

let durable_state_subkeys :
    ( [`GET],
      unit,
      unit * Block_id.t,
      state_value_query,
      unit,
      string list option )
    Service.service =
  Mavryk_rpc.Service.get_service
    ~description:
      "Retrieve subkeys by key from PVM durable storage. PVM state is taken \
       with respect to the specified block level. Value returned in hex \
       format."
    ~query:state_value_query
    ~output:Data_encoding.(option (list string))
    (open_root / "global" / "block" /: Block_id.arg / "durable" / "wasm_2_0_0"
   / "subkeys")

(** [smart_rollup_address base] asks for the smart rollup node's
    address, using the endpoint [base]. *)
let smart_rollup_address base =
  let open Lwt_result_syntax in
  let*! answer =
    call_service
      ~base
      ~media_types:[Media_type.octet_stream]
      smart_rollup_address
      ()
      ()
      ()
  in
  match answer with
  | Ok address -> return (Bytes.to_string address)
  | Error trace -> fail trace

let oldest_known_l1_level base =
  let open Lwt_result_syntax in
  let*! answer =
    call_service ~base ~media_types:[Media_type.octet_stream] gc_info () () ()
  in
  match answer with
  | Ok (_last_gc_level, first_available_level, _last_context_split) ->
      return first_available_level
  | Error trace -> fail trace

(** [mavryk_level base] asks for the smart rollup node's
    latest l1 level, using the endpoint [base]. *)
let mavryk_level base =
  let open Lwt_result_syntax in
  let* level_opt =
    call_service
      ~base
      ~media_types:[Media_type.octet_stream]
      global_current_mavryk_level
      ()
      ()
      ()
  in
  let*? level =
    Option.to_result
      ~none:
        [
          error_of_fmt
            "Rollup node is not yet bootstrapped, please wait for the rollup \
             to process an initial block. ";
        ]
      level_opt
  in
  return level
