(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs, <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

type t = {
  own_frozen : Tez_repr.t;
  staked_frozen : Tez_repr.t;
  delegated : Tez_repr.t;
}

let init ~own_frozen ~staked_frozen ~delegated =
  {own_frozen; staked_frozen; delegated}

let zero =
  init
    ~own_frozen:Tez_repr.zero
    ~staked_frozen:Tez_repr.zero
    ~delegated:Tez_repr.zero

let encoding =
  let open Data_encoding in
  conv
    (fun {own_frozen; staked_frozen; delegated} ->
      (own_frozen, staked_frozen, delegated))
    (fun (own_frozen, staked_frozen, delegated) ->
      {own_frozen; staked_frozen; delegated})
    (obj3
       (req "own_frozen" Tez_repr.encoding)
       (req "staked_frozen" Tez_repr.encoding)
       (req "delegated" Tez_repr.encoding))

let voting_weight {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let* frozen = Tez_repr.(own_frozen +? staked_frozen) in
  let+ all = Tez_repr.(frozen +? delegated) in
  Tez_repr.to_mutez all

let remove_delegated ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ delegated = Tez_repr.(delegated -? amount) in
  {own_frozen; staked_frozen; delegated}

let remove_own_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ own_frozen = Tez_repr.(own_frozen -? amount) in
  {own_frozen; staked_frozen; delegated}

let remove_staked_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ staked_frozen = Tez_repr.(staked_frozen -? amount) in
  {own_frozen; staked_frozen; delegated}

let remove_shared_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let* own_part =
    if Tez_repr.(staked_frozen = zero) then return amount
    else
      let* total_frozen = Tez_repr.(own_frozen +? staked_frozen) in
      Tez_repr.mul_ratio
        amount
        ~num:(Tez_repr.to_mutez own_frozen)
        ~den:(Tez_repr.to_mutez total_frozen)
  in
  let* own_frozen = Tez_repr.(own_frozen -? own_part) in
  let* staked_part = Tez_repr.(amount -? own_part) in
  let+ staked_frozen = Tez_repr.(staked_frozen -? staked_part) in
  {own_frozen; staked_frozen; delegated}

let add_delegated ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ delegated = Tez_repr.(delegated +? amount) in
  {own_frozen; staked_frozen; delegated}

let add_own_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ own_frozen = Tez_repr.(own_frozen +? amount) in
  {own_frozen; staked_frozen; delegated}

let add_staked_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let+ staked_frozen = Tez_repr.(staked_frozen +? amount) in
  {own_frozen; staked_frozen; delegated}

let add_shared_frozen ~amount {own_frozen; staked_frozen; delegated} =
  let open Result_syntax in
  let* own_part =
    if Tez_repr.(staked_frozen = zero) then return amount
    else
      let* total_frozen = Tez_repr.(own_frozen +? staked_frozen) in
      Tez_repr.mul_ratio
        amount
        ~num:(Tez_repr.to_mutez own_frozen)
        ~den:(Tez_repr.to_mutez total_frozen)
  in
  let* own_frozen = Tez_repr.(own_frozen +? own_part) in
  let* staked_part = Tez_repr.(amount -? own_part) in
  let+ staked_frozen = Tez_repr.(staked_frozen +? staked_part) in
  {own_frozen; staked_frozen; delegated}
