(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

include Internal_event.Simple

let section = ["dal"; "node"]

let starting_node =
  declare_0
    ~section
    ~name:"starting_dal_node"
    ~msg:"starting the DAL node"
    ~level:Notice
    ()

let waiting_l1_node_bootstrapped =
  declare_0
    ~section
    ~name:"waiting_l1_node_to_be_bootstrapped"
    ~msg:"waiting for the L1 node to be bootstrapped"
    ~level:Notice
    ()

let l1_node_bootstrapped =
  declare_0
    ~section
    ~name:"l1_node_is_bootstrapped"
    ~msg:"the L1 node is bootstrapped"
    ~level:Notice
    ()

let shutdown_node =
  declare_1
    ~section
    ~name:"stopping_dal_node"
    ~msg:"stopping DAL node"
    ~level:Notice
    ("exit_status", Data_encoding.int8)

let store_is_ready =
  declare_0
    ~section
    ~name:"dal_node_store_is_ready"
    ~msg:"the DAL node store is ready"
    ~level:Notice
    ()

let node_is_ready =
  declare_0
    ~section
    ~name:"dal_node_is_ready"
    ~msg:"the DAL node is ready"
    ~level:Notice
    ()

let data_dir_not_found =
  declare_1
    ~section
    ~name:"dal_node_no_data_dir"
    ~msg:
      "the DAL node configuration file does not exist in {path}, creating one"
    ~level:Warning
    ("path", Data_encoding.(string))

let failed_to_persist_profiles =
  declare_2
    ~section
    ~name:"failed_to_persist_profiles"
    ~msg:"failed to persist the profiles to the config file"
    ~level:Error
    ("profiles", Types.profiles_encoding)
    ("error", Error_monad.trace_encoding)

let fetched_slot =
  declare_2
    ~section
    ~name:"fetched_slot"
    ~msg:"slot fetched: size {size}, shards {shards}"
    ~level:Notice
    ("size", Data_encoding.int31)
    ("shards", Data_encoding.int31)

let layer1_node_new_head =
  declare_3
    ~section
    ~name:"dal_node_layer_1_new_head"
    ~msg:
      "head of Layer 1 node updated to {hash} at level {level}, round {round}"
    ~level:Info
    ("hash", Block_hash.encoding)
    ("level", Data_encoding.int32)
    ("round", Data_encoding.int32)

let layer1_node_final_block =
  declare_2
    ~section
    ~name:"dal_node_layer_1_new_final_block"
    ~msg:"layer 1 node's block at level {level}, round {round} is final"
    ~level:Notice
    ("level", Data_encoding.int32)
    ("round", Data_encoding.int32)

let layer1_node_tracking_started =
  declare_0
    ~section
    ~name:"dal_node_layer_1_start_tracking"
    ~msg:"started tracking layer 1's node"
    ~level:Notice
    ()

let layer1_node_tracking_started_for_plugin =
  declare_0
    ~section
    ~name:"dal_node_layer_1_start_tracking_for_plugin"
    ~msg:"started tracking layer 1's node to determine plugin"
    ~level:Notice
    ()

let protocol_plugin_resolved =
  declare_1
    ~section
    ~name:"dal_node_plugin_resolved"
    ~msg:"resolved plugin on protocol {proto_hash}"
    ~level:Notice
    ~pp1:Protocol_hash.pp_short
    ("proto_hash", Protocol_hash.encoding)

let no_protocol_plugin =
  declare_0
    ~section
    ~name:"dal_node_no_plugin"
    ~msg:"could not resolve plugin"
    ~level:Error
    ()

let unexpected_protocol_plugin =
  declare_0
    ~section
    ~name:"dal_node_unexpected_plugin"
    ~msg:
      "found plugin for the current protocol, expected one for the next \
       protocol."
    ~level:Error
    ()

let daemon_error =
  declare_1
    ~section
    ~name:"dal_node_daemon_error"
    ~msg:"daemon thrown an error: {error}"
    ~level:Notice
    ~pp1:Error_monad.pp_print_trace
    ("error", Error_monad.trace_encoding)

let configuration_loaded =
  declare_0
    ~section
    ~name:"configuration_loaded"
    ~msg:"configuration loaded successfully"
    ~level:Notice
    ()

let stored_slot_content =
  declare_1
    ~section
    ~name:"stored_slot_content"
    ~msg:"slot stored: commitment {commitment}"
    ~level:Notice
    ~pp1:Cryptobox.Commitment.pp_short
    ("commitment", Cryptobox.Commitment.encoding)

let stored_slot_shard =
  declare_2
    ~section
    ~name:"stored_slot_shard"
    ~msg:"stored shard {shard_index} for commitment {commitment}"
    ~level:Debug
    ~pp1:Cryptobox.Commitment.pp_short
    ("commitment", Cryptobox.Commitment.encoding)
    ("shard_index", Data_encoding.int31)

let removed_slot_shards =
  declare_1
    ~section
    ~name:"removed_slot_shards"
    ~msg:"removed shards for commitment {commitment}"
    ~level:Notice
    ~pp1:Cryptobox.Commitment.pp_short
    ("commitment", Cryptobox.Commitment.encoding)

let decoding_data_failed =
  declare_1
    ~section
    ~name:"decoding_failed"
    ~msg:"error while decoding a {data_kind} value"
    ~level:Warning
    ("data_kind", Types.Store.encoding)

let loading_shard_data_failed =
  declare_1
    ~section
    ~name:"loading_shard_data_failed"
    ~msg:"error while reading shard data {message}"
    ~level:Warning
    ("message", Data_encoding.string)

let message_validation_error =
  declare_2
    ~section
    ~name:"message_validation_failed"
    ~msg:
      "validating message with id {message_id} failed with error \
       {validation_error}"
    ~level:Warning
    ~pp1:Gossipsub.Worker.GS.Message_id.pp
    ("message_id", Types.Message_id.encoding)
    ("validation_error", Data_encoding.string)

let p2p_server_is_ready =
  declare_1
    ~section
    ~name:"dal_node_p2p_server_is_ready"
    ~msg:"P2P server is listening on {point}"
    ~level:Notice
    ("point", P2p_point.Id.encoding)

let rpc_server_is_ready =
  declare_1
    ~section
    ~name:"dal_node_rpc_server_is_ready"
    ~msg:"RPC server is listening on {point}"
    ~level:Notice
    ("point", P2p_point.Id.encoding)

let metrics_server_is_ready =
  let open Internal_event.Simple in
  declare_2
    ~section
    ~name:"starting_metrics_server"
    ~msg:"metrics server is listening on {host}:{port}"
    ~level:Notice
    ("host", Data_encoding.string)
    ("port", Data_encoding.uint16)

let loading_profiles_failed =
  declare_1
    ~section
    ~name:"loading_profiles_failed"
    ~msg:"loading profiles failed: {error}"
    ~level:Error
    ("error", Error_monad.trace_encoding)

let saving_profiles_failed =
  declare_1
    ~section
    ~name:"saving_profiles_failed"
    ~msg:"saving profiles failed: {error}"
    ~level:Error
    ("error", Error_monad.trace_encoding)

let reconstruct_missing_prover_srs =
  declare_2
    ~section
    ~name:"reconstruct_missing_prover_srs"
    ~msg:
      "Missing prover SRS, reconstruction for the level {level} and slot index \
       {slot_index} was skipped."
    ~level:Warning
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)

