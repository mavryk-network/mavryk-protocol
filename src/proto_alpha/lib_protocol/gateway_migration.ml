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

(** This module is used to originate contracts for block fees splitting during
    protocol stitching: a Gateway contract

    The Gateway storage contains:

    The test FA1.2 contract uses the same script as the liquidity token. Its
    manager is initialized to the first bootstrap account. Before originating it,
    we make sure we are not on mainnet by both checking for the existence of the
    tzBTC contract and that the level is sufficiently low.

    The Michelson and Ligo code, as well as Coq proofs, for the CPMM and
    liquidity token contracts are available here:
    https://gitlab.com/dexter2tz/dexter2tz/-/tree/liquidity_baking

    All contracts were generated from Ligo at revision
    4d10d07ca05abe0f8a5fb97d15267bf5d339d9f4 and converted to OCaml using
    `octez-client convert`.
*)

open Michelson_v1_primitives
open Micheline

let null_address =
  Bytes.of_string
    "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000"

(* let mainnet_tzBTC_address =
  Contract_hash.of_b58check_exn "KT1PWx2mnDueood7fEmfbBDKx1D9BAnnXitn" *)

(** If token_pool, xtz_pool, or lqt_total are ever zero the CPMM will be
    permanently broken. Therefore, we initialize it with the null address
    registered as a liquidity provider with 1 satoshi tzBTC and 100 mumav
    (roughly the current exchange rate).  *)
(* let cpmm_init_storage ~token_address ~lqt_address =
  Script_repr.lazy_expr
    (Micheline.strip_locations
       (Prim
          ( 0,
            D_Pair,
            [
              Int (1, Z.one);
              Int (2, Z.of_int 100);
              Int (3, Z.of_int 100);
              String (4, token_address);
              String (5, lqt_address);
            ],
            [] ))) *)

let gateway_init_storage gateway_address =
  Script_repr.lazy_expr
    (Micheline.strip_locations
       (Prim
          ( 0,
            D_Pair,
            [
              Seq
                ( 1,
                  [
                    Prim
                      ( 2,
                        D_Elt,
                        [Bytes (3, null_address); Int (4, Z.of_int 100)],
                        [] );
                  ] );
              Seq (5, []);
              String (6, gateway_address);
              Int (7, Z.of_int 100);
            ],
            [] )))

(* let test_fa12_init_storage manager =
  Script_repr.lazy_expr
    (Micheline.strip_locations
       (Prim
          ( 0,
            D_Pair,
            [
              Seq (1, []);
              Seq (2, []);
              String (3, manager);
              Int (4, Z.of_int 10_000);
            ],
            [] ))) *)

let originate ctxt address_hash ~balance script =
  Contract_storage.raw_originate
    ctxt
    ~prepaid_bootstrap_storage:true
    address_hash
    ~script
  >>=? fun ctxt ->
  let address = Contract_repr.Originated address_hash in
  Contract_storage.used_storage_space ctxt address >>=? fun size ->
  Fees_storage.burn_origination_fees
    ~origin:Protocol_migration
    ctxt
    ~storage_limit:(Z.of_int64 Int64.max_int)
    ~payer:`Liquidity_baking_subsidies
  >>=? fun (ctxt, _, origination_updates) ->
  Fees_storage.burn_storage_fees
    ~origin:Protocol_migration
    ctxt
    ~storage_limit:(Z.of_int64 Int64.max_int)
    ~payer:`Liquidity_baking_subsidies
    size
  >>=? fun (ctxt, _, storage_updates) ->
  Token.transfer
    ~origin:Protocol_migration
    ctxt
    `Liquidity_baking_subsidies
    (`Contract address)
    balance
  >>=? fun (ctxt, transfer_updates) ->
  let balance_updates =
    origination_updates @ storage_updates @ transfer_updates
  in
  let result : Migration_repr.origination_result =
    {
      balance_updates;
      originated_contracts = [address_hash];
      storage_size = size;
      paid_storage_size_diff = size;
    }
  in
  return (ctxt, result)

  
(* let init ctxt ~typecheck =
  (* We use a custom origination nonce because it is unset when stitching from 009 *)
  let nonce = Operation_hash.hash_string ["Save, save, save."] in
  let ctxt = Raw_context.init_origination_nonce ctxt nonce in
  
  Contract_storage.fresh_contract_from_current_nonce ctxt
  >>?= fun (ctxt, gateway_address) ->
  
  (* Placeholder for gateway contract code and storage *)
  let gateway_code    = Script_repr.lazy_expr Liquidity_baking_lqt.script in 
  let gateway_storage = gateway_init_storage (Contract_hash.to_b58check gateway_address) in
  
  let gateway_script =
    Script_repr.
      {
        code    = gateway_code;
        storage = gateway_storage;
      }
  in
  
  typecheck ctxt gateway_script >>=? fun (gateway_script, ctxt) ->
  
  originate
    ctxt
    gateway_address
    ~balance:(Tez_repr.of_mumav_exn 100L)
    gateway_script
  >>=? fun (ctxt, gateway_result) ->
  
  (* Unsets the origination nonce, which is okay because this is called after other originations in stitching. *)
  let ctxt = Raw_context.unset_origination_nonce ctxt in
  (ctxt, [gateway_result;]) *)

let init ctxt ~typecheck =
  (* We use a custom origination nonce because it may be unset in certain scenarios *)
  let nonce = Operation_hash.hash_string ["Save, save, save."] in
  let ctxt = Raw_context.init_origination_nonce ctxt nonce in
  
  (* Get a fresh contract address for the gateway contract *)
  Contract_storage.fresh_contract_from_current_nonce ctxt
  >>?= fun (ctxt, gateway_address) ->
  
  (* Define the gateway contract code and storage *)
  let gateway_code = Script_repr.lazy_expr Liquidity_baking_lqt.script in 
  let gateway_storage = gateway_init_storage (Contract_hash.to_b58check gateway_address) in
  
  let gateway_script =
    Script_repr.
      {
        code    = gateway_code;
        storage = gateway_storage;
      }
  in
  
  (* Typecheck the gateway contract *)
  typecheck ctxt gateway_script >>=? fun (gateway_script, ctxt) ->
  
  (* Originate the gateway contract *)
  originate
    ctxt
    gateway_address
    ~balance:(Tez_repr.of_mumav_exn 100L)
    gateway_script
  >>=? fun (ctxt, gateway_result) ->
  
  (* Unset the origination nonce *)
  let ctxt = Raw_context.unset_origination_nonce ctxt in
  (* (ctxt, [gateway_result]) *)
  Lwt.return (Ok (ctxt, [gateway_result]))

  