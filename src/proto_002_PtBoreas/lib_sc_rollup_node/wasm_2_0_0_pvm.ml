(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022-2023 TriliTech <contact@trili.tech>                    *)
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

open Protocol
open Alpha_context

(** This module manifests the proof format used by the Wasm PVM as defined by
    the Layer 1 implementation for it.

    It is imperative that this is aligned with the protocol's implementation.
*)
module Wasm_2_0_0_proof_format =
  Irmin_context.Proof
    (struct
      include Sc_rollup.State_hash

      let of_context_hash = Sc_rollup.State_hash.context_hash_to_state_hash
    end)
    (struct
      let proof_encoding =
        Mavryk_context_merkle_proof_encoding.Merkle_proof_encoding.V2.Tree2
        .tree_proof_encoding
    end)

module type TreeS =
  Mavryk_context_sigs.Context.TREE
    with type key = string list
     and type value = bytes

module Make_wrapped_tree (Tree : TreeS) :
  Mavryk_tree_encoding.TREE with type tree = Tree.tree = struct
  type Mavryk_tree_encoding.tree_instance += PVM_tree of Tree.tree

  include Tree

  let select = function
    | PVM_tree t -> t
    | _ -> raise Mavryk_tree_encoding.Incorrect_tree_type

  let wrap t = PVM_tree t
end

module Make_backend (Tree : TreeS) = struct
  include Mavryk_scoru_wasm_fast.Pvm.Make (Make_wrapped_tree (Tree))

  let compute_step =
    compute_step ~wasm_entrypoint:Mavryk_scoru_wasm.Constants.wasm_entrypoint
end

(** Durable part of the storage of this PVM. *)
module type Durable_state = sig
  type state

  (** [value_length state key] returns the length of data stored
        for the [key] in the durable storage of the PVM state [state], if any. *)
  val value_length : state -> string -> int64 option Lwt.t

  (** [lookup state key] returns the data stored
        for the [key] in the durable storage of the PVM state [state], if any. *)
  val lookup : state -> string -> bytes option Lwt.t

  (** [subtrees state key] returns subtrees
        for the [key] in the durable storage of the PVM state [state].
        Empty list in case if path doesn't exist. *)
  val list : state -> string -> string list Lwt.t

  module Tree_encoding_runner :
    Mavryk_tree_encoding.Runner.S with type tree = state
end

module Make_durable_state
    (T : Mavryk_tree_encoding.TREE with type tree = Irmin_context.tree) :
  Durable_state with type state = T.tree = struct
  module Tree_encoding_runner = Mavryk_tree_encoding.Runner.Make (T)

  type state = T.tree

  let decode_durable tree =
    Tree_encoding_runner.decode
      Mavryk_scoru_wasm.Wasm_pvm.durable_storage_encoding
      tree

  let value_length tree key_str =
    let open Lwt_syntax in
    let key = Mavryk_scoru_wasm.Durable.key_of_string_exn key_str in
    let* durable = decode_durable tree in
    let+ res_opt = Mavryk_scoru_wasm.Durable.find_value durable key in
    Option.map Mavryk_lazy_containers.Chunked_byte_vector.length res_opt

  let lookup tree key_str =
    let open Lwt_syntax in
    let key = Mavryk_scoru_wasm.Durable.key_of_string_exn key_str in
    let* durable = decode_durable tree in
    let* res_opt = Mavryk_scoru_wasm.Durable.find_value durable key in
    match res_opt with
    | None -> return_none
    | Some v ->
        let+ bts = Mavryk_lazy_containers.Chunked_byte_vector.to_bytes v in
        Some bts

  let list tree key_str =
    let open Lwt_syntax in
    let key = Mavryk_scoru_wasm.Durable.key_of_string_exn key_str in
    let* durable = decode_durable tree in
    Mavryk_scoru_wasm.Durable.list durable key
end

module Durable_state =
  Make_durable_state (Make_wrapped_tree (Wasm_2_0_0_proof_format.Tree))

type unsafe_patch = Increase_max_nb_ticks of int64

module Impl : Pvm_sig.S with type Unsafe_patches.t = unsafe_patch = struct
  module PVM =
    Sc_rollup.Wasm_2_0_0PVM.Make (Make_backend) (Wasm_2_0_0_proof_format)
  include PVM

  type repo = Irmin_context.repo

  type tree = Irmin_context.tree

  module Ctxt_wrapper = Context_wrapper.Irmin

  let kind = Sc_rollup.Kind.Wasm_2_0_0

  let new_dissection = Game_helpers.Wasm.new_dissection

  module State = Irmin_context.PVMState

  module Inspect_durable_state = struct
    let lookup state keys =
      let key = "/" ^ String.concat "/" keys in
      Durable_state.lookup state key
  end

  module Backend = Make_backend (Wasm_2_0_0_proof_format.Tree)

  module Unsafe_patches = struct
    type t = unsafe_patch

    let of_patch (p : Pvm_patches.unsafe_patch) =
      match p with
      | Increase_max_nb_ticks max_nb_ticks ->
          Ok (Increase_max_nb_ticks max_nb_ticks)

    let apply state (Increase_max_nb_ticks max_nb_ticks) =
      let open Lwt_syntax in
      let* registered_max_nb_ticks = Backend.Unsafe.get_max_nb_ticks state in
      let max_nb_ticks = Z.of_int64 max_nb_ticks in
      if Z.Compare.(max_nb_ticks < registered_max_nb_ticks) then
        Format.ksprintf
          invalid_arg
          "Decreasing tick limit of WASM PVM from %s to %s is not allowed"
          (Z.to_string registered_max_nb_ticks)
          (Z.to_string max_nb_ticks) ;
      Backend.Unsafe.set_max_nb_ticks max_nb_ticks state
  end

  let string_of_status : status -> string = function
    | Waiting_for_input_message -> "Waiting for input message"
    | Waiting_for_reveal (Sc_rollup.Reveal_raw_data hash) ->
        Format.asprintf
          "Waiting for preimage reveal %a"
          Sc_rollup_reveal_hash.pp
          hash
    | Waiting_for_reveal Sc_rollup.Reveal_metadata -> "Waiting for metadata"
    | Waiting_for_reveal (Sc_rollup.Request_dal_page page_id) ->
        Format.asprintf "Waiting for page data %a" Dal.Page.pp page_id
    | Waiting_for_reveal Sc_rollup.Reveal_dal_parameters ->
        "Waiting for DAL parameters"
    | Computing -> "Computing"

  let eval_many ~reveal_builtins ~write_debug ~is_reveal_enabled:_ =
    Backend.compute_step_many
      ~wasm_entrypoint:Mavryk_scoru_wasm.Constants.wasm_entrypoint
      ~reveal_builtins
      ~write_debug
end

include Impl
