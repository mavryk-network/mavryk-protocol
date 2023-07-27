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

open Api

type _ t =
  | I32 : int32 t
  | I64 : int64 t
  | F32 : float t
  | F64 : float t
  | ExternRef : Ref.t t
  | FuncRef : Ref.t t

let to_wasmer : type a. a t -> Types.ValueType.t = function
  | I32 -> Types.ValueType.I32
  | I64 -> Types.ValueType.I64
  | F32 -> Types.ValueType.F32
  | F64 -> Types.ValueType.F64
  | ExternRef -> Types.ValueType.ExternRef
  | FuncRef -> Types.ValueType.FuncRef

exception
  Type_mismatch of {expected : Types.ValueType.t; got : Types.ValueType.t}

let () =
  Printexc.register_printer (function
      | Type_mismatch {expected; got} ->
          Some
            (Format.asprintf
               "Type mismatch: %a <> %a"
               Types.ValueType.pp
               expected
               Types.ValueType.pp
               got)
      | _ -> None)

let check : type a. a t -> Types.ValueType.t -> unit =
 fun typ got ->
  let check_assertion expected =
    if not (Types.ValueType.equal got expected) then
      raise (Type_mismatch {got; expected})
  in
  match typ with
  | I32 -> check_assertion Types.ValueType.I32
  | I64 -> check_assertion Types.ValueType.I64
  | F32 -> check_assertion Types.ValueType.F32
  | F64 -> check_assertion Types.ValueType.F64
  | ExternRef -> check_assertion Types.ValueType.ExternRef
  | FuncRef -> check_assertion Types.ValueType.FuncRef
