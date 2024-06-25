(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

let exchanger_path () =
  Base.(project_root // "etherlink/mavryk_contracts/exchanger.tz")

let bridge_path () =
  Base.(project_root // "etherlink/mavryk_contracts/evm_bridge.tz")

let admin_path () = Base.(project_root // "etherlink/mavryk_contracts/admin.tz")

let withdrawal_abi_path () =
  Base.(project_root // "etherlink/mavryk_contracts/withdrawal.abi")

let delayed_path () =
  Base.(
    project_root // "etherlink/mavryk_contracts/delayed_transaction_bridge.tz")
