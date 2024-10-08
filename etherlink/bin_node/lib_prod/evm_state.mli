(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

type t = Irmin_context.PVMState.value

(** Directory where the kernel logs are stored. The function {!execute} below
    expect the directory to exist.*)
val kernel_logs_directory : data_dir:string -> string

(** [execute ?simulation ~data_dir ?log_file ~wasm_entrypoint ~config
    evm_state messages] executes the [wasm_entrypoint] function
    (default to [kernel_run]) with [messages] within the inbox of
    [evm_state].

    Kernel logs are stored under the {!kernel_logs_directory} in [log_file].
    [simulation] adds a prefix to the event to differenciate the logs.
*)
val execute :
  ?kind:Events.kernel_log_kind ->
  data_dir:string ->
  ?log_file:string ->
  ?wasm_entrypoint:string ->
  config:Config.config ->
  t ->
  [< `Input of string] list ->
  t tzresult Lwt.t

(** [init ~kernel] initializes the local [evm_state] with [kernel]. *)
val init : kernel:string -> t tzresult Lwt.t

(** [modify ~key ~value evm_state] sets [value] at [key] in the local EVM
    state. *)
val modify : key:string -> value:string -> t -> t Lwt.t

(** [inspect evm_state key] returns the value stored under [key] in
    [evm_state], if any. *)
val inspect : t -> string -> bytes option Lwt.t

(** [subkeys evm_state key] returns the list of value stored under [key] in
    [evm_state]. *)
val subkeys : t -> string -> string trace Lwt.t

(** [execute_and_inspect ~data_dir ?wasm_entrypoint ~config ~input
    evm_state] executes the [wasm_entrypoint] function (default to
    [kernel_run]) with [input] within the inbox of [evm_state], and
    returns [input.insights_requests]. *)
val execute_and_inspect :
  data_dir:string ->
  ?wasm_entrypoint:string ->
  config:Config.config ->
  input:Simulation.Encodings.simulate_input ->
  t ->
  bytes option list tzresult Lwt.t

(** [current_block_height evm_state] returns the height of the latest block
    produced by the kernel. *)
val current_block_height : t -> Ethereum_types.block_height Lwt.t

(** Same as {!current_block_height} for the block hash. *)
val current_block_hash : t -> Ethereum_types.block_hash tzresult Lwt.t

type apply_result =
  | Apply_success of t * Ethereum_types.block_height * Ethereum_types.block_hash
  | Apply_failure

(** [apply_blueprint ~data-dir ~config state payload] applies the
    blueprint [payload] on top of [evm_state]. If the payload produces
    a block, the new updated EVM state is returned along with the new
    block’s height.

    The [data-dir] is used to store the kernel logs in the
    {!kernel_logs_directory}.
*)
val apply_blueprint :
  data_dir:string ->
  config:Config.config ->
  t ->
  Blueprint_types.payload ->
  apply_result tzresult Lwt.t

(** [flag_local_exec evm_state] adds a flag telling the kernel it is executed
    by an EVM node, not a rollup node. *)
val flag_local_exec : t -> t Lwt.t

(** [clear_delayed_inbox evm_state] removes the delayed inbox from the current
    EVM state. *)
val clear_delayed_inbox : t -> t Lwt.t
