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

module SMap = Plonk.SMap
open Plompiler.Csir

let gates_equal = SMap.equal (Array.for_all2 Scalar.equal)

module Make = struct
  module Main = Plonk.Main_protocol
  module Helpers = Plonk_test.Helpers
  module Helpers_main = Helpers.Make (Main)

  let test_make_one_sel sel () =
    let open Plonk.Circuit in
    let wires = SMap.of_list [("a", [1]); ("b", [1]); ("c", [1])] in
    let gates = SMap.add sel [Scalar.one] SMap.empty in
    let gates, tables =
      match sel with
      | "q_plookup" -> (SMap.add "q_table" [Scalar.one] gates, [[[||]]])
      | "q_table" -> (SMap.add "q_plookup" [Scalar.one] gates, [[[||]]])
      | _ -> (gates, [])
    in
    let c = make ~tables ~wires ~gates ~public_input_size:0 () in
    let wires = Tables.map Array.of_list wires in
    let gates = Tables.map Array.of_list gates in
    assert (c.wires = wires) ;
    assert (gates_equal c.gates gates)

  let tests_one_sel =
    List.map
      (fun (s, _) ->
        Alcotest.test_case ("make " ^ s) `Quick (test_make_one_sel s))
      CS.all_selectors

  let test_empty () =
    let open Plonk.Circuit in
    let wires = SMap.of_list [("a", [1]); ("b", [1]); ("c", [1])] in
    let gates = SMap.add "qc" [Scalar.one] SMap.empty in
    Helpers.must_fail (fun () ->
        ignore @@ make ~wires:SMap.empty ~gates ~public_input_size:0 ()) ;
    Helpers.must_fail (fun () ->
        ignore @@ make ~wires ~gates:SMap.empty ~public_input_size:0 ())

  let test_different_size () =
    let open Plonk.Circuit in
    (* wires have different size wrt to gates *)
    let wires = SMap.of_list [("a", [1]); ("b", [1]); ("c", [1])] in
    let gates = SMap.add "qc" Scalar.[one; one] SMap.empty in
    Helpers.must_fail (fun () ->
        ignore @@ make ~wires ~gates ~public_input_size:0 ()) ;
    (* wires have different sizes *)
    let wires = SMap.of_list [("a", [1; 1]); ("b", [1]); ("c", [1])] in
    let gates = SMap.add "qc" Scalar.[one] SMap.empty in
    Helpers.must_fail (fun () ->
        ignore @@ make ~wires ~gates ~public_input_size:0 ()) ;
    (* gates have different sizes *)
    let wires = SMap.of_list [("a", [1]); ("b", [1]); ("c", [1])] in
    let gates = SMap.of_list Scalar.[("qc", [one]); ("ql", [one; one])] in
    Helpers.must_fail (fun () ->
        ignore @@ make ~wires ~gates ~public_input_size:0 ())

  (* Test that Plonk supports using qecc_ws_add and a q*g in the same circuit. *)
  let test_disjoint () =
    let open Plonk.Circuit in
    let x = Scalar.[|one; add one one; of_string "3"; of_string "4"|] in
    let wires =
      SMap.of_list [("a", [0; 2; 0]); ("b", [0; 3; 3]); ("c", [0; 1; 1])]
    in
    let gates =
      SMap.of_list
        Scalar.
          [
            ("ql", [one; zero; zero]);
            ("qecc_ws_add", [zero; one; zero]);
            ("qlg", [one; zero; zero]);
            ("qc", [Scalar.(negate (of_string "4")); zero; zero]);
          ]
    in
    let c = make ~wires ~gates ~public_input_size:0 () in
    Helpers_main.test_circuit ~name:"test_disjoint" c x

  let test_wrong_selectors () =
    let open Plonk.Circuit in
    let wires =
      SMap.of_list [("a", [0; 2; 0]); ("b", [0; 3; 3]); ("c", [0; 1; 1])]
    in
    let gates =
      SMap.of_list
        Scalar.
          [
            ("ql", [one; zero; zero]);
            ("dummy", [zero; one; zero]);
            ("qlg", [one; zero; zero]);
            ("qc", [Scalar.(negate (of_string "4")); zero; zero]);
          ]
    in
    try
      let _ = make ~wires ~gates ~public_input_size:0 () in
      ()
    with
    | Invalid_argument s when s = "Make Circuit: unknown gates." -> ()
    | _ ->
        failwith
          "Test_wrong_selector : Invalid_argument \"Make Circuit: unknown \
           gates.\" expected."

  let test_vector () =
    let open Plonk.Circuit in
    let wires = SMap.of_list [("a", [1; 1]); ("b", [1; 1]); ("c", [1; 1])] in
    let gates =
      SMap.of_list Scalar.[("qc", [zero; one]); ("qr", [zero; zero])]
    in
    let gates_expected =
      SMap.of_list Scalar.[("qc", [|zero; one|]); ("ql", [|zero; zero|])]
    in
    let c = make ~wires ~gates ~public_input_size:1 () in
    let wires = Tables.map Array.of_list wires in
    assert (c.wires = wires) ;
    assert (gates_equal c.gates gates_expected)

  (* TODO add more tests about lookup *)

  let test_table () =
    let zero, one = Scalar.(zero, one) in
    let table_or =
      Table.of_list
        [
          [|zero; zero; one; one|];
          [|zero; one; zero; one|];
          [|zero; one; one; one|];
          [|zero; zero; zero; zero|];
          [|zero; zero; zero; zero|];
        ]
    in
    let entry =
      ({a = zero; b = zero; c = zero; d = zero; e = zero} : Table.entry)
    in
    let input =
      Table.{a = Some zero; b = Some zero; c = None; d = None; e = None}
    in
    assert (Table.size table_or = 4) ;
    assert (Table.mem entry table_or) ;
    Table.find input table_or |> Option.get |> fun res ->
    assert (Scalar.(eq entry.a res.a && eq entry.b res.b && eq entry.c res.c)) ;
    ()
end

module To_plonk = struct
  let test_vector () =
    let open Plonk.Circuit in
    let open CS in
    let zero, one, two = Scalar.(zero, one, one + one) in
    let precomputed_advice = [] in
    let g1 =
      [|
        {
          a = 0;
          b = 1;
          c = 0;
          d = 0;
          e = 0;
          sels = [("qr", one)];
          precomputed_advice;
          label = [];
        };
      |]
    in
    let g2 =
      [|
        {
          a = 1;
          b = 2;
          c = 1;
          d = 0;
          e = 0;
          sels = [("qm", two)];
          precomputed_advice;
          label = [];
        };
      |]
    in
    let c = to_plonk ~public_input_size:0 [g1; g2] in
    let expected_wires =
      SMap.of_list
        [
          ("a", [|0; 1|]);
          ("b", [|1; 2|]);
          ("c", [|0; 1|]);
          ("d", [|0; 0|]);
          ("e", [|0; 0|]);
        ]
    in
    let expected_gates =
      SMap.of_list [("qr", [|one; zero|]); ("qm", [|zero; two|])]
    in
    assert (c.wires = expected_wires) ;
    assert (gates_equal c.gates expected_gates)
end

let tests =
  Make.tests_one_sel
  @ List.map
      (fun (n, f) -> Alcotest.test_case n `Quick f)
      [
        ("make empty", Make.test_empty);
        ("make different_size", Make.test_different_size);
        ("make vectors", Make.test_vector);
        ("make table", Make.test_table);
        ("make disjoint", Make.test_disjoint);
        ("to_plonk vectors", To_plonk.test_vector);
        ("to_plonk wrong selectors", Make.test_wrong_selectors);
      ]