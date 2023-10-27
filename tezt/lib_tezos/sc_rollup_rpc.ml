(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 TriliTech <contact@trili.tech>                    *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*****************************************************************************)

let call_rpc ~smart_rollup_node ~service =
  let open Runnable.Syntax in
  let url =
    Printf.sprintf "%s/%s" (Sc_rollup_node.endpoint smart_rollup_node) service
  in
  let*! response = Curl.get url in
  return response

let post_rpc ~smart_rollup_node ~service ~data =
  let open Runnable.Syntax in
  let url =
    Printf.sprintf "%s/%s" (Sc_rollup_node.endpoint smart_rollup_node) service
  in
  let*! response = Curl.post url data in
  return response

let ticks ?(block = "head") smart_rollup_node =
  let service = "global/block/" ^ block ^ "/ticks" in
  let* json = call_rpc ~smart_rollup_node ~service in
  return (JSON.as_int json)

let state_hash ?(block = "head") smart_rollup_node =
  let service = "global/block/" ^ block ^ "/state_hash" in
  let* json = call_rpc ~smart_rollup_node ~service in
  return (JSON.as_string json)

type slot_header = {level : int; commitment : string; index : int}

let dal_slot_headers ?(block = "head") smart_rollup_node =
  let service = "global/block/" ^ block ^ "/dal/slot_headers" in
  let* json = call_rpc ~smart_rollup_node ~service in
  let res =
    JSON.(
      as_list json
      |> List.map (fun obj ->
             {
               level = obj |> get "level" |> as_int;
               commitment = obj |> get "commitment" |> as_string;
               index = obj |> get "index" |> as_int;
             }))
  in
  return res

let inject smart_rollup_node messages =
  let service = "local/batcher/injection" in
  let messages_json =
    `A (List.map (fun s -> `String Hex.(of_string s |> show)) messages)
    |> JSON.annotate ~origin:"injection messages"
  in
  let* json = post_rpc ~smart_rollup_node ~service ~data:messages_json in
  return (JSON.as_list json |> List.map JSON.as_string)

let batcher_queue smart_rollup_node =
  let service = "local/batcher/queue" in
  let* process = call_rpc ~smart_rollup_node ~service in
  let res =
    JSON.as_list process
    |> List.map @@ fun o ->
       let hash = JSON.(o |> get "hash" |> as_string) in
       let hex_msg = JSON.(o |> get "message" |> get "content" |> as_string) in
       (hash, Hex.to_string (`Hex hex_msg))
  in
  return res

let get_batcher_msg smart_rollup_node msg_hash =
  let service = "local/batcher/queue/" ^ msg_hash in
  let* process = call_rpc ~smart_rollup_node ~service in
  let res =
    if JSON.is_null process then failwith "Message is not in the queue" ;
    let hex_msg = JSON.(process |> get "content" |> as_string) in
    (Hex.to_string (`Hex hex_msg), process)
  in
  return res
