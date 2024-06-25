(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

type t

(** [init ~data_dir] returns a handler to the EVM node store located under
    [data_dir]. If no store is located in [data_dir], an empty store is
    created. Also returns if the store was created ([true]) or was already
    existing ([false]). *)
val init : data_dir:string -> t tzresult Lwt.t

(** [with_transaction store k] wraps the accesses to [store] made in the
    continuation [k] within {{:https://www.sqlite.org/lang_transaction.html}a
    SQL transaction}. If [k] fails, the transaction is rollbacked. Otherwise,
    the transaction is committed. *)
val with_transaction : t -> (t -> 'a tzresult Lwt.t) -> 'a tzresult Lwt.t

(** [assert_in_transaction store] raises an exception if a transaction has not
    been started with [store].

    @raise Assert_failure *)
val assert_in_transaction : t -> unit

module Blueprints : sig
  val store : t -> Blueprint_types.t -> unit tzresult Lwt.t

  val find :
    t -> Ethereum_types.quantity -> Blueprint_types.t option tzresult Lwt.t

  val find_range :
    t ->
    from:Ethereum_types.quantity ->
    to_:Ethereum_types.quantity ->
    (Ethereum_types.quantity * Blueprint_types.payload) list tzresult Lwt.t

  val clear_after : t -> Ethereum_types.quantity -> unit tzresult Lwt.t
end

module Context_hashes : sig
  val store :
    t -> Ethereum_types.quantity -> Context_hash.t -> unit tzresult Lwt.t

  val find :
    t -> Ethereum_types.quantity -> Context_hash.t option tzresult Lwt.t

  val find_latest :
    t -> (Ethereum_types.quantity * Context_hash.t) option tzresult Lwt.t

  val clear_after : t -> Ethereum_types.quantity -> unit tzresult Lwt.t
end

module Kernel_upgrades : sig
  val store :
    t ->
    Ethereum_types.quantity ->
    Ethereum_types.Upgrade.t ->
    unit tzresult Lwt.t

  val find_latest_pending : t -> Ethereum_types.Upgrade.t option tzresult Lwt.t

  val record_apply : t -> Ethereum_types.quantity -> unit tzresult Lwt.t

  val clear_after : t -> Ethereum_types.quantity -> unit tzresult Lwt.t
end

module Delayed_transactions : sig
  val store :
    t ->
    Ethereum_types.quantity ->
    Ethereum_types.Delayed_transaction.t ->
    unit tzresult Lwt.t

  val at_level :
    t ->
    Ethereum_types.quantity ->
    Ethereum_types.Delayed_transaction.t list tzresult Lwt.t

  val at_hash :
    t ->
    Ethereum_types.hash ->
    Ethereum_types.Delayed_transaction.t option tzresult Lwt.t

  val clear_after : t -> Ethereum_types.quantity -> unit tzresult Lwt.t
end

module L1_latest_known_level : sig
  val store : t -> Ethereum_types.quantity -> int32 -> unit tzresult Lwt.t

  val find : t -> (Ethereum_types.quantity * int32) option tzresult Lwt.t

  val clear_after : t -> Ethereum_types.quantity -> unit tzresult Lwt.t
end

(** [reset store ~l2_level] clear the table that has information
    related to l2 level that after [l2_level] *)
val reset : t -> l2_level:Ethereum_types.quantity -> unit tzresult Lwt.t
