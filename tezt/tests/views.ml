(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Nomadic Labs <contact@nomadic-labs.com>                *)
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
   Invocation:   dune exec tezt/tests/main.exe -- --file views.ml
   Subject:      Call smart contract views to catch performance regressions.
*)

(* Normally "--base-dir" would appear in regression logs. However, since
   it is a different dir on every run, we need to mask it in regression
   logs so that it doesn't cause false differences. *)
let hooks =
  let rec mask_temp_dir = function
    | [] -> []
    | "--base-dir" :: _ :: rest -> "--base-dir" :: "<masked>" :: rest
    | arg :: args -> arg :: mask_temp_dir args
  in
  {
    Regression.hooks with
    on_spawn =
      (fun cmd args -> mask_temp_dir args |> Regression.hooks.on_spawn cmd);
  }

let register =
  Protocol.register_regression_test
    ~__FILE__
    ~title:"Run views"
    ~tags:["client"; "michelson"]
  @@ fun protocol ->
  let* client = Client.init_mockup ~protocol () in
  let* _alias, register_callers =
    Client.originate_contract_at
      ~hooks
      ~burn_cap:Tez.one
      ~amount:Tez.zero
      ~src:"bootstrap1"
      ~init:"{}"
      client
      ["mini_scenarios"; "view_registers_callers"]
      protocol
  in
  let arg = Format.sprintf "\"%s\"" register_callers in
  let* _alias, check_caller =
    Client.originate_contract_at
      ~hooks
      ~burn_cap:Tez.one
      ~amount:Tez.zero
      ~src:"bootstrap1"
      ~init:"None"
      client
      ["mini_scenarios"; "view_check_caller"]
      protocol
  in
  let* () =
    Client.transfer
      ~hooks
      ~burn_cap:Tez.one
      ~amount:Tez.one
      ~giver:"bootstrap1"
      ~receiver:check_caller
      ~arg
      client
  in
  let* () =
    Client.transfer
      ~hooks
      ~burn_cap:Tez.one
      ~amount:Tez.one
      ~giver:"bootstrap1"
      ~receiver:register_callers
      client
  in
  let* () =
    Client.transfer
      ~hooks
      ~burn_cap:Tez.one
      ~amount:Tez.one
      ~giver:"bootstrap1"
      ~receiver:check_caller
      ~arg
      client
  in
  return ()
