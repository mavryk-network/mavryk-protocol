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

open Wasm_pvm_state.Internal_state

include Wasm_vm_sig.S

(** [compute_step_many_until max_step should_continue pvm_state]
      advance forwards the VM in the same manners as [compute_step_many]
      as long as [should_continue] returns true.

      Returns the new state and number of the executed ticks.

      IS applied on [pvm_state] rather than a tree.

      /!\ as it allows to redefine the stop condition, this function should
      not be used in unit test: the test could hide regression if the
      condition change in the code, but not in the test.
  *)
val compute_step_many_until :
  ?max_steps:int64 ->
  (pvm_state -> bool Lwt.t) ->
  pvm_state ->
  (pvm_state * int64) Lwt.t

(** [eval_has_finished tick_state] returns [true] if the evaluation phase has
    finished successfully. *)
val eval_has_finished : tick_state -> bool

(** [should_compute pvm_state] probes whether it is possible to continue with
    more computational steps. *)
val should_compute : pvm_state -> bool

(** [has_reboot_flag durable] checks if the reboot flag is set in the durable storage. *)
val has_reboot_flag : Durable.t -> bool Lwt.t

(** [mark_for_reboot reboot_counter durable] figures out the computational
    status with respect to what the PVM shall do next. E.g. schedule a reboot. *)
val mark_for_reboot : pvm_state -> [`Forcing_yield | `Reboot | `Yielding] Lwt.t

(** [next_reboot_counter pvm_state status] computes the next reboot counter. *)
val next_reboot_counter : pvm_state -> computation_status -> Z.t

(** [save_fallback_kernel durable] stores the current kernel as a fallback
    kernel. *)
val save_fallback_kernel : Durable.t -> Durable.t Lwt.t
