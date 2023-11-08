(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Tocqueville Group, Inc. <contact@tezos.com>            *)
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

(** Testing
    -------
    Component:    Gateway
    Invocation:   dune exec src/proto_alpha/lib_protocol/test/integration/main.exe \
                   -- --file test_gateway.ml
    Subject:      Test origination of gateway contract.
*)

(* open Gateway_machine *)
open Protocol
open Test_tez

(* let generate_init_state () =
  let gateway_min_xtz_balance = 10_000_000L in
  let gateway_min_tzbtc_balance = 100_000 in
  let accounts_balances =
    [
      {xtz = 1_000_000L; tzbtc = 1; liquidity = 100};
      {xtz = 1_000L; tzbtc = 1000; liquidity = 100};
      {xtz = 40_000_000L; tzbtc = 350000; liquidity = 300};
    ]
  in
  ValidationMachine.build
    {gateway_min_xtz_balance; gateway_min_tzbtc_balance; accounts_balances}
  >>=? fun (_, _) -> return_unit *)

(* The script hash of

   https://gitlab.com/dexter2tz/dexter2tz/-/blob/d98643881fe14996803997f1283e84ebd2067e35/dexter.liquidity_baking.mligo.tz
*)
let expected_gateway_hash =
  Script_expr_hash.of_b58check_exn
    "expru15HMzoLGQzuQjFVkXRPdQR2D9WgFGPS8tvcwb6xLiDqovSVQT"

let expected_cpmm_hash =
  Script_expr_hash.of_b58check_exn
    "expru15HMzoLGQzuQjFVkXRPdQR2D9WgFGPS8tvcwb6xLiDqovSVQT"
    
(* The script hash of

   https://gitlab.com/dexter2tz/dexter2tz/-/blob/d98643881fe14996803997f1283e84ebd2067e35/lqt_fa12.mligo.tz
*)

(* let expected_lqt_hash =
  Script_expr_hash.of_b58check_exn
    "exprufAK15C2FCbxGLCEVXFe26p3eQdYuwZRk1morJUwy9NBUmEZVB" *)



(* let gateway_origination () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_baking_cpmm_address (B blk) >>=? fun cpmm_address ->
  Context.Contract.script_hash (B blk) cpmm_address >>=? fun cpmm_hash ->
  Assert.equal
    ~loc:__LOC__
    Script_expr_hash.equal
    "Unexpected CPMM script."
    Script_expr_hash.pp
    cpmm_hash
    expected_cpmm_hash
  >>=? fun () -> return_unit *)
   

let gateway_origination () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_gateway_contract_address (B blk) >>=? fun cpmm_address ->
  Context.Contract.script_hash (B blk) cpmm_address >>=? fun cpmm_hash ->
  Assert.equal
    ~loc:__LOC__
    Script_expr_hash.equal
    "Unexpected CPMM script."
    Script_expr_hash.pp
    cpmm_hash
    expected_cpmm_hash
  >>=? fun () -> return_unit


(* let clocktower_origination () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_clocktower_contract_address (B blk) >>=? fun cpmm_address ->
  Context.Contract.script_hash (B blk) cpmm_address >>=? fun cpmm_hash ->
  Assert.equal
    ~loc:__LOC__
    Script_expr_hash.equal
    "Unexpected Clocktower script."
    Script_expr_hash.pp
    cpmm_hash
    expected_cpmm_hash
  >>=? fun () -> return_unit


let liquidity_mining_treasury_origination () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_mining_treasury_contract_address (B blk) >>=? fun cpmm_address ->
  Context.Contract.script_hash (B blk) cpmm_address >>=? fun cpmm_hash ->
  Assert.equal
    ~loc:__LOC__
    Script_expr_hash.equal
    "Unexpected Liquidity Mining Treasury script."
    Script_expr_hash.pp
    cpmm_hash
    expected_cpmm_hash
  >>=? fun () -> return_unit *)

    
(* Test that the scripts of the Gateway contract have the expected hashes. *)
(* let gateway_origination () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_gateway_contract_address (B blk) >>=? fun gateway_address ->
    
    (* Log.info "------";
    Log.info "Gateway Address is: %s" (Contract_hash.to_b58check gateway_address);
    Log.info "------"; *)

  Context.Contract.script_hash (B blk) gateway_address >>=? fun gateway_hash ->
  
  let hardcoded_gateway_address =
    Contract_hash.of_b58check_exn "KT1AafHA1C1vk959wvHWBispY9Y2f3fxBUUo"
  in
  (* If you need to check the hash for the hardcoded address, you can do so here. *)
  Context.Contract.script_hash (B blk) hardcoded_gateway_address >>=? fun expected_gateway_hash ->

  Assert.equal
    ~loc:__LOC__
    Script_expr_hash.equal
    "Unexpected Gateway script."
    Script_expr_hash.pp
    gateway_hash
    expected_gateway_hash
  >>=? fun () -> return_unit *)


