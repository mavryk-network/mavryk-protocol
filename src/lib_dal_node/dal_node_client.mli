(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Trili Tech <contact@trili.tech>                        *)
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

open Mavryk_crypto_dal

(** Instance of [Mavryk_client_base.Client_context] that only handles IOs and
    RPCs. Can be used for keys and RPCs related commands. *)
class type cctxt =
  object
    inherit Mavryk_rpc.Context.generic
  end

(** Instance of [cctxt] for linux systems. Relies on
    [Mavryk_rpc_http_client_unix]. *)
class unix_cctxt :
  rpc_config:Mavryk_rpc_http_client_unix.RPC_client_unix.config -> cctxt

(** [make_unix_context endpoint] generates a cctxt with the provided
    [endpoint]. *)
val make_unix_cctxt : Uri.t -> cctxt

val get_slot : #cctxt -> Cryptobox.Commitment.t -> Cryptobox.slot tzresult Lwt.t

(** [get_slot_pages cctxt header ] fetches from the dal node the pages
    of the slot with header [header]. *)
val get_slot_pages :
  #cctxt -> Cryptobox.Commitment.t -> bytes list tzresult Lwt.t

(** [get_page_proof cctxt page_index slot_data] computes and returns the proof
    of the page whose index and slot are given. *)
val get_page_proof :
  #cctxt -> int -> bytes -> Cryptobox.page_proof tzresult Lwt.t
