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

exception
  Kind_mismatch of {expected : Types.ValueType.t; got : Types.ValueType.t}

let check_kind value expected =
  let got = Functions.Value.type_ value in
  if expected <> got then raise (Kind_mismatch {expected; got})

let unpack : type a. a Value_type.t -> Types.Value.t Ctypes.ptr -> a =
 fun typ value ->
  match typ with
  | I32 ->
      check_kind value Types.ValueType.I32 ;
      Functions.Value.i32 value
  | I64 ->
      check_kind value Types.ValueType.I64 ;
      Functions.Value.i64 value
  | F32 ->
      check_kind value Types.ValueType.F32 ;
      Functions.Value.f32 value
  | F64 ->
      check_kind value Types.ValueType.F64 ;
      Functions.Value.f64 value
  | ExternRef ->
      check_kind value Types.ValueType.ExternRef ;
      failwith "TODO"
  | FuncRef ->
      check_kind value Types.ValueType.FuncRef ;
      failwith "TODO"

let push : type a. Types.ValueVector.t Ctypes.ptr -> a Value_type.t -> a -> unit
    =
 fun vec typ value ->
  match typ with
  | I32 -> Functions.ValueVector.add_i32 vec value
  | I64 -> Functions.ValueVector.add_i64 vec value
  | F32 -> Functions.ValueVector.add_f32 vec value
  | F64 -> Functions.ValueVector.add_f64 vec value
  | ExternRef -> failwith "TODO"
  | FuncRef -> failwith "TODO"
