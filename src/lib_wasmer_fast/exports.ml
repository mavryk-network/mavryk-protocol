(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 TriliTech <contact@trili.tech>                         *)
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

(* For documentation please refer to the [Tezos_wasmer] module. *)

open Api

type t = Types.Exports.t Ctypes.ptr

let from_instance inst =
  let exports = Functions.Instance.exports inst.Instance.instance in

  exports

let delete = Functions.Exports.delete

exception Export_not_found of {name : string; kind : Unsigned.uint64}

let () =
  Printexc.register_printer (function
      | Export_not_found {name; kind} ->
          Some
            (Format.asprintf
               "Export %S (%i) not found"
               name
               (Unsigned.UInt64.to_int kind))
      | _ -> None)

let fn exports name typ =
  let extern =
    Functions.Exports.get_function exports (Functions.String.new_ name)
  in
  let func =
    match extern with
    | None -> raise (Export_not_found {name; kind = Unsigned.UInt64.of_int 0})
    | Some extern -> extern
  in
  let f = Function.call func typ in
  () ;
  (* ^ This causes the current function to cap its arity. E.g. in case it gets
     aggressively inlined we make sure that the resulting extern function is
     entirely separate. *)
  f

let mem exports name =
  let mem = Functions.Exports.get_memory exports (Functions.String.new_ name) in
  match mem with
  | Some mem -> mem
  | None -> raise (Export_not_found {name; kind = Unsigned.UInt64.of_int 0})

let mem0 exports =
  let mem = Functions.Exports.get_memory0 exports in
  match mem with
  | Some mem -> mem
  | None ->
      raise (Export_not_found {name = "<0>"; kind = Unsigned.UInt64.of_int 0})