let reconstruct_starting_in =
  declare_3
    ~section
    ~name:"reconstruct_starting_in"
    ~msg:
      "For the level {level} and slot index {slot_index}, enough shards have \
       been received to reconstruct the slot. If the remaining shards are not \
       received in {delay} seconds, they will be reconstructed."
    ~level:Info
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)
    ~pp3:Format.pp_print_float
    ("delay", Data_encoding.float)

let reconstruct_started =
  declare_4
    ~section
    ~name:"reconstruct_started"
    ~msg:
      "For the level {level} and slot index {slot_index}, \
       {number_of_received_shards} out of {number_of_shards} shards were \
       received, starting a reconstruction of the missing shards."
    ~level:Notice
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)
    ~pp3:Format.pp_print_int
    ("number_of_received_shards", Data_encoding.int31)
    ~pp4:Format.pp_print_int
    ("number_of_shards", Data_encoding.int31)

let reconstruct_finished =
  declare_2
    ~section
    ~name:"reconstruct_finished"
    ~msg:
      "For the level {level} and slot index {slot_index}, missing shards have \
       been successfully reconstructed."
    ~level:Notice
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)

let reconstruct_no_missing_shard =
  declare_2
    ~section
    ~name:"reconstruct_no_missing_shard"
    ~msg:
      "For the level {level}, all shards for slot index {slot_index} were \
       received. The planned reconstruction has been cancelled."
    ~level:Info
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)

let reconstruct_error =
  declare_3
    ~section
    ~name:"reconstruct_error"
    ~msg:
      "For the level {level} and slot index {slot_index}, unexpected error \
       during reconstruction: {error}."
    ~level:Error
    ~pp1:(fun fmt -> Format.fprintf fmt "%ld")
    ("level", Data_encoding.int32)
    ~pp2:Format.pp_print_int
    ("slot_index", Data_encoding.int31)
    ("error", Error_monad.trace_encoding)
