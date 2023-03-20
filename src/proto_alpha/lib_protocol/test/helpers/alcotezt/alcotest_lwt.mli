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

(** Protocol-specific Alcotezt_lwt wrapper. *)

(** This modules shadows the function [run] in
    [Octez_alcotezt.Alcotest_lwt] to automatically add the protocol name
    to the title and tags of registered tests. *)
include module type of Octez_alcotezt.Alcotest_lwt

(** Shadowed version of {!Octez_alcotezt.Alcotest_lwt.run}, with
    protocol-prefixed titles and protocol-specific tags.

    This modules shadows the function [run] in
    [Octez_alcotezt.Alcotest] to prefix Alcotest suite names with the
    "pretty" version of the protocol name (e.g. [Alpha], [Mumbai],
    ... ). It also adds a tag to each registered test identifying the
    test. As in integration tests, this is the pretty name lowercased
    (e.g. [alpha], [mumbai]). *)
val run :
  __FILE__:string -> ?tags:string list -> string -> unit test list -> return
