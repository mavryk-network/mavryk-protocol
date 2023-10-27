(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 TriliTech <contact@trili.tech>                    *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*****************************************************************************)

type commitment = {
  compressed_state : string;
  inbox_level : int;
  predecessor : string;
  number_of_ticks : int;
}

type commitment_and_hash = {commitment : commitment; hash : string}

type commitment_info = {
  commitment_and_hash : commitment_and_hash;
  first_published_at_level : int option;
  published_at_level : int option;
}

(** [post_rpc ~smart_rollup_node ~service ~data] call the RPC for [service] with [data] on
    [smart_rollup_node]. *)
val post_rpc :
  smart_rollup_node:Sc_rollup_node.t ->
  service:string ->
  data:JSON.t ->
  JSON.t Lwt.t

(** [ticks ?block sc_rollup_node] gets the number of ticks for the PVM for the [block]
    (default ["head"]). *)
val ticks : ?block:string -> Sc_rollup_node.t -> int Lwt.t

(** [state_hash ?block sc_rollup_node] gets the corresponding PVM state hash for the
    [block] (default ["head"]). *)
val state_hash : ?block:string -> Sc_rollup_node.t -> string Lwt.t

type slot_header = {level : int; commitment : string; index : int}

(** [dal_slot_headers ?block sc_rollup_node] returns the dal slot headers of the
    [block] (default ["head"]). *)
val dal_slot_headers :
  ?block:string -> Sc_rollup_node.t -> slot_header list Lwt.t

(** [inject sc_rollup_node messages] injects the [messages] in the queue the rollup
    node's batcher and returns the list of message hashes injected. *)
val inject : Sc_rollup_node.t -> string list -> string list Lwt.t

(** [batcher_queue sc_rollup_node] returns the queue of messages, as pairs of message
    hash and binary message, in the batcher. *)
val batcher_queue : Sc_rollup_node.t -> (string * string) list Lwt.t

(** [get_batcher_msg sc_rollup_node hash] fetches the message whose hash is [hash] from
    the queue. It returns the message together with the full JSON response
    including the status. *)
val get_batcher_msg : Sc_rollup_node.t -> string -> (string * JSON.t) Lwt.t

type simulation_result = {
  state_hash : string;
  status : string;
  output : JSON.t;
  inbox_level : int;
  num_ticks : int;
  insights : string option list;
}

(** [simulate ?block sc_rollup_node ?reveal_pages ?insight_request messages] simulates
    the evaluation of input [messages] for the rollup PVM at [block] (default
    ["head"]). [reveal_pages] can be used to provide data to be used for the
    revelation ticks. [insight_request] can be used to look at a list of keys in
    the PVM state after the simulation. *)
val simulate :
  ?block:string ->
  Sc_rollup_node.t ->
  ?reveal_pages:string list ->
  ?insight_requests:
    [`Pvm_state_key of string list | `Durable_storage_key of string list] list ->
  string list ->
  simulation_result Lwt.t

(** [commitment_from_json] parses a commitment from its JSON representation. *)
val commitment_from_json : JSON.t -> commitment option

(** [commitment_info_from_json] parses a commitment, its hash and
    the levels when the commitment was first published (if any) and included,
    from the JSON representation. *)
val commitment_info_from_json : JSON.t -> commitment_info option

(** [last_stored_commitment sc_rollup_node] gets the last commitment with its hash
    stored by the rollup node. *)
val last_stored_commitment :
  Sc_rollup_node.t -> commitment_and_hash option Lwt.t

(** [last_published_commitment sc_rollup_node] gets the last commitment published by the
    rollup node, with its hash and level when the commitment was first published
    and the level it was included. *)
val last_published_commitment : Sc_rollup_node.t -> commitment_info option Lwt.t

(** [commitment sc_rollup_node hash] gets commitment by its [hash] from the rollup node,
    with its hash and level when the commitment was first published and the
    level it was included. *)
val commitment : Sc_rollup_node.t -> string -> commitment_info option Lwt.t
