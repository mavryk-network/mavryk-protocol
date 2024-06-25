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

let id = "mav"

let name = "mumav"

open Compare.Int64 (* invariant: positive *)

type repr = t

type t = Tez_tag of repr [@@ocaml.unboxed]

let wrap t = Tez_tag t [@@ocaml.inline always]

type error +=
  | Addition_overflow of t * t (* `Temporary *)
  | Subtraction_underflow of t * t (* `Temporary *)
  | Multiplication_overflow of t * Z.t (* `Temporary *)
  | Negative_multiplicator of t * Z.t (* `Temporary *)
  | Invalid_divisor of t * Z.t

(* `Temporary *)

let zero = Tez_tag 0L

(* all other constant are defined from the value of one micro mav *)
let one_mumav = Tez_tag 1L

let max_mumav = Tez_tag Int64.max_int

let mul_int (Tez_tag mav) i = Tez_tag (Int64.mul mav i)

let one_cent = mul_int one_mumav 10_000L

let fifty_cents = mul_int one_cent 50L

(* 1 mav = 100 cents = 1_000_000 mumav *)
let one = mul_int one_cent 100L

let of_string s =
  let triplets = function
    | hd :: tl ->
        let len = String.length hd in
        Compare.Int.(
          len <= 3 && len > 0 && List.for_all (fun s -> String.length s = 3) tl)
    | [] -> false
  in
  let integers s = triplets (String.split_on_char ',' s) in
  let decimals s =
    let l = String.split_on_char ',' s in
    if Compare.List_length_with.(l > 2) then false else triplets (List.rev l)
  in
  let parse left right =
    let remove_commas s = String.concat "" (String.split_on_char ',' s) in
    let pad_to_six s =
      let len = String.length s in
      String.init 6 (fun i -> if Compare.Int.(i < len) then s.[i] else '0')
    in
    let prepared = remove_commas left ^ pad_to_six (remove_commas right) in
    Option.map wrap (Int64.of_string_opt prepared)
  in
  match String.split_on_char '.' s with
  | [left; right] ->
      if String.contains s ',' then
        if integers left && decimals right then parse left right else None
      else if
        Compare.Int.(String.length right > 0)
        && Compare.Int.(String.length right <= 6)
      then parse left right
      else None
  | [left] ->
      if (not (String.contains s ',')) || integers left then parse left ""
      else None
  | _ -> None

let pp ppf (Tez_tag amount) =
  let mult_int = 1_000_000L in
  let rec left ppf amount =
    let d, r = (Int64.div amount 1000L, Int64.rem amount 1000L) in
    if Compare.Int64.(d > 0L) then Format.fprintf ppf "%a%03Ld" left d r
    else Format.fprintf ppf "%Ld" r
  in
  let right ppf amount =
    let triplet ppf v =
      if Compare.Int.(v mod 10 > 0) then Format.fprintf ppf "%03d" v
      else if Compare.Int.(v mod 100 > 0) then Format.fprintf ppf "%02d" (v / 10)
      else Format.fprintf ppf "%d" (v / 100)
    in
    let hi, lo = (amount / 1000, amount mod 1000) in
    if Compare.Int.(lo = 0) then Format.fprintf ppf "%a" triplet hi
    else Format.fprintf ppf "%03d%a" hi triplet lo
  in
  let ints, decs =
    (Int64.div amount mult_int, Int64.(to_int (rem amount mult_int)))
  in
  left ppf ints ;
  if Compare.Int.(decs > 0) then Format.fprintf ppf ".%a" right decs

let to_string t = Format.asprintf "%a" pp t

let ( -? ) mav1 mav2 =
  let open Result_syntax in
  let (Tez_tag t1) = mav1 in
  let (Tez_tag t2) = mav2 in
  if t2 <= t1 then return (Tez_tag (Int64.sub t1 t2))
  else tzfail (Subtraction_underflow (mav1, mav2))

let sub_opt (Tez_tag t1) (Tez_tag t2) =
  if t2 <= t1 then Some (Tez_tag (Int64.sub t1 t2)) else None

let ( +? ) mav1 mav2 =
  let open Result_syntax in
  let (Tez_tag t1) = mav1 in
  let (Tez_tag t2) = mav2 in
  let t = Int64.add t1 t2 in
  if t < t1 then tzfail (Addition_overflow (mav1, mav2)) else return (Tez_tag t)

let ( *? ) mav m =
  let open Result_syntax in
  let (Tez_tag t) = mav in
  if m < 0L then tzfail (Negative_multiplicator (mav, Z.of_int64 m))
  else if m = 0L then return (Tez_tag 0L)
  else if t > Int64.(div max_int m) then
    tzfail (Multiplication_overflow (mav, Z.of_int64 m))
  else return (Tez_tag (Int64.mul t m))

let ( /? ) mav d =
  let open Result_syntax in
  let (Tez_tag t) = mav in
  if d <= 0L then tzfail (Invalid_divisor (mav, Z.of_int64 d))
  else return (Tez_tag (Int64.div t d))

let div2 (Tez_tag t) = Tez_tag (Int64.div t 2L)

let mul_exn t m =
  match t *? Int64.of_int m with Ok v -> v | Error _ -> invalid_arg "mul_exn"

let div_exn t d =
  match t /? Int64.of_int d with Ok v -> v | Error _ -> invalid_arg "div_exn"

let mul_ratio_z ~rounding mav ~num ~den =
  let open Result_syntax in
  let (Tez_tag t) = mav in
  if Z.(lt num zero) then tzfail (Negative_multiplicator (mav, num))
  else if Z.(leq den zero) then tzfail (Invalid_divisor (mav, den))
  else
    let numerator = Z.(mul (of_int64 t) num) in
    let z =
      match rounding with
      | `Down -> Z.div numerator den
      | `Up -> Z.cdiv numerator den
    in
    if Z.fits_int64 z then return (Tez_tag (Z.to_int64 z))
    else tzfail (Multiplication_overflow (mav, num))

let mul_ratio ~rounding mav ~num ~den =
  mul_ratio_z ~rounding mav ~num:(Z.of_int64 num) ~den:(Z.of_int64 den)

let mul_q ~rounding mav {Q.num; den} = mul_ratio_z ~rounding mav ~num ~den

let mul_percentage ~rounding (Tez_tag t) (percentage : Percentage.t) =
  let {Q.num; den} = Percentage.to_q percentage in
  (* Guaranteed to produce no errors by the invariants on {!Percentage.t}. *)
  let div' = match rounding with `Down -> Z.div | `Up -> Z.cdiv in
  Tez_tag Z.(to_int64 (div' (mul (of_int64 t) num) den))

let of_mumav t = if t < 0L then None else Some (Tez_tag t)

let of_mumav_exn x =
  match of_mumav x with None -> invalid_arg "Tez.of_mumav" | Some v -> v

let to_mumav (Tez_tag t) = t

let encoding =
  let open Data_encoding in
  let decode (Tez_tag t) = Z.of_int64 t in
  let encode = Json.wrap_error (fun i -> Tez_tag (Z.to_int64 i)) in
  Data_encoding.def name (check_size 10 (conv decode encode n))

let balance_update_encoding =
  let open Data_encoding in
  conv
    (function
      | `Credited v -> to_mumav v | `Debited v -> Int64.neg (to_mumav v))
    ( Json.wrap_error @@ fun v ->
      if Compare.Int64.(v < 0L) then `Debited (Tez_tag (Int64.neg v))
      else `Credited (Tez_tag v) )
    int64

let () =
  let open Data_encoding in
  register_error_kind
    `Temporary
    ~id:(id ^ ".addition_overflow")
    ~title:("Overflowing " ^ id ^ " addition")
    ~pp:(fun ppf (opa, opb) ->
      Format.fprintf
        ppf
        "Overflowing addition of %a %s and %a %s"
        pp
        opa
        id
        pp
        opb
        id)
    ~description:("An addition of two " ^ id ^ " amounts overflowed")
    (obj1 (req "amounts" (tup2 encoding encoding)))
    (function Addition_overflow (a, b) -> Some (a, b) | _ -> None)
    (fun (a, b) -> Addition_overflow (a, b)) ;
  register_error_kind
    `Temporary
    ~id:(id ^ ".subtraction_underflow")
    ~title:("Underflowing " ^ id ^ " subtraction")
    ~pp:(fun ppf (opa, opb) ->
      Format.fprintf
        ppf
        "Underflowing subtraction of %a %s and %a %s"
        pp
        opa
        id
        pp
        opb
        id)
    ~description:
      ("A subtraction of two " ^ id
     ^ " amounts underflowed (i.e., would have led to a negative amount)")
    (obj1 (req "amounts" (tup2 encoding encoding)))
    (function Subtraction_underflow (a, b) -> Some (a, b) | _ -> None)
    (fun (a, b) -> Subtraction_underflow (a, b)) ;
  register_error_kind
    `Temporary
    ~id:(id ^ ".multiplication_overflow")
    ~title:("Overflowing " ^ id ^ " multiplication")
    ~pp:(fun ppf (opa, opb) ->
      Format.fprintf
        ppf
        "Overflowing multiplication of %a %s and %a"
        pp
        opa
        id
        Z.pp_print
        opb)
    ~description:
      ("A multiplication of a " ^ id ^ " amount by an integer overflowed")
    (obj2 (req "amount" encoding) (req "multiplicator" z))
    (function Multiplication_overflow (a, b) -> Some (a, b) | _ -> None)
    (fun (a, b) -> Multiplication_overflow (a, b)) ;
  register_error_kind
    `Temporary
    ~id:(id ^ ".negative_multiplicator")
    ~title:("Negative " ^ id ^ " multiplicator")
    ~pp:(fun ppf (opa, opb) ->
      Format.fprintf
        ppf
        "Multiplication of %a %s by negative integer %a"
        pp
        opa
        id
        Z.pp_print
        opb)
    ~description:("Multiplication of a " ^ id ^ " amount by a negative integer")
    (obj2 (req "amount" encoding) (req "multiplicator" z))
    (function Negative_multiplicator (a, b) -> Some (a, b) | _ -> None)
    (fun (a, b) -> Negative_multiplicator (a, b)) ;
  register_error_kind
    `Temporary
    ~id:(id ^ ".invalid_divisor")
    ~title:("Invalid " ^ id ^ " divisor")
    ~pp:(fun ppf (opa, opb) ->
      Format.fprintf
        ppf
        "Division of %a %s by non positive integer %a"
        pp
        opa
        id
        Z.pp_print
        opb)
    ~description:
      ("Multiplication of a " ^ id ^ " amount by a non positive integer")
      (obj2 (req "amount" encoding) (req "divisor" z))
    (function Invalid_divisor (a, b) -> Some (a, b) | _ -> None)
    (fun (a, b) -> Invalid_divisor (a, b))

let compare (Tez_tag x) (Tez_tag y) = compare x y

let ( = ) (Tez_tag x) (Tez_tag y) = x = y

let ( <> ) (Tez_tag x) (Tez_tag y) = x <> y

let ( < ) (Tez_tag x) (Tez_tag y) = x < y

let ( > ) (Tez_tag x) (Tez_tag y) = x > y

let ( <= ) (Tez_tag x) (Tez_tag y) = x <= y

let ( >= ) (Tez_tag x) (Tez_tag y) = x >= y

let equal (Tez_tag x) (Tez_tag y) = equal x y

let max (Tez_tag x) (Tez_tag y) = Tez_tag (max x y)

let min (Tez_tag x) (Tez_tag y) = Tez_tag (min x y)
