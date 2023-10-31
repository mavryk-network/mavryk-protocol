(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Trilitech <contact@trili.tech>                         *)
(*                                                                           *)
(*****************************************************************************)

include Tezos_base.TzPervasives.Result_syntax

let ( let*@ ) m f =
  let* x = Environment.wrap_tzresult m in
  f x

let ( let+@ ) m f =
  let+ x = Environment.wrap_tzresult m in
  f x
