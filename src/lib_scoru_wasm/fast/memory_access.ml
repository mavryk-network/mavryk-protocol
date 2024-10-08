(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Marigold <contact@marigold.dev>                        *)
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

open Mavryk_scoru_wasm
module Memory = Mavryk_wasmer.Memory
module I32 = Mavryk_webassembly_interpreter.I32

module Wasmer : Host_funcs.Memory_access with type t = Memory.t = struct
  type t = Memory.t

  exception Out_of_bounds = Memory.Out_of_bounds

  let load_bytes memory address length =
    let address = I32.to_int_u address in
    Lwt.return (Memory.get_string memory ~address ~length)

  let store_bytes memory address data =
    let address = I32.to_int_u address in
    Memory.set_string memory ~address ~data ;
    Lwt.return_unit

  let to_bits (num : Mavryk_webassembly_interpreter.Values.num) : int * int64 =
    let open Mavryk_webassembly_interpreter in
    let size = Types.num_size @@ Values.type_of_num num in
    let bits =
      match num with
      | Values.I32 x -> Int64.of_int32 x
      | Values.I64 x -> x
      | Values.F32 x -> Int64.of_int32 @@ F32.to_bits x
      | Values.F64 x -> F64.to_bits x
    in
    (size, bits)

  let store_num memory addr offset num =
    let abs_addr = I32.to_int_u @@ Int32.add addr offset in
    let num_bytes, bits = to_bits num in

    let rec loop steps addr bits =
      if steps > 0 then (
        let lsb = Unsigned.UInt8.of_int @@ (Int64.to_int bits land 0xff) in
        let bits = Int64.shift_right bits 8 in

        Memory.set memory addr lsb ;
        loop (steps - 1) (addr + 1) bits)
    in

    loop num_bytes abs_addr bits ;

    Lwt.return_unit

  let bound (memory : Memory.t) = Int64.of_int (Memory.length memory)

  let exn_to_error ~default = function
    | Out_of_bounds -> Host_funcs.Error.Memory_invalid_access
    | _ -> default
end
