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

type simulation_result = {
  state_hash : string;
  status : string;
  output : JSON.t;
  inbox_level : int;
  num_ticks : int;
  insights : string option list;
}

let simulate ?(block = "head") sc_rollup_node ?(reveal_pages = [])
    ?(insight_requests = []) messages =
  let service = "global/block/" ^ block ^ "/simulate" in
  let messages_json =
    `A (List.map (fun s -> `String Hex.(of_string s |> show)) messages)
  in
  let reveal_json =
    match reveal_pages with
    | [] -> []
    | pages ->
        [
          ( "reveal_pages",
            `A (List.map (fun s -> `String Hex.(of_string s |> show)) pages) );
        ]
  in
  let insight_requests_json =
    let insight_request_json insight_request =
      let insight_request_kind, key =
        match insight_request with
        | `Pvm_state_key key -> ("pvm_state", key)
        | `Durable_storage_key key -> ("durable_storage", key)
      in
      let x = `A (List.map (fun s -> `String s) key) in
      `O [("kind", `String insight_request_kind); ("key", x)]
    in
    [("insight_requests", `A (List.map insight_request_json insight_requests))]
  in
  let data =
    `O ((("messages", messages_json) :: reveal_json) @ insight_requests_json)
    |> JSON.annotate ~origin:"simulation data"
  in
  let* process = post_rpc ~smart_rollup_node:sc_rollup_node ~service ~data in
  return
    JSON.
      {
        state_hash = process |> get "state_hash" |> as_string;
        status = process |> get "status" |> as_string;
        output = process |> get "output";
        inbox_level = process |> get "inbox_level" |> as_int;
        num_ticks = process |> get "num_ticks" |> as_string |> int_of_string;
        insights =
          process |> get "insights" |> as_list |> List.map as_string_opt;
      }
