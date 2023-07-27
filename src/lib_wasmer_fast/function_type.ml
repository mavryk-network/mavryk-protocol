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

type (_, _) params =
  | End_param : ('r, 'r) params
  | Trigger_param : ('a, 'r) params -> (unit -> 'a, 'r) params
  | Cons_param : 'a Value_type.t * ('b, 'r) params -> ('a -> 'b, 'r) params

let num_params params =
  let rec go : type f r. (f, r) params -> Unsigned.size_t -> Unsigned.size_t =
   fun params num ->
    match params with
    | End_param -> num
    | Trigger_param params -> (go [@tailcail]) params num
    | Cons_param (_, params) ->
        (go [@tailcail]) params (Unsigned.Size_t.succ num)
  in
  go params Unsigned.Size_t.zero

let param_types params =
  let inputs =
    Ctypes.CArray.make
      Types.ValueType.t
      (num_params params |> Unsigned.Size_t.to_int)
  in
  let set_type index typ =
    Ctypes.CArray.set inputs index (Value_type.to_wasmer typ)
  in
  let rec go : type f r. (f, r) params -> int -> unit =
   fun params index ->
    match params with
    | End_param -> ()
    | Trigger_param params -> (go [@tailcail]) params index
    | Cons_param (typ, params) ->
        set_type index typ ;
        (go [@tailcail]) params (succ index)
  in
  go params 0 ;
  inputs

type _ results =
  | No_result : unit results
  | One_result : 'a Value_type.t -> 'a results
  | Cons_result : 'a Value_type.t * 'b results -> ('a * 'b) results

let num_results results =
  let rec go : type r. r results -> Unsigned.size_t -> Unsigned.size_t =
   fun results num ->
    match results with
    | No_result -> num
    | One_result _ -> Unsigned.Size_t.succ num
    | Cons_result (_, results) ->
        (go [@tailcail]) results (Unsigned.Size_t.succ num)
  in
  go results Unsigned.Size_t.zero

let result_types results =
  let outputs =
    Ctypes.CArray.make
      Types.ValueType.t
      (num_results results |> Unsigned.Size_t.to_int)
  in
  let set_type index typ =
    Ctypes.CArray.set outputs index (Value_type.to_wasmer typ)
  in
  let rec go : type r. r results -> int -> unit =
   fun results index ->
    match results with
    | No_result -> ()
    | One_result typ -> set_type index typ
    | Cons_result (typ, results) ->
        set_type index typ ;
        (go [@tailcail]) results (succ index)
  in
  go results 0 ;
  outputs

type 'f t = Function : ('f, 'r Lwt.t) params * 'r results -> 'f t

let to_owned (Function (params, results)) =
  let inputs = param_types params in
  let outputs = result_types results in
  let type_ =
    Functions.FunctionType.new_
      (Ctypes.CArray.start inputs)
      (Ctypes.CArray.length inputs |> Unsigned.Size_t.of_int)
      (Ctypes.CArray.start outputs)
      (Ctypes.CArray.length outputs |> Unsigned.Size_t.of_int)
  in
  type_

exception
  Wrong_number_of_params of {expected : Unsigned.size_t; got : Unsigned.size_t}

let () =
  Printexc.register_printer (function
      | Wrong_number_of_params {expected; got} ->
          Some
            (Printf.sprintf
               "Wrong number of parameters: expected %s, got %s"
               (Unsigned.Size_t.to_string expected)
               (Unsigned.Size_t.to_string got))
      | _ -> None)

let check_param_types params param_types =
  let expected = num_params params in
  let got = Unsigned.Size_t.of_int (Ctypes.CArray.length param_types) in
  if
    (* Fewer or more params than expected. *)
    not (Unsigned.Size_t.equal expected got)
  then raise (Wrong_number_of_params {got; expected}) ;
  let rec go : type f r. (f, r) params -> int -> unit =
   fun params index ->
    match params with
    | End_param -> ()
    | Trigger_param params -> (go [@tailcail]) params index
    | Cons_param (expected, params) ->
        Ctypes.CArray.get param_types index |> Value_type.check expected ;
        (go [@tailcail]) params (succ index)
  in
  go params 0

exception
  Not_enough_results of {expected : Unsigned.size_t; got : Unsigned.size_t}

let () =
  Printexc.register_printer (function
      | Not_enough_results {expected; got} ->
          Some
            (Printf.sprintf
               "Not enough results: expected %s, got %s"
               (Unsigned.Size_t.to_string expected)
               (Unsigned.Size_t.to_string got))
      | _ -> None)

let check_result_types results result_types =
  let expected = num_results results in
  let got = Unsigned.Size_t.of_int (Ctypes.CArray.length result_types) in
  if (* Fewer resuls than expected. *)
     Unsigned.Size_t.compare got expected < 0
  then raise (Not_enough_results {got; expected}) ;
  let rec go : type r. r results -> int -> unit =
   fun results index ->
    match results with
    | No_result -> ()
    | One_result expected ->
        Ctypes.CArray.get result_types index |> Value_type.check expected
    | Cons_result (expected, results) ->
        Ctypes.CArray.get result_types index |> Value_type.check expected ;
        (go [@tailcail]) results (succ index)
  in
  go results 0

exception Function_type_mismatch of {reason : exn}

let () =
  Printexc.register_printer (function
      | Function_type_mismatch {reason} ->
          Some
            (Printf.sprintf
               "Function type does not match: %s"
               (Printexc.to_string reason))
      | _ -> None)

let check_types (Function (params, results)) func_type =
  try
    let param_types =
      Ctypes.CArray.make
        Types.ValueType.t
        (Functions.FunctionType.num_params func_type |> Unsigned.Size_t.to_int)
    in
    Functions.FunctionType.params func_type (Ctypes.CArray.start param_types) ;
    check_param_types params param_types ;
    let result_types =
      Ctypes.CArray.make
        Types.ValueType.t
        (Functions.FunctionType.num_results func_type |> Unsigned.Size_t.to_int)
    in
    Functions.FunctionType.results func_type (Ctypes.CArray.start result_types) ;
    check_result_types results result_types
  with exn -> raise (Function_type_mismatch {reason = exn})
