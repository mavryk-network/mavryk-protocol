(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

(** [get_value ~pvm tree durable_path] returns the value behind the [durable_path]
    if it exists in [tree]. *)
val get_value :
  pvm:(module Pvm_plugin_sig.S) ->
  tree:Context.tree ->
  durable_path:string list ->
  string option Lwt.t

(** [dump_durable_storage ~block ~data_dir ~file] writes to [file] the current
    state of the WASM PVM from [data_dir], that is the state of the WASM PVM
    for the given [block]. *)
val dump_durable_storage :
  block:Tezos_shell_services.Block_services.block ->
  data_dir:string ->
  file:string ->
  unit tzresult Lwt.t
