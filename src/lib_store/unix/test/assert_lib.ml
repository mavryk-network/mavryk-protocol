(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs. <contact@nomadic-labs.com>               *)
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

(** [assert_lib] contains Alcotest convenience assertions depending on Mavryk_base. *)

module Assert = Mavryk_test_helpers.Assert

module Crypto = struct
  let equal_operation ?loc ?msg op1 op2 =
    let eq = Option.equal Mavryk_base.Operation.equal in
    let pp ppf = function
      | None -> Format.pp_print_string ppf "none"
      | Some op ->
          Format.pp_print_string ppf
          @@ Mavryk_crypto.Hashed.Operation_hash.to_b58check
               (Mavryk_base.Operation.hash op)
    in
    Assert.equal ?loc ?msg ~pp ~eq op1 op2

  let equal_block ?loc ?msg st1 st2 =
    let eq st1 st2 = Mavryk_base.Block_header.equal st1 st2 in
    let pp ppf st =
      Format.fprintf
        ppf
        "@[<v 2>%a@ %a@]"
        Mavryk_crypto.Hashed.Block_hash.pp
        (Mavryk_base.Block_header.hash st)
        Data_encoding.Json.pp
        (Data_encoding.Json.construct Mavryk_base.Block_header.encoding st)
    in
    Assert.equal ?loc ?msg ~pp ~eq st1 st2

  let equal_block_set ?loc ?msg set1 set2 =
    let b1 = Mavryk_crypto.Hashed.Block_hash.Set.elements set1
    and b2 = Mavryk_crypto.Hashed.Block_hash.Set.elements set2 in
    Assert.equal_list
      ?loc
      ?msg
      ~eq:Mavryk_crypto.Hashed.Block_hash.equal
      ~pp:Mavryk_crypto.Hashed.Block_hash.pp
      b1
      b2

  let equal_block_map ~eq ?loc ?msg map1 map2 =
    let b1 = Mavryk_crypto.Hashed.Block_hash.Map.bindings map1
    and b2 = Mavryk_crypto.Hashed.Block_hash.Map.bindings map2 in
    Assert.equal_list
      ?loc
      ?msg
      ~eq:(fun (h1, b1) (h2, b2) ->
        Mavryk_crypto.Hashed.Block_hash.equal h1 h2 && eq b1 b2)
      ~pp:(fun ppf (h, _) -> Mavryk_crypto.Hashed.Block_hash.pp ppf h)
      b1
      b2

  let equal_block_hash_list ?loc ?msg l1 l2 =
    let pp = Mavryk_crypto.Hashed.Block_hash.pp_short in
    Assert.equal_list
      ?loc
      ?msg
      ~eq:Mavryk_crypto.Hashed.Block_hash.equal
      ~pp
      l1
      l2

  let equal_block_descriptor ?loc ?msg bd1 bd2 =
    let eq (l1, h1) (l2, h2) =
      Int32.equal l1 l2 && Mavryk_crypto.Hashed.Block_hash.equal h1 h2
    in
    let pp ppf (l, h) =
      Format.fprintf ppf "(%ld, %a)" l Mavryk_crypto.Hashed.Block_hash.pp h
    in
    Assert.equal ?loc ?msg ~pp ~eq bd1 bd2
end
