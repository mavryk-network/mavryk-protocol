(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 Trili Tech <contact@trili.tech>                   *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*                                                                           *)
(*****************************************************************************)

val alcotezt : Manifest.target

val bls12_381 : Manifest.target

val mavkit_base : Manifest.target

val mavkit_base_test_helpers : Manifest.target

val mavkit_base_unix : Manifest.target

val mavkit_clic : Manifest.target

val mavkit_client_base : Manifest.target

val mavkit_client_base_unix : Manifest.target

val mavkit_context_disk : Manifest.target

val mavkit_context_encoding : Manifest.target

val mavkit_context_sigs : Manifest.target

val mavkit_crypto : Manifest.target

val mavkit_event_logging : Manifest.target

val mavkit_layer2_store : Manifest.target

val mavkit_rpc_http_client_unix : Manifest.target

val mavkit_rpc_http : Manifest.target

val mavkit_rpc_http_server : Manifest.target

val mavkit_scoru_wasm_debugger_lib : Manifest.target

val mavkit_scoru_wasm_debugger_plugin : Manifest.target

val mavkit_scoru_wasm_helpers : Manifest.target

val mavkit_scoru_wasm : Manifest.target

val mavkit_signer_services : Manifest.target

val mavkit_smart_rollup_lib : Manifest.target

val mavkit_stdlib_unix : Manifest.target

val mavkit_test_helpers : Manifest.target

val mavkit_version_value : Manifest.target

val mavkit_workers : Manifest.target

val registered_mavkit_l2_libs : Manifest.Sub_lib.container

val registered_mavkit_libs : Manifest.Sub_lib.container

val registered_mavkit_proto_libs : Manifest.Sub_lib.container

val registered_mavkit_shell_libs : Manifest.Sub_lib.container

val tezt_risc_v_sandbox : Manifest.target

val tezt_performance_regression : Manifest.target

val tezt_mavryk : Manifest.target

val tezt_tx_kernel : Manifest.target

val tezt_wrapper : Manifest.target

module Protocol : sig
  type t

  type number = Alpha | V of int | Other

  val main : t -> Manifest.target

  val alpha : t

  val active : t list

  val number : t -> number

  val name_dash : t -> string

  val short_hash : t -> string

  val all_optionally :
    (t -> Manifest.target option) list -> Manifest.target list

  val client : t -> Manifest.target option
end
