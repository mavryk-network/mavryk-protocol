(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

module Proof = Mavryk_context_sigs.Context.Proof_types

(** A container of input data needed to process a consensus. *)
type input = {
  printer : Mavryk_client_base.Client_context.printer;
  min_agreement : float;  (** The same value as [Light.sources.min_agreement] *)
  chain : Mavryk_shell_services.Block_services.chain;
      (** The chain considered *)
  block : Mavryk_shell_services.Block_services.block;
      (** The block considered *)
  key : string list;
      (** The key of the context for which data is being requested *)
  mproof : Proof.tree Proof.t;
      (** The Merkle proof received from the endpoint providing data.
          It is much smaller than the whole context. *)
}

(** [min_agreeing_endpoints min_agreement nb_endpoints] returns
    the minimum number of endpoints that must agree for [Make.consensus]
    to return [true]. The first parameter should be
    [Light.sources.min_agreement] while the second
    parameter should be the length of [Light.sources.endpoints]. *)
val min_agreeing_endpoints : float -> int -> int

(** Given RPCs specific to the light mode, obtain the consensus
    algorithm *)
module Make (Light_proto : Light_proto.PROTO_RPCS) : sig
  (** Whether consensus on data can be achieved. Parameters are:

      - The data to consider
      - The endpoints to contact for validating

      Returns: whether consensus was attained or an error message.
    *)
  val consensus :
    input -> (Uri.t * Mavryk_rpc.Context.simple) list -> bool Lwt.t
end
