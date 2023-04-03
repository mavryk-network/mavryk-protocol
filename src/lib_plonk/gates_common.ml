(*****************************************************************************)
(*                                                                           *)
(* MIT License                                                               *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
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

open Bls
open Identities
module L = Plompiler.LibCircuit

type public = {public_inputs : Scalar.t array; input_coms_size : int}

let one = Scalar.one

let mone = Scalar.negate one

let two = Scalar.add one one

let left = "a"

let right = "b"

let output = "c"

let top = "d"

let bottom = "e"

let com_label = "com"

let tmp_buffers = ref [||]

type answers = {
  q : Poly.scalar;
  a : Poly.scalar;
  b : Poly.scalar;
  c : Poly.scalar;
  d : Poly.scalar;
  e : Poly.scalar;
  ag : Poly.scalar;
  bg : Poly.scalar;
  cg : Poly.scalar;
  dg : Poly.scalar;
  eg : Poly.scalar;
}

type witness = {
  q : Evaluations.t;
  a : Evaluations.t;
  b : Evaluations.t;
  c : Evaluations.t;
  d : Evaluations.t;
  e : Evaluations.t;
}

let get_buffers ~nb_buffers ~nb_ids =
  let precomputed = !tmp_buffers in
  let nb_precomputed = Array.length precomputed in
  let size_eval = Evaluations.length precomputed.(0) in
  let buffers =
    Array.init (max nb_buffers nb_precomputed) (fun i ->
        if i < nb_precomputed then precomputed.(i)
        else Evaluations.create size_eval)
  in
  tmp_buffers := buffers ;
  (buffers, Array.init nb_ids (fun _ -> Evaluations.create size_eval))

let get_answers ~q_label ~blinds ~prefix ~prefix_common answers : answers =
  let dummy = Scalar.zero in
  let answer = get_answer answers in
  let answer_wire w =
    match SMap.find_opt w blinds with
    | Some array ->
        assert (Array.length array = 2) ;
        let w' = prefix w in
        let x = if array.(0) = 0 then dummy else answer X w' in
        let gx = if array.(1) = 0 then dummy else answer GX w' in
        (x, gx)
    | None -> (dummy, dummy)
  in
  let q = prefix_common q_label |> answer X in
  let a, ag = answer_wire left in
  let b, bg = answer_wire right in
  let c, cg = answer_wire output in
  let d, dg = answer_wire top in
  let e, eg = answer_wire bottom in
  {q; a; b; c; d; e; ag; bg; cg; dg; eg}

let get_evaluations ~q_label ~blinds ~prefix ~prefix_common evaluations =
  let dummy = Evaluations.zero in
  let find_wire w =
    match SMap.find_opt w blinds with
    | Some array ->
        assert (Array.length array = 2) ;
        if array.(0) = 0 && array.(1) = 0 then dummy
        else Evaluations.find_evaluation evaluations (prefix w)
    | None -> dummy
  in
  {
    q = Evaluations.find_evaluation evaluations (prefix_common q_label);
    a = find_wire left;
    b = find_wire right;
    c = find_wire output;
    d = find_wire top;
    e = find_wire bottom;
  }

(* Block names to merge identities within, if identities are independent, use q_label instead.
   For instance, we want to have want AddLeft and Addright identities to be merged inside the Arithmetic block,
   we thus use "arith" as Map key for these gates identities.
   We also want to use the ECC point addition identity independently, as such we put ECCAdd gate's q_label as key. *)
let arith = "Arith"

let qadv_label = "qadv"

let map_singleton m =
  let map f t =
    let open L in
    let* x = t in
    ret (f x)
  in
  map (fun x -> [x]) m

module type Base_sig = sig
  val q_label : string

  (* array.(i) = 1 <=> f is evaluated at (g^i)X *)
  val blinds : int array SMap.t

  val identity : string * int

  val index_com : int option

  val nb_advs : int

  val nb_buffers : int

  val gx_composition : bool

  val equations :
    q:Scalar.t ->
    a:Scalar.t ->
    b:Scalar.t ->
    c:Scalar.t ->
    d:Scalar.t ->
    e:Scalar.t ->
    ag:Scalar.t ->
    bg:Scalar.t ->
    cg:Scalar.t ->
    dg:Scalar.t ->
    eg:Scalar.t ->
    ?precomputed_advice:Scalar.t SMap.t ->
    unit ->
    Scalar.t list

  val prover_identities :
    prefix_common:(string -> string) ->
    prefix:(string -> string) ->
    public:public ->
    domain:Domain.t ->
    prover_identities

  val verifier_identities :
    prefix_common:(string -> string) ->
    prefix:(string -> string) ->
    public:public ->
    generator:Scalar.t ->
    size_domain:int ->
    verifier_identities

  (* Give the size of the domain on which the identities
     of the gate need to have the evaluation of each of his polynomial
     divided by the size of the citcuit. *)
  val polynomials_degree : int SMap.t

  val cs :
    q:L.scalar L.repr ->
    a:L.scalar L.repr ->
    b:L.scalar L.repr ->
    c:L.scalar L.repr ->
    d:L.scalar L.repr ->
    e:L.scalar L.repr ->
    ag:L.scalar L.repr ->
    bg:L.scalar L.repr ->
    cg:L.scalar L.repr ->
    dg:L.scalar L.repr ->
    eg:L.scalar L.repr ->
    ?precomputed_advice:L.scalar L.repr SMap.t ->
    unit ->
    L.scalar L.repr list L.t
end