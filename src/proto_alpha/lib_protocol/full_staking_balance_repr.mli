(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs, <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

type t

val init :
  own_frozen:Tez_repr.t -> staked_frozen:Tez_repr.t -> delegated:Tez_repr.t -> t

val zero : t

val encoding : t Data_encoding.t

(** The weight of a delegate used for voting rights. *)
val voting_weight : t -> Int64.t tzresult

val own_frozen : t -> Tez_repr.t

val staked_frozen : t -> Tez_repr.t

val delegated : t -> Tez_repr.t

val has_minimal_stake : minimal_stake:Tez_repr.t -> t -> bool

val has_minimal_stake_and_frozen_stake :
  minimal_stake:Tez_repr.t -> minimal_frozen_stake:Tez_repr.t -> t -> bool

val remove_delegated : amount:Tez_repr.t -> t -> t tzresult

val remove_own_frozen : amount:Tez_repr.t -> t -> t tzresult

val remove_staked_frozen : amount:Tez_repr.t -> t -> t tzresult

val remove_shared_frozen : amount:Tez_repr.t -> t -> t tzresult

val add_delegated : amount:Tez_repr.t -> t -> t tzresult

val add_own_frozen : amount:Tez_repr.t -> t -> t tzresult

val add_staked_frozen : amount:Tez_repr.t -> t -> t tzresult

val add_shared_frozen : amount:Tez_repr.t -> t -> t tzresult
