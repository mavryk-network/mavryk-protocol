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
module Array = Ctypes.CArray

exception Out_of_bounds

type t = Types.Memory.t Ctypes.ptr

let length mem = Functions.Memory.data_size mem |> Unsigned.UInt64.to_int

(*
let bad_bounds mem addr len = addr < 0 || len > length mem - addr

let check_bounds mem addr len =
  if bad_bounds mem addr len then raise Out_of_bounds
*)

let get mem addr =
  let value = Functions.Memory.read_u8 mem (Unsigned.UInt64.of_int addr) in
  if value = Unsigned.UInt16.max_int then raise Out_of_bounds ;
  Unsigned.UInt8.of_int (Unsigned.UInt16.to_int value)

let get_string mem ~address ~length =
  let buffer = Ctypes.(CArray.make uint8_t length) in
  let r =
    Functions.Memory.read
      mem
      (Unsigned.UInt64.of_int address)
      (Ctypes.CArray.start buffer)
      (Unsigned.Size_t.of_int length)
  in
  if not r then raise Out_of_bounds ;
  Ctypes.(
    string_from_ptr
      (CArray.start buffer |> coerce (ptr uint8_t) (ptr char))
      ~length)

let set mem addr value =
  let r = Functions.Memory.write_u8 mem (Unsigned.UInt64.of_int addr) value in
  if not r then raise Out_of_bounds

let set_string mem ~address ~data =
  let len = String.length data in
  if len > 0 then
    (* For compatibility we only check bounds when something shall be written. *)
    let buffer = Ctypes.CArray.of_string data in
    let r =
      Functions.Memory.write
        mem
        (Unsigned.UInt64.of_int address)
        Ctypes.(coerce (ptr char) (ptr uint8_t) (CArray.start buffer))
        (Unsigned.Size_t.of_int len)
    in
    if not r then raise Out_of_bounds

module Internal_for_tests = struct
  let internal_store =
    Lazy.from_fun (fun () ->
        let engine = Engine.create () in
        Store.create engine)

  let of_list (content : Unsigned.uint8 list) =
    let mem_length = List.length content in
    let page_size = 0x10000 in
    let pages = mem_length / page_size in
    assert (Int.rem mem_length page_size = 0) ;

    let store = Lazy.force internal_store in
    let mem = Functions.Memory.new_ store (Unsigned.UInt32.of_int pages) in
    Utils.check_null_ptr Error.(make_exception Create_memory) mem ;
    mem

  let to_list (mem : t) =
    let len = Functions.Memory.data_size mem in
    let buffer = Ctypes.(CArray.make uint8_t (Unsigned.UInt64.to_int len)) in
    let r =
      Functions.Memory.read
        mem
        Unsigned.UInt64.zero
        (Ctypes.CArray.start buffer)
        (Unsigned.Size_t.of_int (Unsigned.UInt64.to_int len))
    in
    if not r then raise Out_of_bounds ;
    Ctypes.CArray.to_list buffer
end
