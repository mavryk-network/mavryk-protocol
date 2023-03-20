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

module type PROTOCOL = sig
  val hash : Tezos_crypto.Hashed.Protocol_hash.t

  val name : string
end

type protocol = (module PROTOCOL)

let name_internal (p : protocol) =
  let module Protocol = (val p) in
  Protocol.name

let hash (p : protocol) =
  let module Protocol = (val p) in
  Protocol.hash

let tezt_protocol (p : protocol) =
  p |> hash |> Tezos_crypto.Hashed.Protocol_hash.to_b58check
  |> Tezt_tezos.Protocol.of_hash_opt

let tag (p : protocol) =
  match tezt_protocol p with
  | Some tezt_protocol -> Tezt_tezos.Protocol.tag tezt_protocol
  | None ->
      name_internal p |> String.lowercase_ascii
      |> String.map (fun c ->
             match c with 'a' .. 'z' | '0' .. '9' -> c | _ -> '_')

let name (p : protocol) =
  match tezt_protocol p with
  | Some tezt_protocol -> Tezt_tezos.Protocol.name tezt_protocol
  | None -> name_internal p
