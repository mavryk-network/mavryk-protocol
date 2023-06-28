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

module Array = Ctypes.CArray

exception Out_of_bounds

type t = {
  raw : char Array.t;
  min : Unsigned.uint32;
  max : Unsigned.uint32 option;
}

let length mem = Array.length mem.raw

let bad_bounds mem addr len = addr < 0 || len > length mem - addr

let check_bounds mem addr len =
  if bad_bounds mem addr len then raise Out_of_bounds

let get mem addr =
  check_bounds mem addr 1 ;
  Array.unsafe_get mem.raw addr

let unsafe_get_string_slow mem ~address ~length =
  String.init length @@ fun i -> Array.unsafe_get mem.raw (i + address)

let unsafe_get_string_fast mem ~address ~length =
  let address = Ctypes.(Array.start mem.raw +@ address) in
  Ctypes.string_from_ptr address ~length

let get_string mem ~address ~length =
  check_bounds mem address length ;
  let func =
    if length >= 64 then unsafe_get_string_fast else unsafe_get_string_slow
  in
  func mem ~address ~length

let set mem addr value =
  check_bounds mem addr 1 ;
  Array.unsafe_set mem.raw addr value

let set_string mem ~address ~data =
  let len = String.length data in
  if len > 0 then (
    (* For compatibility we only check bounds when something shall be written. *)
    check_bounds mem address len ;
    Memcpy.memcpy_from_string
      Memcpy.carray
      ~src:data
      ~dst:mem.raw
      ~dst_off:address)

module Internal_for_tests = struct
  let of_list (content : char list) =
    let mem_length = List.length content in
    let page_size = 0x10000 in
    let pages = mem_length / page_size in

    assert (Int.rem mem_length page_size = 0) ;

    {
      raw = Array.of_list Ctypes.char content;
      min = Unsigned.UInt32.of_int pages;
      max = None;
    }

  let to_list (mem : t) = Array.to_list mem.raw
end
