(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2024 Trilitech <contact@trili.tech>                         *)
(*                                                                           *)
(*****************************************************************************)

(** Default balance given to bootstrap account. *)
val default_bootstrap_account_balance : Wei.t

(** Creates an installer configuration compatible with the EVM kernel. *)
val make_config :
  ?kernel_root_hash:string ->
  ?bootstrap_accounts:Eth_account.t array ->
  ?ticketer:string ->
  ?administrator:string ->
  ?kernel_governance:string ->
  ?kernel_security_governance:string ->
  ?sequencer_governance:string ->
  ?sequencer:string ->
  ?sequencer_pool_address:string ->
  ?delayed_bridge:string ->
  ?da_fee_per_byte:Wei.t ->
  ?minimum_base_fee_per_gas:Wei.t ->
  ?delayed_inbox_timeout:int ->
  ?delayed_inbox_min_levels:int ->
  unit ->
  [> `Config of Sc_rollup_helpers.Installer_kernel_config.instr list] option
