(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Tocqueville Group, Inc. <contact@tezos.com>            *)
(* Copyright (c) 2022-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
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

(** Options available for toggle per-block votes *)

type toggle_vote = Toggle_vote_on | Toggle_vote_off | Toggle_vote_pass

type toggle_votes = {
  liquidity_baking_vote : toggle_vote;
  adaptive_inflation_vote : toggle_vote;
}

let toggle_vote_of_int2 = function
  | 0 -> Ok Toggle_vote_on
  | 1 -> Ok Toggle_vote_off
  | 2 -> Ok Toggle_vote_pass
  | _ -> Error "toggle_vote_of_int2"

let toggle_vote_to_int2 = function
  | Toggle_vote_on -> 0
  | Toggle_vote_off -> 1
  | Toggle_vote_pass -> 2

let toggle_vote_encoding name =
  let open Data_encoding in
  (* union *)
  def name
  @@ splitted
       ~binary:(conv_with_guard toggle_vote_to_int2 toggle_vote_of_int2 int8)
       ~json:
         (string_enum
            [
              ("on", Toggle_vote_on);
              ("off", Toggle_vote_off);
              ("pass", Toggle_vote_pass);
            ])

let liquidity_baking_vote_encoding =
  toggle_vote_encoding "liquidity_baking_vote"

let adaptive_inflation_vote_encoding =
  toggle_vote_encoding "adaptive_inflation_vote"

let toggle_votes_encoding =
  let of_int8 i =
    match (toggle_vote_of_int2 (i land 0b11), toggle_vote_of_int2 (i / 4)) with
    | Ok liquidity_baking_vote, Ok adaptive_inflation_vote ->
        Ok {liquidity_baking_vote; adaptive_inflation_vote}
    | _ -> Error "toggle_votes_of_int8"
  in
  let to_int8 {liquidity_baking_vote; adaptive_inflation_vote} =
    toggle_vote_to_int2 liquidity_baking_vote
    + (toggle_vote_to_int2 adaptive_inflation_vote * 4)
  in
  let open Data_encoding in
  let json =
    conv
      (fun {liquidity_baking_vote; adaptive_inflation_vote} ->
        (liquidity_baking_vote, adaptive_inflation_vote))
      (fun (liquidity_baking_vote, adaptive_inflation_vote) ->
        {liquidity_baking_vote; adaptive_inflation_vote})
      (obj2
         (req "liquidity_baking_vote" liquidity_baking_vote_encoding)
         (req "adaptive_inflation_vote" adaptive_inflation_vote_encoding))
  in
  (* union *)
  def "toggle_votes"
  @@ splitted ~binary:(conv_with_guard to_int8 of_int8 int8) ~json

(* Invariant: 0 <= ema <= 2_000_000 *)
let compute_new_ema ~toggle_vote ema =
  match toggle_vote with
  | Toggle_vote_pass -> ema
  | Toggle_vote_off -> Toggle_EMA.update_ema_off ema
  | Toggle_vote_on -> Toggle_EMA.update_ema_on ema
