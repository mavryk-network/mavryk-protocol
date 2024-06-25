(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

open Tezos_rpc

let evm_services_root = Path.(root / "evm")

let get_smart_rollup_address_service =
  Service.get_service
    ~description:"Get the address of the smart rollup hosting the chain"
    ~query:Query.empty
    ~output:Tezos_crypto.Hashed.Smart_rollup_address.encoding
    Path.(evm_services_root / "smart_rollup_address")

let get_blueprint_service =
  Service.get_service
    ~description:"Fetch the contents of a blueprint"
    ~query:Query.empty
    ~output:Blueprint_types.with_events_encoding
    Path.(evm_services_root / "blueprint" /: Arg.uint63)

let blueprint_watcher_service =
  let level_query =
    Query.(query Fun.id |+ field "from_level" Arg.uint63 0L Fun.id |> seal)
  in

  Service.get_service
    ~description:"Watch for new blueprints"
    ~query:level_query
    ~output:Blueprint_types.with_events_encoding
    Path.(evm_services_root / "blueprints")

let create_blueprint_watcher_service from_level =
  let open Lwt_syntax in
  let blueprint_stream, stopper = Evm_context.blueprints_watcher () in
  let shutdown () = Lwt_watcher.shutdown stopper in
  (* input source block creating a stream to observe the events *)
  let* head_info = Evm_context.head_info () in
  let (Qty next) = head_info.next_blueprint_number in
  let* () =
    if Z.(Compare.(next < of_int64 from_level)) then
      Stdlib.failwith "Cannot start watching from a level too far in the future"
    else return_unit
  in

  (* generate the next asynchronous event *)
  let next =
    let next_level_requested = ref Z.(of_int64 from_level) in
    fun () ->
      if Z.Compare.(!next_level_requested < next) then (
        let current_request = !next_level_requested in
        (next_level_requested := Z.(succ current_request)) ;
        let* blueprint = Evm_context.blueprint (Qty current_request) in
        match blueprint with
        | Ok (Some blueprint) -> return_some blueprint
        | Ok None -> return_none
        | Error _ ->
            Stdlib.failwith
              "Something went wrong when trying to fetch a blueprint")
      else Lwt_stream.get blueprint_stream
  in
  Tezos_rpc.Answer.return_stream {next; shutdown}

let register_get_smart_rollup_address_service smart_rollup_address dir =
  Directory.register0 dir get_smart_rollup_address_service (fun () () ->
      let open Lwt_syntax in
      return_ok smart_rollup_address)

let register_get_blueprint_service dir =
  Directory.opt_register1 dir get_blueprint_service (fun level () () ->
      let open Lwt_result_syntax in
      let number = Ethereum_types.Qty (Z.of_int64 level) in
      let* blueprint = Evm_context.blueprint number in
      return blueprint)

let register_blueprint_watcher_service dir =
  Directory.gen_register0 dir blueprint_watcher_service (fun level () ->
      create_blueprint_watcher_service level)

let register smart_rollup_address dir =
  register_get_smart_rollup_address_service smart_rollup_address dir
  |> register_get_blueprint_service |> register_blueprint_watcher_service

let get_smart_rollup_address ~evm_node_endpoint =
  Tezos_rpc_http_client_unix.RPC_client_unix.call_service
    [Media_type.json]
    ~base:evm_node_endpoint
    get_smart_rollup_address_service
    ()
    ()
    ()

let get_blueprint ~evm_node_endpoint Ethereum_types.(Qty level) =
  Tezos_rpc_http_client_unix.RPC_client_unix.call_service
    [Media_type.json]
    ~base:evm_node_endpoint
    get_blueprint_service
    ((), Z.to_int64 level)
    ()
    ()

let monitor_blueprints ~evm_node_endpoint Ethereum_types.(Qty level) =
  let open Lwt_syntax in
  let stream, push = Lwt_stream.create () in
  let on_chunk v = push (Some v) and on_close () = push None in
  let* _spill_all =
    Tezos_rpc_http_client_unix.RPC_client_unix.call_streamed_service
      [Media_type.json]
      ~base:evm_node_endpoint
      blueprint_watcher_service
      ~on_chunk
      ~on_close
      ()
      (Z.to_int64 level)
      ()
  in
  return stream
