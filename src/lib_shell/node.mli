(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2018-2021 Nomadic Labs, <contact@nomadic-labs.com>          *)
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

type t

val get_version : t -> Mavryk_version.Mavkit_node_version.t

type config = {
  genesis : Genesis.t;
  chain_name : Distributed_db_version.Name.t;
  sandboxed_chain_name : Distributed_db_version.Name.t;
  user_activated_upgrades : User_activated.upgrades;
  user_activated_protocol_overrides : User_activated.protocol_overrides;
  operation_metadata_size_limit : Shell_limits.operation_metadata_size_limit;
  data_dir : string;
  internal_events : Mavryk_base.Internal_event_config.t;
  store_root : string;
  context_root : string;
  protocol_root : string;
  patch_context :
    (Mavryk_protocol_environment.Context.t ->
    Mavryk_protocol_environment.Context.t tzresult Lwt.t)
    option;
  p2p : (P2p.config * P2p_limits.t) option;
  target : (Block_hash.t * int32) option;
  disable_mempool : bool;
      (** If [true], all non-empty mempools will be ignored. *)
  enable_testchain : bool;
      (** If [false], testchain related messages will be ignored. *)
  dal_config : Mavryk_crypto_dal.Cryptobox.Config.t;
}

val create :
  ?sandboxed:bool ->
  ?sandbox_parameters:Data_encoding.json ->
  ?disable_context_pruning:bool ->
  ?history_mode:History_mode.t ->
  ?maintenance_delay:Storage_maintenance.delay ->
  singleprocess:bool ->
  version:string ->
  commit_info:Mavkit_node_version.commit_info ->
  config ->
  Shell_limits.peer_validator_limits ->
  Shell_limits.block_validator_limits ->
  Shell_limits.prevalidator_limits ->
  Shell_limits.chain_validator_limits ->
  (t, tztrace) result Lwt.t

val shutdown : t -> unit Lwt.t

(** [build_rpc_directory ~node_version ~commit_info node] builds a Mavryk RPC
    directory for the node by gathering all the subdirectories. [node_version],
    [commit_info] and [node] contain all informations required to build such a
    directory. *)
val build_rpc_directory :
  node_version:Mavryk_version.Mavkit_node_version.t ->
  commit_info:Mavkit_node_version.commit_info ->
  t ->
  unit Mavryk_rpc.Directory.t
