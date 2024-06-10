(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Functori, <contact@functori.com>                       *)
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

open Protocol.Alpha_context

module Address : sig
  type t = Sc_rollup.Address.t

  val of_mavkit : Mavkit_smart_rollup.Address.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Address.t
end

module State_hash : sig
  type t = Sc_rollup.State_hash.t

  val of_mavkit : Mavkit_smart_rollup.State_hash.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.State_hash.t
end

module Merkelized_payload_hashes_hash : sig
  type t = Sc_rollup.Inbox_merkelized_payload_hashes.Hash.t

  val of_mavkit : Mavkit_smart_rollup.Merkelized_payload_hashes_hash.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Merkelized_payload_hashes_hash.t
end

module Commitment_hash : sig
  type t = Sc_rollup.Commitment.Hash.t

  val of_mavkit : Mavkit_smart_rollup.Commitment.Hash.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Commitment.Hash.t
end

module Commitment : sig
  type t = Sc_rollup.Commitment.t

  val of_mavkit : Mavkit_smart_rollup.Commitment.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Commitment.t
end

module Inbox_hash : sig
  type t = Sc_rollup.Inbox.Hash.t

  val of_mavkit : Mavkit_smart_rollup.Inbox_hash.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Inbox_hash.t
end

module Inbox : sig
  type t = Sc_rollup.Inbox.t

  type history_proof = Sc_rollup.Inbox.history_proof

  val of_mavkit : Mavkit_smart_rollup.Inbox.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Inbox.t

  val history_proof_of_mavkit :
    Mavkit_smart_rollup.Inbox.history_proof -> history_proof

  val history_proof_to_mavkit :
    history_proof -> Mavkit_smart_rollup.Inbox.history_proof
end

module Game : sig
  type dissection_chunk = Sc_rollup.Game.dissection_chunk

  val dissection_chunk_of_mavkit :
    Mavkit_smart_rollup.Game.dissection_chunk -> dissection_chunk

  val dissection_chunk_to_mavkit :
    dissection_chunk -> Mavkit_smart_rollup.Game.dissection_chunk

  type step = Sc_rollup.Game.step

  val step_of_mavkit : Mavkit_smart_rollup.Game.step -> step

  val step_to_mavkit : step -> Mavkit_smart_rollup.Game.step

  type refutation = Sc_rollup.Game.refutation

  val refutation_of_mavkit : Mavkit_smart_rollup.Game.refutation -> refutation

  val refutation_to_mavkit : refutation -> Mavkit_smart_rollup.Game.refutation

  type index = Sc_rollup.Game.Index.t

  val index_of_mavkit : Mavkit_smart_rollup.Game.index -> index

  val index_to_mavkit : index -> Mavkit_smart_rollup.Game.index

  type player = Sc_rollup.Game.player

  val player_of_mavkit : Mavkit_smart_rollup.Game.player -> player

  val player_to_mavkit : player -> Mavkit_smart_rollup.Game.player

  type game_state = Sc_rollup.Game.game_state

  val game_state_of_mavkit : Mavkit_smart_rollup.Game.game_state -> game_state

  val game_state_to_mavkit : game_state -> Mavkit_smart_rollup.Game.game_state

  type t = Sc_rollup.Game.t

  val of_mavkit : Mavkit_smart_rollup.Game.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Game.t

  type conflict = Sc_rollup.Refutation_storage.conflict

  val conflict_of_mavkit : Mavkit_smart_rollup.Game.conflict -> conflict

  val conflict_to_mavkit : conflict -> Mavkit_smart_rollup.Game.conflict
end

module Kind : sig
  type t = Sc_rollup.Kind.t

  val of_mavkit : Mavkit_smart_rollup.Kind.t -> t

  val to_mavkit : t -> Mavkit_smart_rollup.Kind.t
end

module Dal : sig
  module Slot_index : sig
    type t = Dal.Slot_index.t

    val of_mavkit :
      number_of_slots:int -> Mavkit_smart_rollup.Dal.Slot_index.t -> t

    val to_mavkit : t -> Mavkit_smart_rollup.Dal.Slot_index.t
  end

  module Page_index : sig
    type t = Dal.Page.Index.t

    val of_mavkit : Mavkit_smart_rollup.Dal.Page_index.t -> t

    val to_mavkit : t -> Mavkit_smart_rollup.Dal.Page_index.t
  end

  module Slot_header : sig
    type t = Dal.Slot.Header.t

    val of_mavkit :
      number_of_slots:int -> Mavkit_smart_rollup.Dal.Slot_header.t -> t

    val to_mavkit : t -> Mavkit_smart_rollup.Dal.Slot_header.t
  end

  module Slot_history : sig
    type t = Dal.Slots_history.t

    val of_mavkit : Mavkit_smart_rollup.Dal.Slot_history.t -> t

    val to_mavkit : t -> Mavkit_smart_rollup.Dal.Slot_history.t
  end

  module Slot_history_cache : sig
    type t = Dal.Slots_history.History_cache.t

    val of_mavkit : Mavkit_smart_rollup.Dal.Slot_history_cache.t -> t

    val to_mavkit : t -> Mavkit_smart_rollup.Dal.Slot_history_cache.t
  end
end

module Constants : sig
  type reveal_activation_level =
    Constants.Parametric.sc_rollup_reveal_activation_level

  val reveal_activation_level_of_mavkit :
    Mavkit_smart_rollup.Rollup_constants.reveal_activation_level ->
    reveal_activation_level

  val reveal_activation_level_to_mavkit :
    reveal_activation_level ->
    Mavkit_smart_rollup.Rollup_constants.reveal_activation_level
end
