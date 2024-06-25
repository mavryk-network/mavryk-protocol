(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
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

(** Michelson type to use when originating the EVM rollup. *)
val evm_type : string

(** [u16_to_bytes n] translate an int in a binary string of two bytes
    (little endian).
    NB: Ints greater than 2 bytes are truncated. *)
val u16_to_bytes : int -> string

(** [mapping_position key map_position] computes the storage position for
    a value in a mapping given its [key] and the position of the map
    itself.
    It computes this position as:
    [keccack(LeftPad32(key, 0), LeftPad32(map_position, 0))]
    as specified in
    https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs
*)
val mapping_position : string -> int -> string

(** Transform an hexadecimal string to an integer using {!Z.of_bits}. *)
val hex_string_to_int : string -> int

(** [next_rollup_node_level ~sc_rollup_node ~client] moves
    [sc_rollup_node] to the next level l1. *)
val next_rollup_node_level :
  sc_rollup_node:Sc_rollup_node.t -> client:Client.t -> int Lwt.t

(** [next_evm_level ~evm_node ~sc_rollup_node ~client] moves
    [evm_node] to the next L2 level. *)
val next_evm_level :
  evm_node:Evm_node.t ->
  sc_rollup_node:Sc_rollup_node.t ->
  client:Client.t ->
  unit Lwt.t

(** Path to the directory containing sample inputs. *)
val kernel_inputs_path : string

(** [read_tx_from_file ()] reads a file containing 100 transactions.
    The list returned contains pairs of the shape [(tx_raw, tx_hash)].
*)
val read_tx_from_file : unit -> (string * string) list

(** [force_kernel_upgrade ~sc_rollup_address ~sc_rollup_node ~node
    ~client] produces the force kernel upgrade and sends it via the
    client. [sc_rollup_address] is expected to be the b58 address. *)
val force_kernel_upgrade :
  sc_rollup_address:string ->
  sc_rollup_node:Sc_rollup_node.t ->
  client:Client.t ->
  unit Lwt.t

(** [upgrade ~sc_rollup_node ~sc_rollup_address ~admin ~admin_contract
    ~client ~upgrade_to ~activation_timestamp ] prepares the
    kernel upgrade payload and sends it to the layer 1. *)
val upgrade :
  sc_rollup_node:Sc_rollup_node.t ->
  sc_rollup_address:string ->
  admin:string ->
  admin_contract:string ->
  client:Client.t ->
  upgrade_to:Uses.t ->
  activation_timestamp:string ->
  unit Lwt.t

(** [check_block_consistency ~left ~right ?error_msg ~blocks ()]
    checks that the block hash of [left] and [right] are equal. Fails
    if they are not with [error_msg] *)
val check_block_consistency :
  left:Evm_node.t ->
  right:Evm_node.t ->
  ?error_msg:string ->
  block:[< `Latest | `Level of int32] ->
  unit ->
  unit Lwt.t

(** Checks latest block using {!check_block_consistency}. *)
val check_head_consistency :
  left:Evm_node.t -> right:Evm_node.t -> ?error_msg:string -> unit -> unit Lwt.t

(** [sequencer_upgrade ~sc_rollup_address ~sequencer_admin
    ~sequencer_admin_contract ~client ~upgrade_to
    ~activation_timestamp] prepares the sequencer upgrade payload and
    sends it to the layer 1. *)
val sequencer_upgrade :
  sc_rollup_address:string ->
  sequencer_admin:string ->
  sequencer_governance_contract:string ->
  client:Client.t ->
  upgrade_to:string ->
  pool_address:string ->
  activation_timestamp:string ->
  unit Lwt.t

(** [bake_until_sync ?timeout ~sc_rollup_node ~proxy ~sequencer
    ~client] bakes blocks until the rollup node is synced with
    evm_node. timeout if it takes more than [timeout] sec, 30. by
    default. *)
val bake_until_sync :
  ?timeout:float ->
  sc_rollup_node:Sc_rollup_node.t ->
  proxy:Evm_node.t ->
  sequencer:Evm_node.t ->
  client:Client.t ->
  unit ->
  unit Lwt.t

(** [wait_for_transaction_receipt ?count ~evm_node ~transaction_hash ()] takes a
    transaction_hash and returns only when the receipt is non null, or [count]
    blocks have passed and the receipt is still not available. *)
val wait_for_transaction_receipt :
  ?count:int ->
  evm_node:Evm_node.t ->
  transaction_hash:string ->
  unit ->
  Transaction.transaction_receipt Lwt.t

(** [wait_for_application ~evm_node ~sc_rollup_node ~client apply] returns only
    when the `apply` yields, or fails when 10 blocks have passed. *)
val wait_for_application :
  evm_node:Evm_node.t ->
  sc_rollup_node:Sc_rollup_node.t ->
  client:Client.t ->
  (unit -> 'a Lwt.t) ->
  'a Lwt.t

(** [batch_n_transactions ~evm_node raw_transactions] batches [raw_transactions]
    to the [evm_node] and returns the requests and transaction hashes. *)
val batch_n_transactions :
  evm_node:Evm_node.t ->
  string list ->
  (Evm_node.request list * string list) Lwt.t

(** [send_n_transactions ~sc_rollup_node ~evm_node ?wait_for_blocks
    raw_transactions] batches [raw_transactions] to the [evm_node] and waits
    until the first one is applied in a block and returns, or fails if it isn't
    applied after [wait_for_blocks] blocks. *)
val send_n_transactions :
  sc_rollup_node:Sc_rollup_node.t ->
  client:Client.t ->
  evm_node:Evm_node.t ->
  ?wait_for_blocks:int ->
  string list ->
  (Evm_node.request list * Transaction.transaction_receipt * string list) Lwt.t
