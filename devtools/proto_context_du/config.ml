(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

let known_networks =
  List.map
    (fun (alias, (net : Mavkit_node_config.Config_file.blockchain_network)) ->
      (alias, net.genesis))
    Mavkit_node_config.Config_file.builtin_blockchain_networks
