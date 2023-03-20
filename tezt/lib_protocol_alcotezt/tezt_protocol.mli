(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
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

(** This module provides a bridge between the a Tezos protocols own
    notion of a protocol (a [Protocol] module) and Tezts
    [Protocol.t]. It is used to simplify registration of Alcotezts in
    protocols while enforcing a test naming and tagging policies. *)

(** Minimal signature of a Protocol. *)
module type PROTOCOL = sig
  val hash : Tezos_crypto.Hashed.Protocol_hash.t

  val name : string
end

(** [protocol] packs modules of signature [PROTOCOL]. *)
type protocol = (module PROTOCOL)

(** Return the "pretty name" of a [protocol].

    The pretty name is the same as defined by
    {!Tezt_tezos.Protocol.name}, that is, the capitalized,
    non-numbered name of a protocol, e.g. [Alpha], [Mumbai], ... *)
val name : protocol -> string

(** The protocol-specific Tezt tag of this prototcol

    The protocol tag is the same as defined by
    {!Tezt_tezos.Protocol.tag}, that is, the lower-cased "pretty" name
    of the protocol (e.g. [alpha], [mumbai], ...). *)
val tag : protocol -> string