(* Test that the CPMM address in storage is correct *)
let liquidity_baking_cpmm_address () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_baking_cpmm_address (B blk) >>=? fun liquidity_baking ->
  Assert.equal
    ~loc:__LOC__
    String.equal
    "CPMM address in storage is incorrect"
    Format.pp_print_string
    (Contract_hash.to_b58check liquidity_baking)
    "KT1TxqZ8QtKvLu3V3JH7Gx58n7Co8pgtpQU5"
  >>=? fun () -> return_unit


let liquidity_baking_storage n () =
  Context.init1 ~consensus_threshold:0 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_baking_cpmm_address (B blk) >>=? fun liquidity_baking ->
  Context.get_liquidity_baking_subsidy (B blk) >>=? fun subsidy ->
  let expected_storage =
    Expr.from_string
      (Printf.sprintf
         "Pair 1\n\
         \        %d\n\
         \        100\n\
         \        \"KT1VqarPDicMFn1ejmQqqshUkUXTCTXwmkCN\"\n\
         \        \"KT1AafHA1C1vk959wvHWBispY9Y2f3fxBUUo\""
         (100 + (n * Int64.to_int (to_mumav subsidy))))
  in
  Block.bake_n n blk >>=? fun blk ->
  Context.Contract.storage (B blk) liquidity_baking >>=? fun storage ->
  let to_string expr =
    Format.asprintf "%a" Michelson_v1_printer.print_expr expr
  in
  Assert.equal
    ~loc:__LOC__
    String.equal
    "Storage isn't equal"
    Format.pp_print_string
    (to_string storage)
    (to_string expected_storage)
  >>=? fun () -> return_unit

let liquidity_baking_balance_update () =
  Context.init1 ~consensus_threshold:0 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_baking_cpmm_address (B blk) >>=? fun liquidity_baking ->
  Context.get_constants (B blk) >>=? fun csts ->
  let subsidy = csts.parametric.liquidity_baking_subsidy in
  Block.bake_n_with_all_balance_updates 128 blk
  >>=? fun (_blk, balance_updates) ->
  let liquidity_baking_updates =
    List.filter
      (fun el ->
        match el with
        | ( Alpha_context.Receipt.Contract (Originated contract),
            Alpha_context.Receipt.Credited _,
            Alpha_context.Receipt.Subsidy ) ->
            Contract_hash.(contract = liquidity_baking)
        | _ -> false)
      balance_updates
  in
  List.fold_left_e
    (fun accum (_, update, _) ->
      match update with
      | Alpha_context.Receipt.Credited x -> accum +? x
      | Alpha_context.Receipt.Debited _ -> assert false)
    (of_int 0)
    liquidity_baking_updates
  >>?= fun credits ->
  Assert.equal_int
    ~loc:__LOC__
    (Int64.to_int (to_mumav credits))
    (128 * Int64.to_int (to_mumav subsidy))
  >>=? fun () -> return_unit

let get_cpmm_result results =
  match results with
  | cpmm_result :: _results -> cpmm_result
  | _ -> assert false

let get_lqt_result results =
  match results with
  | _cpmm_result :: lqt_result :: _results -> lqt_result
  | _ -> assert false

let get_address_in_result result =
  match result with
  | Apply_results.Origination_result {originated_contracts; _} -> (
      match originated_contracts with [c] -> c | _ -> assert false)

let get_balance_updates_in_result result =
  match result with
  | Apply_results.Origination_result {balance_updates; _} -> balance_updates

let get_balance_update_in_result result =
  match get_balance_updates_in_result result with
  | [(Contract _, Credited balance, Protocol_migration)] -> balance
  | [_; _; _; _; _; (Contract _, Credited balance, Protocol_migration)] ->
      balance
  | _ -> assert false

let liquidity_baking_origination_result_cpmm_address () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Context.get_liquidity_baking_cpmm_address (B blk)
  >>=? fun cpmm_address_in_storage ->
  Block.bake_n_with_origination_results 1 blk
  >>=? fun (_blk, origination_results) ->
  let result = get_cpmm_result origination_results in
  let address = get_address_in_result result in
  Assert.equal
    ~loc:__LOC__
    Contract_hash.equal
    "CPMM address in storage is not the same as in origination result"
    Contract_hash.pp
    address
    cpmm_address_in_storage
  >>=? fun () -> return_unit

let liquidity_baking_origination_result_cpmm_balance () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Block.bake_n_with_origination_results 1 blk
  >>=? fun (_blk, origination_results) ->
  let result = get_cpmm_result origination_results in
  let balance_update = get_balance_update_in_result result in
  Assert.equal_tez ~loc:__LOC__ balance_update (of_mumav_exn 100L)
  >>=? fun () -> return_unit

