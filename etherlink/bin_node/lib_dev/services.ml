(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2023 Functori <contact@functori.com>                        *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
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

open Tezos_rpc
open Rpc_encodings

let version_service =
  Service.get_service
    ~description:"version"
    ~query:Query.empty
    ~output:Data_encoding.string
    Path.(root / "version")

let client_version =
  Format.sprintf
    "%s/%s-%s/%s/ocamlc.%s"
    "octez-evm-node"
    (Tezos_version.Version.to_string
       Tezos_version_value.Current_git_info.etherlink_version)
    Tezos_version_value.Current_git_info.abbreviated_commit_hash
    Stdlib.Sys.os_type
    Stdlib.Sys.ocaml_version

let version dir =
  Directory.register0 dir version_service (fun () () ->
      Lwt.return_ok client_version)

(* The node can either take a single request or multiple requests at
   once. *)
type 'a batched_request = Singleton of 'a | Batch of 'a list

let request_encoding kind =
  Data_encoding.(
    union
      [
        case
          ~title:"singleton"
          (Tag 0)
          kind
          (function Singleton i -> Some i | _ -> None)
          (fun i -> Singleton i);
        case
          ~title:"batch"
          (Tag 1)
          (list kind)
          (function Batch i -> Some i | _ -> None)
          (fun i -> Batch i);
      ])

let dispatch_service ~path =
  Service.post_service
    ~query:Query.empty
    ~input:(request_encoding JSONRPC.request_encoding)
    ~output:(request_encoding JSONRPC.response_encoding)
    path

let get_block_by_number ~full_transaction_object block_param
    (module Rollup_node_rpc : Services_backend_sig.S) =
  match block_param with
  | Ethereum_types.(Hash_param (Block_height n)) ->
      Rollup_node_rpc.nth_block ~full_transaction_object n
  | Latest | Earliest | Pending ->
      Rollup_node_rpc.current_block ~full_transaction_object

let get_transaction_from_index block index
    (module Rollup_node_rpc : Services_backend_sig.S) =
  let open Lwt_result_syntax in
  match block.Ethereum_types.transactions with
  | TxHash l -> (
      match List.nth_opt l index with
      | None -> return_none
      | Some hash -> Rollup_node_rpc.transaction_object hash)
  | TxFull l -> return @@ List.nth_opt l index

let block_transaction_count block =
  Ethereum_types.quantity_of_z @@ Z.of_int
  @@
  match block.Ethereum_types.transactions with
  | TxHash l -> List.length l
  | TxFull l -> List.length l

let decode :
    type a. (module METHOD with type input = a) -> Data_encoding.json -> a =
 fun (module M) v -> Data_encoding.Json.destruct M.input_encoding v

let encode :
    type a. (module METHOD with type output = a) -> a -> Data_encoding.json =
 fun (module M) v -> Data_encoding.Json.construct M.output_encoding v

let build :
    type input output.
    (module METHOD with type input = input and type output = output) ->
    f:
      (input option ->
      (output, string * Ethereum_types.hash option) Either.t tzresult Lwt.t) ->
    Data_encoding.json option ->
    JSONRPC.value Lwt.t =
 fun (module Method) ~f parameters ->
  let open Lwt_syntax in
  let decoded = Option.map (decode (module Method)) parameters in
  let+ v = f decoded in
  match v with
  | Error err ->
      let message = Format.asprintf "%a" pp_print_trace err in
      Error JSONRPC.{code = -32000; message; data = None}
  | Ok value -> (
      match value with
      | Left output -> Ok (encode (module Method) output)
      | Right (message, data) ->
          let data =
            Option.map
              (Data_encoding.Json.construct Ethereum_types.hash_encoding)
              data
          in
          Error JSONRPC.{code = -32000; message; data})

let rpc_ok result = Lwt_result_syntax.return (Either.Left result)

let rpc_error ?data message =
  Lwt_result_syntax.return (Either.Right (message, data))

let missing_parameter () = rpc_error "Missing parameters"

let expect_input input f =
  match input with None -> missing_parameter () | Some v -> f v

let build_with_input method_ ~f parameters =
  build method_ ~f:(fun input -> expect_input input f) parameters

let dispatch_request (config : Configuration.t)
    ((module Backend_rpc : Services_backend_sig.S), _)
    ({method_; parameters; id} : JSONRPC.request) : JSONRPC.response Lwt.t =
  let open Lwt_result_syntax in
  let open Ethereum_types in
  let*! value =
    match map_method_name method_ with
    | Unknown ->
        Lwt.return
          (Error
             JSONRPC.
               {
                 code = -3200;
                 message = "Method not found";
                 data = Some (`String method_);
               })
    | Unsupported ->
        Lwt.return
          (Error
             JSONRPC.
               {
                 code = -3200;
                 message = "Method not supported";
                 data = Some (`String method_);
               })
    (* Ethereum JSON-RPC API methods we support *)
    | Method (Accounts.Method, module_) ->
        let f (_ : unit option) = rpc_ok [] in
        build ~f module_ parameters
    | Method (Network_id.Method, module_) ->
        let f (_ : unit option) =
          let open Lwt_result_syntax in
          let* (Qty chain_id) = Backend_rpc.chain_id () in
          rpc_ok (Z.to_string chain_id)
        in
        build ~f module_ parameters
    | Method (Chain_id.Method, module_) ->
        let f (_ : unit option) =
          let* chain_id = Backend_rpc.chain_id () in
          rpc_ok chain_id
        in
        build ~f module_ parameters
    | Method (Get_balance.Method, module_) ->
        let f (address, _block_param) =
          let* balance = Backend_rpc.balance address in
          rpc_ok balance
        in
        build_with_input ~f module_ parameters
    | Method (Get_storage_at.Method, module_) ->
        let f (address, position, _block_param) =
          let* value = Backend_rpc.storage_at address position in
          rpc_ok value
        in
        build_with_input ~f module_ parameters
    | Method (Block_number.Method, module_) ->
        let f (_ : unit option) =
          let* block_number = Backend_rpc.current_block_number () in
          rpc_ok block_number
        in
        build ~f module_ parameters
    | Method (Get_block_by_number.Method, module_) ->
        let f (block_param, full_transaction_object) =
          let* block =
            get_block_by_number
              ~full_transaction_object
              block_param
              (module Backend_rpc)
          in
          rpc_ok block
        in
        build_with_input ~f module_ parameters
    | Method (Get_block_by_hash.Method, module_) ->
        let f (block_hash, full_transaction_object) =
          let* block =
            Backend_rpc.block_by_hash ~full_transaction_object block_hash
          in
          rpc_ok block
        in
        build_with_input ~f module_ parameters
    | Method (Get_code.Method, module_) ->
        let f (address, _) =
          let* code = Backend_rpc.code address in
          rpc_ok code
        in
        build_with_input ~f module_ parameters
    | Method (Gas_price.Method, module_) ->
        let f (_ : unit option) =
          let* base_fee = Backend_rpc.base_fee_per_gas () in
          rpc_ok base_fee
        in
        build ~f module_ parameters
    | Method (Get_transaction_count.Method, module_) ->
        let f (address, _) =
          let* nonce = Tx_pool.nonce address in
          rpc_ok nonce
        in
        build_with_input ~f module_ parameters
    | Method (Get_block_transaction_count_by_hash.Method, module_) ->
        let f block_hash =
          let* block =
            Backend_rpc.block_by_hash ~full_transaction_object:false block_hash
          in
          rpc_ok (block_transaction_count block)
        in
        build_with_input ~f module_ parameters
    | Method (Get_block_transaction_count_by_number.Method, module_) ->
        let f block_param =
          let* block =
            get_block_by_number
              ~full_transaction_object:false
              block_param
              (module Backend_rpc)
          in
          rpc_ok (block_transaction_count block)
        in
        build_with_input ~f module_ parameters
    | Method (Get_uncle_count_by_block_hash.Method, module_) ->
        let f _block_param = rpc_ok (Qty Z.zero) in
        build_with_input ~f module_ parameters
    | Method (Get_uncle_count_by_block_number.Method, module_) ->
        let f _block_param = rpc_ok (Qty Z.zero) in
        build_with_input ~f module_ parameters
    | Method (Get_transaction_receipt.Method, module_) ->
        let f tx_hash =
          let* receipt = Backend_rpc.transaction_receipt tx_hash in
          rpc_ok receipt
        in
        build_with_input ~f module_ parameters
    | Method (Get_transaction_by_hash.Method, module_) ->
        let f tx_hash =
          let* transaction_object = Backend_rpc.transaction_object tx_hash in
          rpc_ok transaction_object
        in
        build_with_input ~f module_ parameters
    | Method (Get_transaction_by_block_hash_and_index.Method, module_) ->
        let f (block_hash, Qty index) =
          let* block =
            Backend_rpc.block_by_hash ~full_transaction_object:false block_hash
          in
          let* transaction_object =
            get_transaction_from_index
              block
              (Z.to_int index)
              (module Backend_rpc)
          in
          rpc_ok transaction_object
        in
        build_with_input ~f module_ parameters
    | Method (Get_transaction_by_block_number_and_index.Method, module_) ->
        let f (block_number, Qty index) =
          let* block =
            get_block_by_number
              ~full_transaction_object:false
              block_number
              (module Backend_rpc)
          in
          let* transaction_object =
            get_transaction_from_index
              block
              (Z.to_int index)
              (module Backend_rpc)
          in
          rpc_ok transaction_object
        in
        build_with_input ~f module_ parameters
    | Method (Get_uncle_by_block_hash_and_index.Method, module_) ->
        let f (_block_hash, _index) =
          (* A block cannot have uncles. *)
          rpc_ok None
        in
        build_with_input ~f module_ parameters
    | Method (Get_uncle_by_block_number_and_index.Method, module_) ->
        let f (_block_number, _index) =
          (* A block cannot have uncles. *)
          rpc_ok None
        in
        build_with_input ~f module_ parameters
    | Method (Send_raw_transaction.Method, module_) ->
        let f tx_raw =
          let* tx_hash = Tx_pool.add (Ethereum_types.hex_to_bytes tx_raw) in
          match tx_hash with
          | Ok tx_hash -> rpc_ok tx_hash
          | Error reason ->
              (* TODO: https://gitlab.com/tezos/tezos/-/issues/6229 *)
              rpc_error reason
        in
        build_with_input ~f module_ parameters
    | Method (Eth_call.Method, module_) ->
        let f (call, _) =
          let* call_result = Backend_rpc.simulate_call call in
          match call_result with
          | Ok (Ok {value = Some value; gas_used = _}) -> rpc_ok value
          | Ok (Ok {value = None; gas_used = _}) -> rpc_ok (hash_of_string "")
          | Ok (Error reason) -> rpc_error ~data:reason "execution reverted"
          | Error reason ->
              (* TODO: https://gitlab.com/tezos/tezos/-/issues/6229 *)
              rpc_error reason
        in
        build_with_input ~f module_ parameters
    | Method (Get_estimate_gas.Method, module_) ->
        let f (call, _) =
          let* result = Backend_rpc.estimate_gas call in
          match result with
          | Ok (Ok {value = _; gas_used = Some gas}) -> rpc_ok gas
          | Ok (Ok {value = _; gas_used = None}) ->
              rpc_error
                "Simulation failed before execution, cannot estimate gas."
          | Ok (Error reason) -> rpc_error ~data:reason "execution reverted"
          | Error reason ->
              (* TODO: https://gitlab.com/tezos/tezos/-/issues/6229 *)
              rpc_error reason
        in
        build_with_input ~f module_ parameters
    | Method (Txpool_content.Method, module_) ->
        let f (_ : unit option) =
          rpc_ok
            Ethereum_types.
              {pending = AddressMap.empty; queued = AddressMap.empty}
        in
        build ~f module_ parameters
    | Method (Web3_clientVersion.Method, module_) ->
        let f (_ : unit option) = rpc_ok client_version in
        build ~f module_ parameters
    | Method (Web3_sha3.Method, module_) ->
        let f data =
          let open Ethereum_types in
          let (Hex h) = data in
          let bytes = Hex.to_bytes_exn (`Hex h) in
          let hash_bytes = Tezos_crypto.Hacl.Hash.Keccak_256.digest bytes in
          let hash = Hex.of_bytes hash_bytes |> Hex.show in
          rpc_ok (Hash (Hex hash))
        in
        build_with_input ~f module_ parameters
    | Method (Get_logs.Method, module_) ->
        let f filter =
          let* logs =
            Filter_helpers.get_logs
              config.log_filter
              (module Backend_rpc)
              filter
          in
          rpc_ok logs
        in
        build_with_input ~f module_ parameters
        (* Internal RPC methods *)
    | Method (Kernel_version.Method, module_) ->
        let f (_ : unit option) =
          let* kernel_version = Backend_rpc.kernel_version () in
          rpc_ok kernel_version
        in
        build ~f module_ parameters
    | Method (Kernel_root_hash.Method, module_) ->
        let f (_ : unit option) =
          let* kernel_root_hash = Backend_rpc.kernel_root_hash () in
          rpc_ok kernel_root_hash
        in
        build ~f module_ parameters
    | _ -> Stdlib.failwith "The pattern matching of methods is not exhaustive"
  in
  Lwt.return JSONRPC.{value; id}

let dispatch_private_request (_config : Configuration.t)
    ((module Backend_rpc : Services_backend_sig.S), _)
    ({method_; parameters; id} : JSONRPC.request) : JSONRPC.response Lwt.t =
  let open Lwt_syntax in
  let* value =
    match map_method_name method_ with
    | Unknown ->
        return
          (Error
             JSONRPC.
               {
                 code = -3200;
                 message = "Method not found";
                 data = Some (`String method_);
               })
    | Unsupported ->
        return
          (Error
             JSONRPC.
               {
                 code = -3200;
                 message = "Method not supported";
                 data = Some (`String method_);
               })
    | Method (Produce_block.Method, module_) ->
        let f (timestamp : Time.Protocol.t option) =
          let open Lwt_result_syntax in
          let timestamp = Option.value timestamp ~default:(Helpers.now ()) in
          let* nb_transactions =
            Block_producer.produce_block ~force:true ~timestamp
          in
          rpc_ok (Ethereum_types.quantity_of_z @@ Z.of_int nb_transactions)
        in
        build ~f module_ parameters
    | Method (Durable_state_value.Method, module_) ->
        let f path =
          let open Lwt_result_syntax in
          let*? path =
            Option.to_result
              ~none:[error_of_fmt "missing params, please provide a path"]
              path
          in
          let* value = Backend_rpc.Reader.read path in
          rpc_ok value
        in
        build ~f module_ parameters
    | _ -> Stdlib.failwith "The pattern matching of methods is not exhaustive"
  in
  return JSONRPC.{value; id}

let generic_dispatch config ctx dir path dispatch_request =
  Directory.register0 dir (dispatch_service ~path) (fun () input ->
      let open Lwt_result_syntax in
      match input with
      | Singleton request ->
          let*! response = dispatch_request config ctx request in
          return (Singleton response)
      | Batch requests ->
          let*! outputs = List.map_s (dispatch_request config ctx) requests in
          return (Batch outputs))

let dispatch_public config ctx dir =
  generic_dispatch config ctx dir Path.root dispatch_request

let dispatch_private config ctx dir =
  generic_dispatch
    config
    ctx
    dir
    Path.(add_suffix root "private")
    dispatch_private_request

let directory config
    ((module Rollup_node_rpc : Services_backend_sig.S), smart_rollup_address) =
  Directory.empty |> version
  |> dispatch_public
       config
       ((module Rollup_node_rpc : Services_backend_sig.S), smart_rollup_address)

let private_directory config
    ((module Rollup_node_rpc : Services_backend_sig.S), smart_rollup_address) =
  Directory.empty |> version
  |> dispatch_private
       config
       ((module Rollup_node_rpc : Services_backend_sig.S), smart_rollup_address)
