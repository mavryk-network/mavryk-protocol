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

type owned = Types.Function.t Ctypes.ptr

let call_with_inputs params f inputs =
  let rec go : type f r. (f, r) Function_type.params -> f -> int -> r =
   fun params f index ->
    match params with
    | Function_type.End_param -> f
    | Trigger_param params -> (go [@tailcall]) params (f ()) index
    | Cons_param (typ, params) ->
        let value = Ctypes.(!@(inputs +@ index)) |> Value.unpack typ in
        (go [@tailcall]) params (f value) (succ index)
  in
  go params f 0

let pack_outputs results r outputs =
  let rec go : type r. r Function_type.results -> r -> int -> unit =
   fun results value index ->
    match results with
    | Function_type.No_result -> ()
    | Function_type.One_result typ -> Value.push outputs typ value
    | Function_type.Cons_result (typ, results) ->
        let value, xs = value in
        Value.push outputs typ value ;
        (go [@tailcall]) results xs (succ index)
  in
  go results r 0

module Func_callback_maker = (val Types.FunctionCallback.m)

let () =
  (* The Ctypes library tries to detect leaked function pointers. However, this
     does not work correctly for our use cases because we don't keep the
     underlying function pointers on the OCaml side. Instead we pass them to
     Wasmer where they will be kept. This means we mustn't prematurely free
     function pointers just because they are no longer accessible from the
     OCaml side. *)
  Foreign.report_leaked_funptr := Fun.const ()

let create : type f. Store.t -> f Function_type.t -> f -> owned * (unit -> unit)
    =
 fun store typ f ->
  let func_type = Function_type.to_owned typ in
  let (Function_type.Function (params, results)) = typ in
  let run inputs outputs =
    let result =
      Lwt_preemptive.run_in_main (fun () -> call_with_inputs params f inputs)
    in
    pack_outputs results result outputs
  in
  let try_run inputs outputs =
    try
      let () = run inputs outputs in
      None
    with exn -> Some (Functions.String.new_ (Printexc.to_string exn))
  in
  let try_run = Func_callback_maker.of_fun try_run in
  let free () = Func_callback_maker.free try_run in
  let try_run =
    Ctypes.coerce Func_callback_maker.t Types.FunctionCallback.t try_run
  in
  let owned = Functions.Function.new_ store func_type try_run in
  (owned, free)

let call_raw func inputs =
  let open Lwt.Syntax in
  let outputs =
    Ctypes.(
      CArray.make
        (ptr Types.Value.t)
        (Functions.Function.num_results func |> Unsigned.Size_t.to_int))
  in
  let+ trap =
    Lwt_preemptive.detach
      (fun (inputs, outputs) ->
        Functions.Function.call func inputs (Ctypes.CArray.start outputs))
      (inputs, outputs)
  in
  Trap.check trap ;
  outputs

let pack_inputs (type x r) (params : (x, r Lwt.t) Function_type.params) func
    (unpack : Types.Value.t Ctypes.ptr Ctypes.carray -> r) =
  let open Lwt.Syntax in
  let inputs = Functions.ValueVector.new_ (Function_type.num_params params) in
  let rec go_params : type f. (f, r Lwt.t) Function_type.params -> int -> f =
   fun params index ->
    match params with
    | Function_type.End_param ->
        print_endline "> start call_raw" ;
        let+ outputs = call_raw func inputs in
        print_endline "> end call_raw" ;
        unpack outputs
    | Trigger_param params -> fun () -> (go_params [@tailcall]) params index
    | Cons_param (typ, params) ->
        fun x ->
          Value.push inputs typ x ;
          (go_params [@tailcall]) params (succ index)
  in
  go_params params 0

exception
  Not_enough_outputs of {expected : Unsigned.size_t; got : Unsigned.size_t}

let () =
  Printexc.register_printer (function
      | Not_enough_outputs {got; expected} ->
          Some
            (Printf.sprintf
               "Function did return less values (%s) than expected (%s)"
               (Unsigned.Size_t.to_string got)
               (Unsigned.Size_t.to_string got))
      | _ -> None)

let unpack_outputs results outputs =
  let got = Ctypes.CArray.length outputs |> Unsigned.Size_t.of_int in
  let expected = Function_type.num_results results in
  if (* Fewer outputs than expected. *)
     Unsigned.Size_t.compare got expected < 0
  then raise (Not_enough_outputs {got; expected}) ;
  let rec go : type r x. r Function_type.results -> int -> (r -> x) -> x =
   fun params index k ->
    match params with
    | Function_type.No_result -> k ()
    | Function_type.One_result typ ->
        Ctypes.CArray.get outputs index |> Value.unpack typ |> k
    | Function_type.Cons_result (typ, results) ->
        let x = Ctypes.CArray.get outputs index |> Value.unpack typ in
        (go [@tailcall]) results (succ index) (fun xs -> k (x, xs))
  in
  go results 0 Fun.id

let call func typ =
  let func_type = Functions.Function.type_ func in
  Function_type.check_types typ func_type ;
  (* Once the types have been checked, [func_type] can be deleted. *)
  Functions.FunctionType.delete func_type ;
  let (Function_type.Function (params, results)) = typ in
  pack_inputs params func (unpack_outputs results)
