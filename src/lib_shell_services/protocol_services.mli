(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
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

open Mavryk_rpc.Context

val contents : #simple -> Protocol_hash.t -> Protocol.t tzresult Lwt.t

val environment :
  #simple -> Protocol_hash.t -> Protocol.env_version tzresult Lwt.t

val list : #simple -> Protocol_hash.t list tzresult Lwt.t

val fetch : #simple -> Protocol_hash.t -> unit tzresult Lwt.t

module S : sig
  val contents :
    ( [`GET],
      unit,
      unit * Protocol_hash.t,
      unit,
      unit,
      Protocol.t )
    Mavryk_rpc.Service.t

  val environment :
    ( [`GET],
      unit,
      unit * Protocol_hash.t,
      unit,
      unit,
      Protocol.env_version )
    Mavryk_rpc.Service.t

  val list :
    ([`GET], unit, unit, unit, unit, Protocol_hash.t list) Mavryk_rpc.Service.t

  val fetch :
    ( [`GET],
      unit,
      unit * Protocol_hash.t,
      unit,
      unit,
      unit )
    Mavryk_rpc.Service.t
end
