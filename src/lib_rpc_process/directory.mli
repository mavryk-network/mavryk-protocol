(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs. <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

(** [build_rpc_directory node_version config] builds the Tezos RPC directory for
    the rpc process. RPCs handled here are not forwarded to the node.
*)
val build_rpc_directory :
  Mavryk_version.Node_version.t ->
  Mavkit_node_config.Config_file.t ->
  unit Mavryk_rpc.Directory.t
