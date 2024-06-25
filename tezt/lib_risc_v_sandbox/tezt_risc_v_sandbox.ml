(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 TriliTech <contact@trili.tech>                         *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
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

let risc_v_sandbox =
  Uses.make ~tag:"risc_v_sandbox" ~path:"./src/risc_v/risc-v-sandbox"

(* Tell Manifezt that [risc_v_sandbox] itself depends on the full contents
   of the [src/risc_v] directory. Manifezt doesn't know how to automatically
   infer non-OCaml dependency relationships. Also declare a dependency on
   the RISC-V test suite using the same tag to avoid warnings. *)
let _ = Uses.make ~tag:"risc_v_sandbox" ~path:"./src/risc_v/"

let _ =
  Uses.make ~tag:"risc_v_sandbox" ~path:"./tezt/tests/riscv-tests/generated/"

let run_kernel ?(posix = false) ~input ?initrd () =
  let process =
    Process.spawn
      ~hooks:Tezt_tezos.Tezos_regression.hooks
      (Uses.path risc_v_sandbox)
      (["rvemu"; "--input"; input]
      @ Option.fold ~none:[] ~some:(fun initrd -> ["--initrd"; initrd]) initrd
      @ if posix then ["--posix"] else [])
  in
  Process.check process
