(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

let exchanger_path () =
  Base.(project_root // "etherlink/mavryk_contracts/exchanger.mv")

let bridge_path () =
  Base.(project_root // "etherlink/mavryk_contracts/evm_bridge.mv")

let admin_path () = Base.(project_root // "etherlink/mavryk_contracts/admin.mv")

let withdrawal_abi_path () =
  Base.(project_root // "etherlink/mavryk_contracts/withdrawal.abi")

let delayed_path () =
  Base.(
    project_root // "etherlink/mavryk_contracts/delayed_transaction_bridge.mv")