let liquidity_baking_origination_result_lqt_address () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Block.bake_n_with_origination_results 1 blk
  >>=? fun (_blk, origination_results) ->
  let result = get_lqt_result origination_results in
  let address = get_address_in_result result in
  Assert.equal
    ~loc:__LOC__
    String.equal
    "LQT address in origination result is incorrect"
    Format.pp_print_string
    (Contract_hash.to_b58check address)
    "KT1AafHA1C1vk959wvHWBispY9Y2f3fxBUUo"
  >>=? fun () -> return_unit

let liquidity_baking_origination_result_lqt_balance () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Block.bake_n_with_origination_results 1 blk
  >>=? fun (_blk, origination_results) ->
  let result = get_lqt_result origination_results in
  let balance_updates = get_balance_updates_in_result result in
  match balance_updates with
  | [
   (Liquidity_baking_subsidies, Debited am1, Protocol_migration);
   (Storage_fees, Credited am2, Protocol_migration);
   (Liquidity_baking_subsidies, Debited am3, Protocol_migration);
   (Storage_fees, Credited am4, Protocol_migration);
  ] ->
      Assert.equal_tez ~loc:__LOC__ am1 am2 >>=? fun () ->
      Assert.equal_tez ~loc:__LOC__ am3 am4 >>=? fun () ->
      Assert.equal_tez ~loc:__LOC__ am1 (of_mumav_exn 64_250L) >>=? fun () ->
      Assert.equal_tez ~loc:__LOC__ am3 (of_mumav_exn 494_500L)
  | _ -> failwith "Unexpected balance updates (%s)" __LOC__

(* Test that with no contract at the tzBTC address and the level low enough to indicate we're not on mainnet, three contracts are originated in stitching. *)
let liquidity_baking_origination_test_migration () =
  Context.init1 () >>=? fun (blk, _contract) ->
  Block.bake_n_with_origination_results 1 blk
  >>=? fun (_blk, origination_results) ->
  let num_results = List.length origination_results in
  Assert.equal_int ~loc:__LOC__ num_results 3

(* Test that with no contract at the tzBTC address and the level high enough to indicate we could be on mainnet, no contracts are originated in stitching. *)
let liquidity_baking_origination_no_tzBTC_mainnet_migration () =
  Context.init1 ~consensus_threshold:0 ~level:1_437_862l ()
  >>=? fun (blk, _contract) ->
  (* By baking a bit we also check that the subsidy application with no CPMM present does nothing rather than stopping the chain.*)
  Block.bake_n_with_origination_results 64 blk
  >>=? fun (_blk, origination_results) ->
  let num_results = List.length origination_results in
  Assert.equal_int ~loc:__LOC__ num_results 0



let tests =
  [
    Tztest.tztest
      "gateway contract script hashes"
      `Quick
      gateway_origination;
    (* Tztest.tztest
      "gateway contract clocktower script hashes"
      `Quick
      clocktower_origination;
    Tztest.tztest
      "gateway contract liquidity mining treasury script hashes"
      `Quick
      liquidity_mining_treasury_origination; *)
    (* Tztest.tztest
      "liquidity baking cpmm is originated at the expected address"
      `Quick
      liquidity_baking_cpmm_address; *)
    (* Tztest.tztest "Init Context" `Quick generate_init_state; *)
    
    (* Tztest.tztest
      "liquidity baking storage is updated"
      `Quick
      (liquidity_baking_storage 64);
    Tztest.tztest
      "liquidity baking balance updates"
      `Quick
      liquidity_baking_balance_update;
    Tztest.tztest
      "liquidity baking CPMM address in storage matches address in the \
       origination result"
      `Quick
      liquidity_baking_origination_result_cpmm_address;
    Tztest.tztest
      "liquidity baking CPMM balance in origination result is 100 mumav"
      `Quick
      liquidity_baking_origination_result_cpmm_balance;
    Tztest.tztest
      "liquidity baking LQT contract is originated at expected address"
      `Quick
      liquidity_baking_origination_result_lqt_address;
    Tztest.tztest
      "liquidity baking LQT balance in origination result is 0 mumav"
      `Quick
      liquidity_baking_origination_result_lqt_balance;
    Tztest.tztest
      "liquidity baking originates three contracts when tzBTC does not exist \
       and level indicates we are not on mainnet"
      `Quick
      liquidity_baking_origination_test_migration;
    Tztest.tztest
      "liquidity baking originates three contracts when tzBTC does not exist \
       and level indicates we might be on mainnet"
      `Quick
      liquidity_baking_origination_no_tzBTC_mainnet_migration; *)
  ]

let () =
  Alcotest_lwt.run ~__FILE__ Protocol.name [("gateway", tests)]
  |> Lwt_main.run
