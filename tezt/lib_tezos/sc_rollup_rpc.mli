(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 TriliTech <contact@trili.tech>                    *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*****************************************************************************)

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
