(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2020-2022 Nomadic Labs <contact@nomadic-labs.com>           *)
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

(** Internal representation of the Tez currency. Behaves mostly like a natural
   number where number 1 represents 1/1,000,000 Tez (1 micro-Tez or mumav).
   It's protected from ever becoming negative and overflowing by special
   arithmetic functions, which fail in case something undesired would happen.
   When divided, it's always rounded down to 1 mumav.

   Internally encoded as [int64], which may be relevant to guard against
   overflow errors. *)
type repr

(** [t] is made algebraic in order to distinguish it from the other type
    parameters of [Script_typed_ir.ty]. *)
type t = Tez_tag of repr [@@ocaml.unboxed]

type error +=
  | Addition_overflow of t * t (* `Temporary *)
  | Subtraction_underflow of t * t (* `Temporary *)
  | Multiplication_overflow of t * int64 (* `Temporary *)
  | Negative_multiplicator of t * int64 (* `Temporary *)
  | Invalid_divisor of t * int64 (* `Temporary *)

type mav = t

val zero : t

val one_mumav : t

val one_cent : t

val fifty_cents : t

val one : t

val max_mumav : t

val ( -? ) : t -> t -> t tzresult

(** Same as ( -? ) but returns None instead of an error. *)
val sub_opt : t -> t -> t option

val ( +? ) : t -> t -> t tzresult

val ( *? ) : t -> int64 -> t tzresult

val ( /? ) : t -> int64 -> t tzresult

val div2 : t -> t

(** [div2_sub mav] returns [(⌊mav / 2⌋, mav - ⌊mav / 2⌋)]. *)
val div2_sub : t -> t * t

(** [mul_ratio ~rounding mav ~num ~den] returns [mav * num / den] without failing
    when [mav * num] overflows.
    [rounding] controls the rounding of the division. *)
val mul_ratio :
  rounding:[`Down | `Up] -> t -> num:int64 -> den:int64 -> t tzresult

(** [mul_percentage mav percentage] returns [mav * percentage / 100].
    No errors can happen. *)
val mul_percentage : rounding:[`Down | `Up] -> t -> Int_percentage.t -> t

val to_mumav : t -> int64

(** [of_mumav n] (micro mav) is None if n is negative *)
val of_mumav : int64 -> t option

(** [of_mumav_exn n] fails if n is negative.
    It should only be used at toplevel for constants. *)
val of_mumav_exn : int64 -> t

(** It should only be used at toplevel for constants. *)
val mul_exn : t -> int -> t

(** It should only be used at toplevel for constants. *)
val div_exn : t -> int -> t

val encoding : t Data_encoding.t

val balance_update_encoding : [`Credited of t | `Debited of t] Data_encoding.t

include Compare.S with type t := t

val pp : Format.formatter -> t -> unit

val of_string : string -> t option

val to_string : t -> string
