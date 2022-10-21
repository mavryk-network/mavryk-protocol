(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Marigold <contact@marigold.dev>                        *)
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

(* Testing
   -------
   Component:    Michelson
   Invocation:   dune exec tezt/tests/main.exe -- --file tickets.ml
   Subject:      Regression tests for tickets
*)

let hooks = Tezos_regression.hooks

let test_create_and_remove_tickets =
  Protocol.register_regression_test
    ~__FILE__
    ~title:"Create and remove tickets"
    ~tags:["client"; "michelson"]
  @@ fun protocol ->
  let* client = Client.init_mockup ~protocol () in
  let* _alias, contract_id =
    Client.originate_contract_at
      ~amount:(Tez.of_int 200)
      ~src:"bootstrap1"
      ~init:"{}"
      ~burn_cap:Tez.one
      ~hooks
      client
      ["mini_scenarios"; "add_clear_tickets"]
      protocol
  in
  let* () =
    (* Add ticket with payload (Pair 1 "A") *)
    Client.transfer
      ~burn_cap:(Tez.of_int 2)
      ~amount:Tez.zero
      ~giver:"bootstrap2"
      ~receiver:contract_id
      ~entrypoint:"add"
      ~arg:{|Pair 1 "A"|}
      ~hooks
      client
  in
  let* () =
    (* Remove tickets by calling clear entrypoint *)
    Client.transfer
      ~burn_cap:(Tez.of_int 2)
      ~amount:Tez.zero
      ~giver:"bootstrap2"
      ~receiver:contract_id
      ~entrypoint:"clear"
      ~arg:"Unit"
      ~hooks
      client
  in
  let* () =
    (* Add ticket with payload (Pair 1 "B") *)
    Client.transfer
      ~burn_cap:(Tez.of_int 2)
      ~amount:Tez.zero
      ~giver:"bootstrap2"
      ~receiver:contract_id
      ~entrypoint:"add"
      ~arg:{|Pair 1 "B"|}
      ~hooks
      client
  in
  let* () =
    (* Add ticket with payload (Pair 1 "C") *)
    Client.transfer
      ~burn_cap:(Tez.of_int 2)
      ~amount:Tez.zero
      ~giver:"bootstrap2"
      ~receiver:contract_id
      ~entrypoint:"add"
      ~arg:{|Pair 1 "C"|}
      ~hooks
      client
  in
  unit

(* This test originates two contracts. One for receiving a big-map with string
   tickets. Another for creating and sending a big-map with string tickets.
   Scanning the big-map for tickets uses the function [Big_map.list_key_values]
   so the regression tests include gas costs associated with calling this
   function. *)
let test_send_tickets_in_big_map =
  Protocol.register_regression_test
    ~__FILE__
    ~title:"Send tickets in bigmap"
    ~tags:["client"; "michelson"]
  @@ fun protocol ->
  let* client = Client.init_mockup ~protocol () in
  let* _receive_contract_alias, receive_contract_hash =
    Client.originate_contract_at
      ~amount:(Tez.of_int 200)
      ~src:"bootstrap1"
      ~init:"{}"
      ~burn_cap:Tez.one
      ~hooks
      client
      ["mini_scenarios"; "receive_tickets_in_big_map"]
      protocol
  in
  let* _alias_contract_hash, send_contract_hash =
    Client.originate_contract_at
      ~amount:(Tez.of_int 200)
      ~src:"bootstrap1"
      ~init:"Unit"
      ~burn_cap:Tez.one
      ~hooks
      client
      ["mini_scenarios"; "send_tickets_in_big_map"]
      protocol
  in
  let* () =
    Client.transfer
      ~burn_cap:(Tez.of_int 30)
      ~storage_limit:1000000
      ~amount:Tez.zero
      ~giver:"bootstrap2"
      ~receiver:send_contract_hash
      ~arg:(sf {|"%s"|} receive_contract_hash)
      ~hooks
      client
  in
  unit

let register ~protocols =
  test_create_and_remove_tickets protocols ;
  test_send_tickets_in_big_map protocols
