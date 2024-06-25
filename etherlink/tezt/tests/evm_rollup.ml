(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2023-2024 TriliTech <contact@trili.tech>                    *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(* Copyright (c) 2023-2024 Functori <contact@functori.com>                   *)
(*                                                                           *)
(*****************************************************************************)

(* Testing
   -------
   Component:    Smart Optimistic Rollups: EVM Kernel
   Requirement:  make -f kernels.mk build
                 npm install eth-cli
   Invocation:   dune exec etherlink/tezt/tests/main.exe -- --file evm_rollup.ml
*)
open Sc_rollup_helpers
open Helpers
open Rpc.Syntax
open Contract_path

let pvm_kind = "wasm_2_0_0"

let base_fee_for_hardcoded_tx = Wei.to_wei_z @@ Z.of_int 21000

type l1_contracts = {
  exchanger : string;
  bridge : string;
  admin : string;
  kernel_governance : string;
  kernel_security_governance : string;
  sequencer_governance : string option;
}

type full_evm_setup = {
  node : Node.t;
  client : Client.t;
  sc_rollup_node : Sc_rollup_node.t;
  sc_rollup_address : string;
  originator_key : string;
  rollup_operator_key : string;
  evm_node : Evm_node.t;
  endpoint : string;
  l1_contracts : l1_contracts option;
  config :
    [ `Config of Installer_kernel_config.t
    | `Path of string
    | `Both of Installer_kernel_config.instr list * string ]
    option;
  kernel : string;
  kernel_root_hash : string;
}

let hex_256_of n = Printf.sprintf "%064x" n

let hex_256_of_address acc =
  let s = acc.Eth_account.address in
  (* strip 0x and convert to lowercase *)
  let n = String.length s in
  let s = String.lowercase_ascii @@ String.sub s 2 (n - 2) in
  (* prepend 24 leading zeros *)
  String.("0x" ^ make 24 '0' ^ s)

let expected_gas_fees ~gas_price ~gas_used =
  let open Wei in
  let gas_price = gas_price |> Z.of_int64 |> Wei.to_wei_z in
  let gas_used = gas_used |> Z.of_int64 in
  gas_price * gas_used

let evm_node_version evm_node =
  let endpoint = Evm_node.endpoint evm_node in
  let get_version_url = endpoint ^ "/version" in
  Curl.get get_version_url

let get_transaction_status ~endpoint ~tx =
  let* receipt = Eth_cli.get_receipt ~endpoint ~tx in
  match receipt with
  | None ->
      failwith "no transaction receipt, probably it hasn't been mined yet."
  | Some r -> return r.status

let check_tx_succeeded ~endpoint ~tx =
  let* status = get_transaction_status ~endpoint ~tx in
  Check.(is_true status) ~error_msg:"Expected transaction to succeed." ;
  unit

let check_tx_failed ~endpoint ~tx =
  (* Eth-cli sometimes wraps receipt of failed transaction in its own error
     message. This means that the [tx] could be an empty string.
     Additionally, the output of eth-cli might contain some extra characters,
     so we use a regular expression to make sure we get a valid hash.
  *)
  let tx = tx =~* rex "(0x[0-9a-fA-F]{64})" in
  match tx with
  | Some tx ->
      let* status = get_transaction_status ~endpoint ~tx in
      Check.(is_false status) ~error_msg:"Expected transaction to fail." ;
      unit
  | None -> unit

(* Check simple transfer fee is correct

   We apply a da_fee to every tx - which is paid through an
   increase in in either/both gas_used, gas_price.

   We prefer to keep [gas_used == execution_gas_used] where possible, but
   when this results in [gas_price > tx.max_price_per_gas], we set gas_price to
   tx.max_price_per_gas, and increase the gas_used in the receipt.
*)
let check_tx_gas_for_fee ~da_fee_per_byte ~expected_execution_gas ~gas_price
    ~gas_used ~base_fee_per_gas ~data_size =
  (* execution gas fee *)
  let expected_execution_gas = Z.of_int expected_execution_gas in
  let expected_base_fee_per_gas = Z.of_int32 base_fee_per_gas in
  let execution_gas_fee =
    Z.mul expected_execution_gas expected_base_fee_per_gas
  in
  (* Data availability fee *)
  let assumed_encoded_size = 150 in
  let size = Z.of_int (assumed_encoded_size + data_size) in
  let da_fee = Wei.(da_fee_per_byte * size) in
  (* total fee 'in gas' *)
  let expected_total_fee =
    Z.add (Wei.of_wei_z da_fee) execution_gas_fee |> Z.to_int64
  in
  let total_fee_receipt =
    Z.(mul (of_int64 gas_price) (of_int64 gas_used)) |> Z.to_int64
  in
  Check.((total_fee_receipt >= expected_total_fee) int64)
    ~error_msg:"total fee in receipt %L did not cover expected fees of %R"

let check_status_n_logs ~endpoint ~status ~logs ~tx =
  let* receipt = Eth_cli.get_receipt ~endpoint ~tx in
  match receipt with
  | None ->
      failwith "no transaction receipt, probably it hasn't been mined yet."
  | Some r ->
      Check.(
        (r.status = status)
          bool
          ~__LOC__
          ~error_msg:"Unexpected transaction status, expected: %R but got: %L") ;
      let received_logs = List.map Transaction.extract_log_body r.logs in
      Check.(
        (received_logs = logs)
          (list (tuple3 string (list string) string))
          ~__LOC__
          ~error_msg:"Unexpected transaction logs, expected:\n%R but got:\n%L") ;
      unit

(** [get_value_in_storage client addr nth] fetch the [nth] value in the storage
    of account [addr]  *)
let get_value_in_storage sc_rollup_node address nth =
  Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
  @@ Sc_rollup_rpc.get_global_block_durable_state_value
       ~pvm_kind
       ~operation:Sc_rollup_rpc.Value
       ~key:(Durable_storage_path.storage address ~key:(hex_256_of nth) ())
       ()

let check_str_in_storage ~evm_setup ~address ~nth ~expected =
  let* value = get_value_in_storage evm_setup.sc_rollup_node address nth in
  Check.((value = Some expected) (option string))
    ~error_msg:"Unexpected value in storage, should be %R, but got %L" ;
  unit

let check_nb_in_storage ~evm_setup ~address ~nth ~expected =
  check_str_in_storage ~evm_setup ~address ~nth ~expected:(hex_256_of expected)

let get_storage_size sc_rollup_node ~address =
  let* storage =
    Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:(Durable_storage_path.storage address ())
         ()
  in
  return (List.length storage)

let check_storage_size sc_rollup_node ~address size =
  (* check storage size *)
  let* storage_size = get_storage_size sc_rollup_node ~address in
  Check.((storage_size = size) int)
    ~error_msg:"Unexpected storage size, should be %R, but is %L" ;
  unit

let setup_l1_contracts ~admin ?sequencer_admin client =
  (* Originates the exchanger. *)
  let* exchanger =
    Client.originate_contract
      ~alias:"exchanger"
      ~amount:Tez.zero
      ~src:Constant.bootstrap1.public_key_hash
      ~init:"Unit"
      ~prg:(exchanger_path ())
      ~burn_cap:Tez.one
      client
  in
  (* Originates the bridge. *)
  let* bridge =
    Client.originate_contract
      ~alias:"evm-bridge"
      ~amount:Tez.zero
      ~src:Constant.bootstrap2.public_key_hash
      ~init:(sf "Pair %S None" exchanger)
      ~prg:(bridge_path ())
      ~burn_cap:Tez.one
      client
  (* Originates the administrator contract. *)
  and* admin_contract =
    Client.originate_contract
      ~alias:"evm-admin"
      ~amount:Tez.zero
      ~src:Constant.bootstrap3.public_key_hash
      ~init:(sf "%S" admin.Account.public_key_hash)
      ~prg:(admin_path ())
      ~burn_cap:Tez.one
      client
  (* Originates the governance contract (using the administrator contract). *)
  and* kernel_governance =
    Client.originate_contract
      ~alias:"kernel-governance"
      ~amount:Tez.zero
      ~src:Constant.bootstrap4.public_key_hash
      ~init:(sf "%S" admin.Account.public_key_hash)
      ~prg:(admin_path ())
      ~burn_cap:Tez.one
      client
  (* Originates the governance contract (using the administrator contract). *)
  and* kernel_security_governance =
    Client.originate_contract
      ~alias:"security-governance"
      ~amount:Tez.zero
      ~src:Constant.bootstrap5.public_key_hash
      ~init:(sf "%S" admin.Account.public_key_hash)
      ~prg:(admin_path ())
      ~burn_cap:Tez.one
      client
  in
  let* () = Client.bake_for_and_wait ~keys:[] client in

  (* Originates the sequencer administrator contract. *)
  let* sequencer_governance =
    match sequencer_admin with
    | Some sequencer_admin ->
        let* sequencer_admin =
          Client.originate_contract
            ~alias:"evm-sequencer-admin"
            ~amount:Tez.zero
            ~src:Constant.bootstrap1.public_key_hash
            ~init:(sf "%S" sequencer_admin.Account.public_key_hash)
            ~prg:(admin_path ())
            ~burn_cap:Tez.one
            client
        in
        let* () = Client.bake_for_and_wait ~keys:[] client in
        return (Some sequencer_admin)
    | None -> return None
  in
  return
    {
      exchanger;
      bridge;
      admin = admin_contract;
      kernel_governance;
      sequencer_governance;
      kernel_security_governance;
    }

type setup_mode =
  | Setup_sequencer of {
      time_between_blocks : Evm_node.time_between_blocks option;
      sequencer : Account.key;
      devmode : bool;
    }
  | Setup_proxy of {devmode : bool}

let setup_evm_kernel ?(setup_kernel_root_hash = true) ?config
    ?(kernel_installee = Constant.WASM.evm_kernel)
    ?(originator_key = Constant.bootstrap1.public_key_hash)
    ?(rollup_operator_key = Constant.bootstrap1.public_key_hash)
    ?(bootstrap_accounts = Eth_account.bootstrap_accounts)
    ?(with_administrator = true) ?da_fee_per_byte ?minimum_base_fee_per_gas
    ~admin ?sequencer_admin ?commitment_period ?challenge_window ?timestamp
    ?tx_pool_timeout_limit ?tx_pool_addr_limit ?tx_pool_tx_per_addr_limit
    ?(setup_mode = Setup_proxy {devmode = true}) ?(force_install_kernel = true)
    protocol =
  let* node, client =
    setup_l1 ?commitment_period ?challenge_window ?timestamp protocol
  in
  let* l1_contracts =
    match admin with
    | Some admin ->
        let* res = setup_l1_contracts ~admin ?sequencer_admin client in
        return (Some res)
    | None -> return None
  in
  let* kernel_root_hash =
    if setup_kernel_root_hash then
      let* {root_hash; _} =
        prepare_installer_kernel
          ~preimages_dir:(Temp.dir "ignored_preimages")
          kernel_installee
      in
      return (Some root_hash)
    else return None
  in
  (* If a L1 bridge was set up, we make the kernel aware of the address. *)
  let base_config =
    let ticketer = Option.map (fun {exchanger; _} -> exchanger) l1_contracts in
    let administrator =
      if with_administrator then
        Option.map (fun {admin; _} -> admin) l1_contracts
      else None
    in
    let kernel_governance =
      Option.map (fun {kernel_governance; _} -> kernel_governance) l1_contracts
    in
    let kernel_security_governance =
      Option.map
        (fun {kernel_security_governance; _} -> kernel_security_governance)
        l1_contracts
    in
    let sequencer =
      match setup_mode with
      | Setup_proxy _ -> None
      | Setup_sequencer {sequencer; _} -> Some sequencer.public_key
    in
    Configuration.make_config
      ?kernel_root_hash
      ~bootstrap_accounts
      ?da_fee_per_byte
      ?minimum_base_fee_per_gas
      ?ticketer
      ?administrator
      ?kernel_governance
      ?kernel_security_governance
      ?sequencer
      ?sequencer_governance:
        (Option.bind l1_contracts (fun {sequencer_governance; _} ->
             sequencer_governance))
      ()
  in
  let config =
    match (config, base_config) with
    | Some (`Config config), Some (`Config base) ->
        Some (`Config (base @ config))
    | Some (`Path path), Some (`Config base) -> Some (`Both (base, path))
    | None, _ -> base_config
    | Some (`Config config), None -> Some (`Config config)
    | Some (`Path path), None -> Some (`Path path)
  in
  let sc_rollup_node =
    Sc_rollup_node.create
      Operator
      node
      ~base_dir:(Client.base_dir client)
      ~default_operator:rollup_operator_key
  in
  (* Start a rollup node *)
  let preimages_dir =
    Filename.concat (Sc_rollup_node.data_dir sc_rollup_node) "wasm_2_0_0"
  in
  let* {output; root_hash; _} =
    prepare_installer_kernel ~preimages_dir ?config kernel_installee
  in
  let* sc_rollup_address =
    originate_sc_rollup
      ~keys:[]
      ~kind:pvm_kind
      ~boot_sector:("file:" ^ output)
      ~parameters_ty:evm_type
      ~src:originator_key
      client
  in
  let* () =
    Sc_rollup_node.run sc_rollup_node sc_rollup_address [Log_kernel_debug]
  in
  (* EVM Kernel installation level. *)
  let* () =
    if force_install_kernel then
      let* () = Client.bake_for_and_wait ~keys:[] client in
      let* level = Node.get_level node in
      let* _ =
        Sc_rollup_node.wait_for_level ~timeout:30. sc_rollup_node level
      in
      unit
    else unit
  in
  let* mode =
    match setup_mode with
    | Setup_proxy {devmode} -> return (Evm_node.Proxy {devmode})
    | Setup_sequencer {time_between_blocks; sequencer; devmode} ->
        let private_rpc_port = Some (Port.fresh ()) in
        return
          (Evm_node.Sequencer
             {
               initial_kernel = output;
               preimage_dir = preimages_dir;
               private_rpc_port;
               time_between_blocks;
               sequencer = sequencer.alias;
               genesis_timestamp = None;
               max_blueprints_lag = None;
               max_blueprints_ahead = None;
               max_blueprints_catchup = None;
               catchup_cooldown = None;
               max_number_of_chunks = None;
               devmode;
               wallet_dir = Some (Client.base_dir client);
               tx_pool_timeout_limit;
               tx_pool_addr_limit;
               tx_pool_tx_per_addr_limit;
             })
  in
  let* evm_node =
    Evm_node.init ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let endpoint = Evm_node.endpoint evm_node in
  return
    {
      node;
      client;
      sc_rollup_node;
      sc_rollup_address;
      originator_key;
      rollup_operator_key;
      evm_node;
      endpoint;
      l1_contracts;
      config;
      kernel = output;
      kernel_root_hash = root_hash;
    }

let register_test ?config ~title ~tags ?(admin = None) ?uses ?commitment_period
    ?challenge_window ?bootstrap_accounts ?da_fee_per_byte
    ?minimum_base_fee_per_gas ~setup_mode f =
  let extra_tag =
    match setup_mode with
    | Setup_proxy _ -> "proxy"
    | Setup_sequencer _ -> "sequencer"
  in
  let uses =
    Option.value
      ~default:(fun _protocol ->
        [
          Constant.octez_smart_rollup_node;
          Constant.octez_evm_node;
          Constant.smart_rollup_installer;
          Constant.WASM.evm_kernel;
        ])
      uses
  in
  Protocol.register_test
    ~__FILE__
    ~tags:(extra_tag :: tags)
    ~uses
    ~title:(sf "%s (%s)" title extra_tag)
    (fun protocol ->
      let* evm_setup =
        setup_evm_kernel
          ?config
          ?commitment_period
          ?challenge_window
          ?bootstrap_accounts
          ?da_fee_per_byte
          ?minimum_base_fee_per_gas
          ~admin
          ~setup_mode
          protocol
      in
      f ~protocol ~evm_setup)

let register_proxy ?config ~title ~tags ?uses ?admin ?commitment_period
    ?challenge_window ?bootstrap_accounts ?minimum_base_fee_per_gas f protocols
    =
  register_test
    ?config
    ~title
    ~tags
    ?uses
    ?admin
    ?commitment_period
    ?challenge_window
    ?bootstrap_accounts
    ?minimum_base_fee_per_gas
    f
    protocols
    ~setup_mode:(Setup_proxy {devmode = true})

let register_both ~title ~tags ?uses ?admin ?commitment_period ?challenge_window
    ?bootstrap_accounts ?da_fee_per_byte ?minimum_base_fee_per_gas ?config
    ?time_between_blocks f protocols =
  let register =
    register_test
      ?config
      ~title
      ~tags
      ?uses
      ?admin
      ?commitment_period
      ?challenge_window
      ?bootstrap_accounts
      ?da_fee_per_byte
      ?minimum_base_fee_per_gas
      f
      protocols
  in
  register ~setup_mode:(Setup_proxy {devmode = true}) ;
  register
    ~setup_mode:
      (Setup_sequencer
         {time_between_blocks; sequencer = Constant.bootstrap1; devmode = true})

type contract = {label : string; abi : string; bin : string}

let deploy ~contract ~sender full_evm_setup =
  let {client; sc_rollup_node; evm_node; _} = full_evm_setup in
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let* () = Eth_cli.add_abi ~label:contract.label ~abi:contract.abi () in
  let send_deploy () =
    Eth_cli.deploy
      ~source_private_key:sender.Eth_account.private_key
      ~endpoint:evm_node_endpoint
      ~abi:contract.label
      ~bin:contract.bin
  in
  Helpers.wait_for_application ~evm_node ~sc_rollup_node ~client send_deploy

type deploy_checks = {
  contract : contract;
  expected_address : string;
  expected_code : string;
}

let deploy_with_base_checks {contract; expected_address; expected_code}
    full_evm_setup =
  let {sc_rollup_node; evm_node; _} = full_evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* contract_address, tx = deploy ~contract ~sender full_evm_setup in
  let address = String.lowercase_ascii contract_address in
  Check.(
    (address = expected_address)
      string
      ~error_msg:"Expected address to be %R but was %L.") ;
  let* code_in_kernel =
    Evm_node.fetch_contract_code evm_node contract_address
  in
  Check.((code_in_kernel = expected_code) string)
    ~error_msg:"Unexpected code %L, it should be %R" ;
  (* The transaction was a contract creation, the transaction object
     must not contain the [to] field. *)
  let* tx_object = Eth_cli.transaction_get ~endpoint ~tx_hash:tx in
  (match tx_object with
  | Some tx_object ->
      Check.((tx_object.to_ = None) (option string))
        ~error_msg:
          "The transaction object of a contract creation should not have the \
           [to] field present"
  | None -> Test.fail "The transaction object of %s should be available" tx) ;
  let* accounts =
    Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:Durable_storage_path.eth_accounts
         ()
  in
  (* check tx status*)
  let* () = check_tx_succeeded ~endpoint ~tx in
  (* check contract account was created *)
  Check.(
    list_mem
      string
      (Durable_storage_path.normalize contract_address)
      (List.map String.lowercase_ascii accounts)
      ~error_msg:"Expected %L account to be initialized by contract creation.") ;
  unit

let send ~sender ~receiver ~value ?data full_evm_setup =
  let {client; sc_rollup_node; evm_node; _} = full_evm_setup in
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let send =
    Eth_cli.transaction_send
      ~source_private_key:sender.Eth_account.private_key
      ~to_public_key:receiver.Eth_account.address
      ~value
      ~endpoint:evm_node_endpoint
      ?data
  in
  wait_for_application ~evm_node ~sc_rollup_node ~client send

let check_block_progression ~evm_node ~sc_rollup_node ~client ~endpoint
    ~expected_block_level =
  let* _level = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let* block_number = Eth_cli.block_number ~endpoint in
  return
  @@ Check.((block_number = expected_block_level) int)
       ~error_msg:"Unexpected block number, should be %%R, but got %%L"

let test_evm_node_connection =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"]
    ~uses:(fun _protocol -> Constant.[octez_smart_rollup_node; octez_evm_node])
    ~title:"EVM node server connection"
  @@ fun protocol ->
  let* tezos_node, tezos_client = setup_l1 protocol in
  let* sc_rollup =
    originate_sc_rollup
      ~kind:"wasm_2_0_0"
      ~parameters_ty:"string"
      ~src:Constant.bootstrap1.alias
      tezos_client
  in
  let sc_rollup_node =
    Sc_rollup_node.create
      Observer
      tezos_node
      ~base_dir:(Client.base_dir tezos_client)
      ~default_operator:Constant.bootstrap1.alias
  in
  let evm_node = Evm_node.create (Sc_rollup_node.endpoint sc_rollup_node) in
  (* Tries to start the EVM node server without a listening rollup node. *)
  let process = Evm_node.spawn_run evm_node in
  let* () = Process.check ~expect_failure:true process in
  (* Starts the rollup node. *)
  let* _ = Sc_rollup_node.run sc_rollup_node sc_rollup [] in
  (* Starts the EVM node server and asks its version. *)
  let* () = Evm_node.run evm_node in
  let*? process = evm_node_version evm_node in
  let* () = Process.check process in
  unit

let test_originate_evm_kernel =
  register_both ~tags:["evm"] ~title:"Originate EVM kernel with installer"
  @@ fun ~protocol:_ ~evm_setup:{client; node; sc_rollup_node; _} ->
  (* First run of the installed EVM kernel, it will initialize the directory
     "eth_accounts". *)
  let* () = Client.bake_for_and_wait ~keys:[] client in
  let* first_evm_run_level = Node.get_level node in
  let* level =
    Sc_rollup_node.wait_for_level
      ~timeout:30.
      sc_rollup_node
      first_evm_run_level
  in
  Check.(level = first_evm_run_level)
    Check.int
    ~error_msg:"Current level has moved past first EVM run (%L = %R)" ;
  let evm_key = "evm" in
  let* storage_root_keys =
    Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:""
         ()
  in
  Check.(
    list_mem
      string
      evm_key
      storage_root_keys
      ~error_msg:"Expected %L to be initialized by the EVM kernel.") ;
  unit

let test_rpc_getBalance =
  register_both
    ~tags:["evm"; "rpc"; "get_balance"]
    ~title:"RPC method eth_getBalance"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let* balance =
    Eth_cli.balance
      ~account:Eth_account.bootstrap_accounts.(0).address
      ~endpoint:evm_node_endpoint
  in
  Check.((balance = Configuration.default_bootstrap_account_balance) Wei.typ)
    ~error_msg:
      (sf
         "Expected balance of %s should be %%R, but got %%L"
         Eth_account.bootstrap_accounts.(0).address) ;
  unit

let test_rpc_getBlockByNumber =
  register_both
    ~tags:["evm"; "rpc"; "get_block_by_number"]
    ~title:"RPC method eth_getBlockByNumber"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let* block = Eth_cli.get_block ~block_id:"0" ~endpoint:evm_node_endpoint in
  Check.((block.number = 0l) int32)
    ~error_msg:"Unexpected block number, should be %%R, but got %%L" ;
  unit

let get_block_by_hash ?(full_tx_objects = false) evm_setup block_hash =
  let* block =
    Evm_node.(
      call_evm_rpc
        evm_setup.evm_node
        {
          method_ = "eth_getBlockByHash";
          parameters = `A [`String block_hash; `Bool full_tx_objects];
        })
  in
  return @@ (block |> Evm_node.extract_result |> Block.of_json)

let test_rpc_getBlockByHash =
  register_both
    ~tags:["evm"; "rpc"; "get_block_by_hash"]
    ~title:"RPC method eth_getBlockByHash"
  @@ fun ~protocol:_ ~evm_setup ->
  let evm_node_endpoint = Evm_node.endpoint evm_setup.evm_node in
  let* block = Eth_cli.get_block ~block_id:"0" ~endpoint:evm_node_endpoint in
  Check.((block.number = 0l) int32)
    ~error_msg:"Unexpected block number, should be %%R, but got %%L" ;
  let* block' = get_block_by_hash evm_setup block.hash in
  assert (block = block') ;
  unit

let test_l2_block_size_non_zero =
  register_both
    ~tags:["evm"; "block"; "size"]
    ~title:"Block size is greater than zero"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let* block = Eth_cli.get_block ~block_id:"0" ~endpoint:evm_node_endpoint in
  Check.((block.size > 0l) int32)
    ~error_msg:"Unexpected block size, should be > 0, but got %%L" ;
  unit

let test_rpc_getTransactionCount =
  register_both
    ~tags:["evm"; "rpc"; "get_transaction_count"]
    ~title:"RPC method eth_getTransactionCount"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let*@ transaction_count =
    Rpc.get_transaction_count
      evm_node
      ~address:Eth_account.bootstrap_accounts.(0).address
  in
  Check.((transaction_count = 0L) int64)
    ~error_msg:"Expected a nonce of %R, but got %L" ;
  unit

let test_rpc_blockNumber =
  register_both
    ~tags:["evm"; "rpc"; "block_number"]
    ~title:"RPC method eth_blockNumber"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  let* () =
    repeat 2 (fun () -> next_evm_level ~evm_node ~sc_rollup_node ~client)
  in
  let*@ block_number = Rpc.block_number evm_node in
  Check.((block_number = 2l) int32)
    ~error_msg:"Expected a block number of %R, but got %L" ;
  unit

let test_rpc_net_version =
  register_both
    ~tags:["evm"; "rpc"; "net_version"]
    ~title:"RPC method net_version"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let*@ net_version = Rpc.net_version evm_node in
  Check.((net_version = "1337") string)
    ~error_msg:"Expected net_version is %R, but got %L" ;
  unit

let test_rpc_getTransactionCountBatch =
  register_both
    ~tags:["evm"; "rpc"; "get_transaction_count_as_batch"]
    ~title:"RPC method eth_getTransactionCount in batch"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let*@ transaction_count =
    Rpc.get_transaction_count
      evm_node
      ~address:Eth_account.bootstrap_accounts.(0).address
  in
  let* transaction_count_batch =
    let* transaction_count =
      Evm_node.batch_evm_rpc
        evm_node
        [
          Rpc.Request.eth_getTransactionCount
            ~address:Eth_account.bootstrap_accounts.(0).address
            ~block:"latest";
        ]
    in
    match JSON.as_list transaction_count with
    | [transaction_count] ->
        return JSON.(transaction_count |-> "result" |> as_int64)
    | _ -> Test.fail "Unexpected result from batching one request"
  in
  Check.((transaction_count = transaction_count_batch) int64)
    ~error_msg:"Nonce from a single request is %L, but got %R from batching it" ;
  unit

let test_rpc_batch =
  register_both ~tags:["evm"; "rpc"; "batch"] ~title:"RPC batch requests"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let* transaction_count, chain_id =
    let transaction_count =
      Rpc.Request.eth_getTransactionCount
        ~address:Eth_account.bootstrap_accounts.(0).address
        ~block:"latest"
    in
    let chain_id = Evm_node.{method_ = "eth_chainId"; parameters = `Null} in
    let* results =
      Evm_node.batch_evm_rpc evm_node [transaction_count; chain_id]
    in
    match JSON.as_list results with
    | [transaction_count; chain_id] ->
        return
          ( JSON.(transaction_count |-> "result" |> as_int64),
            JSON.(chain_id |-> "result" |> as_int64) )
    | _ -> Test.fail "Unexpected result from batching two requests"
  in
  Check.((transaction_count = 0L) int64)
    ~error_msg:"Expected a nonce of %R, but got %L" ;
  (* Default chain id for Ethereum custom networks, not chosen randomly. *)
  let default_chain_id = 1337L in
  Check.((chain_id = default_chain_id) int64)
    ~error_msg:"Expected a chain_id of %R, but got %L" ;
  unit

let test_l2_blocks_progression =
  register_proxy
    ~tags:["evm"; "l2_blocks_progression"]
    ~title:"Check L2 blocks progression"
  @@ fun ~protocol:_ ~evm_setup:{client; sc_rollup_node; endpoint; evm_node; _}
    ->
  let* () =
    check_block_progression
      ~evm_node
      ~sc_rollup_node
      ~client
      ~endpoint
      ~expected_block_level:1
  in
  let* () =
    check_block_progression
      ~evm_node
      ~sc_rollup_node
      ~client
      ~endpoint
      ~expected_block_level:2
  in
  unit

let test_consistent_block_hashes =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "l2_blocks"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Check L2 blocks consistency of hashes"
  @@ fun protocol ->
  let* {client; sc_rollup_node; endpoint; evm_node; _} =
    setup_evm_kernel ~admin:None protocol
  in
  let new_block () =
    let* _level = next_evm_level ~evm_node ~sc_rollup_node ~client in
    let* number = Eth_cli.block_number ~endpoint in
    Eth_cli.get_block ~block_id:(string_of_int number) ~endpoint
  in

  let* block0 = Eth_cli.get_block ~block_id:(string_of_int 0) ~endpoint in
  let* block1 = new_block () in
  let* block2 = new_block () in
  let* block3 = new_block () in
  let* block4 = new_block () in

  let check_parent_hash parent block =
    Check.((block.Block.parent = parent.Block.hash) string)
      ~error_msg:"Unexpected parent hash, should be %%R, but got %%L"
  in

  (* Check consistency accross blocks. *)
  check_parent_hash block0 block1 ;
  check_parent_hash block1 block2 ;
  check_parent_hash block2 block3 ;
  check_parent_hash block3 block4 ;

  let block_hashes, parent_hashes =
    List.map
      (fun Block.{hash; parent; _} -> (hash, parent))
      [block0; block1; block2; block3; block4]
    |> List.split
  in
  let block_hashes_uniq = List.sort_uniq compare block_hashes in
  let parent_hashes_uniq = List.sort_uniq compare parent_hashes in

  (* Check unicity of hashes and parent hashes. *)
  Check.(List.(length block_hashes = length block_hashes_uniq) int)
    ~error_msg:"The list of block hashes must be unique" ;
  Check.(List.(length parent_hashes = length parent_hashes_uniq) int)
    ~error_msg:"The list of block parent hashes must be unique" ;

  unit

(** The info for the "storage.sol" contract.
    See [etherlink/tezt/tests/evm_kernel_inputs/storage.*] *)
let simple_storage =
  {
    label = "simpleStorage";
    abi = kernel_inputs_path ^ "/storage.abi";
    bin = kernel_inputs_path ^ "/storage.bin";
  }

(** The info for the "erc20tok.sol" contract.
    See [etherlink/tezt/tests/evm_kernel_inputs/erc20tok.*] *)
let erc20 =
  {
    label = "erc20tok";
    abi = kernel_inputs_path ^ "/erc20tok.abi";
    bin = kernel_inputs_path ^ "/erc20tok.bin";
  }

(** The info for the "loop.sol" contract.
    See [etherlink/tezt/tests/evm_kernel_inputs/loop.*] *)
let loop =
  {
    label = "loop";
    abi = kernel_inputs_path ^ "/loop.abi";
    bin = kernel_inputs_path ^ "/loop.bin";
  }

(** The info for the "mapping_storage.sol" contract.
    See [etherlink/tezt/tests/evm_kernel_inputs/mapping_storage*] *)
let mapping_storage =
  {
    label = "mappingStorage";
    abi = kernel_inputs_path ^ "/mapping_storage_abi.json";
    bin = kernel_inputs_path ^ "/mapping_storage.bin";
  }

(** The info for the "storage.sol" contract, compiled for Shanghai.
    See [etherlink/tezt/tests/evm_kernel_inputs/shanghai_storage.*] *)
let shanghai_storage =
  {
    label = "shanghai";
    abi = kernel_inputs_path ^ "/shanghai_storage.abi";
    bin = kernel_inputs_path ^ "/shanghai_storage.bin";
  }

(** The info for the Callee contract.
    See [src\kernel_evm\solidity_examples\caller_callee.sol] *)
let callee =
  {
    label = "callee";
    abi = kernel_inputs_path ^ "/callee.abi";
    bin = kernel_inputs_path ^ "/callee.bin";
  }

(** The info for the Caller contract.
    See [src\kernel_evm\solidity_examples\caller_callee.sol] *)
let caller =
  {
    label = "caller";
    abi = kernel_inputs_path ^ "/caller.abi";
    bin = kernel_inputs_path ^ "/caller.bin";
  }

(** The info for the "events.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/events.sol] *)
let events =
  {
    label = "events";
    abi = kernel_inputs_path ^ "/events.abi";
    bin = kernel_inputs_path ^ "/events.bin";
  }

(** The info for the "nested_create.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/nested_create.sol] *)
let nested_create =
  {
    label = "nested_create";
    abi = kernel_inputs_path ^ "/nested_create.abi";
    bin = kernel_inputs_path ^ "/nested_create.bin";
  }

(** The info for the "revert.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/revert.sol] *)
let revert =
  {
    label = "revert";
    abi = kernel_inputs_path ^ "/revert.abi";
    bin = kernel_inputs_path ^ "/revert.bin";
  }

(** The info for the "create2.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/create2.sol] *)
let create2 =
  {
    label = "create2";
    abi = kernel_inputs_path ^ "/create2.abi";
    bin = kernel_inputs_path ^ "/create2.bin";
  }

(** The info for the "oog_call.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/oog_call.sol] *)
let oog_call =
  {
    label = "oog_call";
    abi = kernel_inputs_path ^ "/oog_call.abi";
    bin = kernel_inputs_path ^ "/oog_call.bin";
  }

(** The info for the "ether_wallet.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/ether_wallet.sol] *)
let ether_wallet =
  {
    label = "ether_wallet";
    abi = kernel_inputs_path ^ "/ether_wallet.abi";
    bin = kernel_inputs_path ^ "/ether_wallet.bin";
  }

(** The info for the "block_hash_gen.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/block_hash_gen.sol] *)
let block_hash_gen =
  {
    label = "block_hash_gen";
    abi = kernel_inputs_path ^ "/block_hash_gen.abi";
    bin = kernel_inputs_path ^ "/block_hash_gen.bin";
  }

(** The info for the "block_hash_gen.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/blockhash.sol] *)
let blockhash =
  {
    label = "blockhash";
    abi = kernel_inputs_path ^ "/blockhash.abi";
    bin = kernel_inputs_path ^ "/blockhash.bin";
  }

(** The info for the "timestamp.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/timestamp.sol] *)
let timestamp =
  {
    label = "timestamp";
    abi = kernel_inputs_path ^ "/timestamp.abi";
    bin = kernel_inputs_path ^ "/timestamp.bin";
  }

(** The info for the "call_selfdestruct.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/call_selfdestruct.sol] *)
let call_selfdestruct =
  {
    label = "call_selfdestruct";
    abi = kernel_inputs_path ^ "/call_selfdestruct.abi";
    bin = kernel_inputs_path ^ "/call_selfdestruct.bin";
  }

(** The info for the "recursive.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/recursive.sol] *)
let recursive =
  {
    label = "recursive";
    abi = kernel_inputs_path ^ "/recursive.abi";
    bin = kernel_inputs_path ^ "/recursive.bin";
  }

(** The info for the "error.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/error.sol] *)
let error =
  {
    label = "error";
    abi = kernel_inputs_path ^ "/error.abi";
    bin = kernel_inputs_path ^ "/error.bin";
  }

(** The info for the "block_hash_gen.sol" contract.
    See [etherlink/kernel_evm/solidity_examples/spam_withdrawal.sol] *)
let spam_withdrawal =
  {
    label = "spam_withdrawal";
    abi = kernel_inputs_path ^ "/spam_withdrawal.abi";
    bin = kernel_inputs_path ^ "/spam_withdrawal.bin";
  }

(** Test that the contract creation works.  *)
let test_l2_deploy_simple_storage =
  register_proxy
    ~tags:["evm"; "l2_deploy"]
    ~title:"Check L2 contract deployment"
  @@ fun ~protocol:_ ~evm_setup ->
  deploy_with_base_checks
    {
      contract = simple_storage;
      expected_address = "0xd77420f73b4612a7a99dba8c2afd30a1886b0344";
      (* The same deployment has been reproduced on the Sepolia testnet, resulting
         on this specific code. *)
      expected_code =
        "0x608060405234801561001057600080fd5b50600436106100415760003560e01c80634e70b1dc1461004657806360fe47b1146100645780636d4ce63c14610080575b600080fd5b61004e61009e565b60405161005b91906100d0565b60405180910390f35b61007e6004803603810190610079919061011c565b6100a4565b005b6100886100ae565b60405161009591906100d0565b60405180910390f35b60005481565b8060008190555050565b60008054905090565b6000819050919050565b6100ca816100b7565b82525050565b60006020820190506100e560008301846100c1565b92915050565b600080fd5b6100f9816100b7565b811461010457600080fd5b50565b600081359050610116816100f0565b92915050565b600060208284031215610132576101316100eb565b5b600061014084828501610107565b9150509291505056fea2646970667358221220ec57e49a647342208a1f5c9b1f2049bf1a27f02e19940819f38929bf67670a5964736f6c63430008120033";
    }
    evm_setup

let send_call_set_storage_simple contract_address sender n
    {sc_rollup_node; client; endpoint; evm_node; _} =
  let call_set (sender : Eth_account.t) n =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:simple_storage.label
      ~address:contract_address
      ~method_call:(Printf.sprintf "set(%d)" n)
  in
  wait_for_application ~evm_node ~sc_rollup_node ~client (call_set sender n)

(** Test that a contract can be called,
    and that the call can modify the storage.  *)
let test_l2_call_simple_storage =
  register_proxy
    ~tags:["evm"; "l2_deploy"; "l2_call"]
    ~title:"Check L2 contract call"
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in

  (* deploy contract *)
  let* address, _tx = deploy ~contract:simple_storage ~sender evm_setup in

  (* set 42 *)
  let* tx = send_call_set_storage_simple address sender 42 evm_setup in

  let* () = check_tx_succeeded ~endpoint ~tx in
  let* () = check_storage_size sc_rollup_node ~address 1 in
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:42 in

  (* set 24 by another user *)
  let* tx =
    send_call_set_storage_simple
      address
      Eth_account.bootstrap_accounts.(1)
      24
      evm_setup
  in

  let* () = check_tx_succeeded ~endpoint ~tx in
  let* () = check_storage_size sc_rollup_node ~address 1 in
  (* value stored has changed *)
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:24 in

  (* set -1 *)
  (* some environments prevent sending a negative value, as the value is
     unsigned (eg remix) but it is actually the expected result *)
  let* tx = send_call_set_storage_simple address sender (-1) evm_setup in

  let* () = check_tx_succeeded ~endpoint ~tx in
  let* () = check_storage_size sc_rollup_node ~address 1 in
  (* value stored has changed *)
  let* () =
    check_str_in_storage
      ~evm_setup
      ~address
      ~nth:0
      ~expected:
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  in
  unit

let test_l2_deploy_erc20 =
  register_proxy
    ~tags:["evm"; "l2_deploy"; "erc20"; "l2_call"]
    ~title:"Check L2 erc20 contract deployment"
  @@ fun ~protocol:_ ~evm_setup ->
  (* setup *)
  let {evm_node; client; sc_rollup_node; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let player = Eth_account.bootstrap_accounts.(1) in

  (* deploy the contract *)
  let* address, tx = deploy ~contract:erc20 ~sender evm_setup in
  Check.(
    (String.lowercase_ascii address
    = "0xd77420f73b4612a7a99dba8c2afd30a1886b0344")
      string
      ~error_msg:"Expected address to be %R but was %L.") ;

  (* check tx status *)
  let* () = check_tx_succeeded ~endpoint ~tx in

  (* check account was created *)
  let* accounts =
    Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:Durable_storage_path.eth_accounts
         ()
  in
  Check.(
    list_mem
      string
      (Durable_storage_path.normalize address)
      (List.map String.lowercase_ascii accounts)
      ~error_msg:"Expected %L account to be initialized by contract creation.") ;

  (* minting / burning *)
  let call_mint (sender : Eth_account.t) n =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:erc20.label
      ~address
      ~method_call:(Printf.sprintf "mint(%d)" n)
  in
  let call_burn ?(expect_failure = false) (sender : Eth_account.t) n =
    Eth_cli.contract_send
      ~expect_failure
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:erc20.label
      ~address
      ~method_call:(Printf.sprintf "burn(%d)" n)
  in
  let transfer_event_topic =
    let h =
      Tezos_crypto.Hacl.Hash.Keccak_256.digest
        (Bytes.of_string "Transfer(address,address,uint256)")
    in
    "0x" ^ Hex.show (Hex.of_bytes h)
  in
  let zero_address = "0x" ^ String.make 64 '0' in
  let mint_logs sender amount =
    [
      ( address,
        [transfer_event_topic; zero_address; hex_256_of_address sender],
        "0x" ^ hex_256_of amount );
    ]
  in
  let burn_logs sender amount =
    [
      ( address,
        [transfer_event_topic; hex_256_of_address sender; zero_address],
        "0x" ^ hex_256_of amount );
    ]
  in
  (* sender mints 42 *)
  let* tx =
    wait_for_application ~evm_node ~sc_rollup_node ~client (call_mint sender 42)
  in
  let* () =
    check_status_n_logs ~endpoint ~status:true ~logs:(mint_logs sender 42) ~tx
  in

  (* totalSupply is the first value in storage *)
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:42 in

  (* player mints 100 *)
  let* tx =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_mint player 100)
  in
  let* () =
    check_status_n_logs ~endpoint ~status:true ~logs:(mint_logs player 100) ~tx
  in
  (* totalSupply is the first value in storage *)
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:142 in

  (* sender tries to burn 100, should fail *)
  let* _tx =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_burn ~expect_failure:true sender 100)
  in
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:142 in

  (* sender tries to burn 42, should succeed *)
  let* tx =
    wait_for_application ~evm_node ~sc_rollup_node ~client (call_burn sender 42)
  in
  let* () =
    check_status_n_logs ~endpoint ~status:true ~logs:(burn_logs sender 42) ~tx
  in
  let* () = check_nb_in_storage ~evm_setup ~address ~nth:0 ~expected:100 in
  unit

let test_deploy_contract_for_shanghai =
  register_proxy
    ~tags:["evm"; "deploy"; "shanghai"]
    ~title:
      "Check that a contract containing PUSH0 can successfully be deployed."
  @@ fun ~protocol:_ ~evm_setup ->
  deploy_with_base_checks
    {
      contract = shanghai_storage;
      expected_address = "0xd77420f73b4612a7a99dba8c2afd30a1886b0344";
      expected_code =
        "0x608060405234801561000f575f80fd5b5060043610610034575f3560e01c80632e64cec1146100385780636057361d14610056575b5f80fd5b610040610072565b60405161004d919061009b565b60405180910390f35b610070600480360381019061006b91906100e2565b61007a565b005b5f8054905090565b805f8190555050565b5f819050919050565b61009581610083565b82525050565b5f6020820190506100ae5f83018461008c565b92915050565b5f80fd5b6100c181610083565b81146100cb575f80fd5b50565b5f813590506100dc816100b8565b92915050565b5f602082840312156100f7576100f66100b4565b5b5f610104848285016100ce565b9150509291505056fea2646970667358221220c1aa96a14de9ab1c36fb97f3051eac7ba11ec6ac604ddeab90e5b6ac8bd4efc064736f6c63430008140033";
    }
    evm_setup

let check_log_indices ~endpoint ~status ~tx indices =
  let* receipt = Eth_cli.get_receipt ~endpoint ~tx in
  match receipt with
  | None ->
      failwith "no transaction receipt, probably it hasn't been mined yet."
  | Some r ->
      Check.(
        (r.status = status)
          bool
          ~__LOC__
          ~error_msg:"Unexpected transaction status, expected: %R but got: %L") ;
      let received_indices =
        List.map (fun tx -> tx.Transaction.logIndex) r.logs
      in
      Check.(
        (received_indices = indices)
          (list int32)
          ~__LOC__
          ~error_msg:
            "Unexpected transaction logs indices, expected:\n%R but got:\n%L") ;
      unit

let test_log_index =
  register_both
    ~tags:["evm"; "log_index"]
    ~title:"Check that log index is correctly computed"
  @@ fun ~protocol:_ ~evm_setup ->
  (* setup *)
  let {evm_node; client; sc_rollup_node; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let _player = Eth_account.bootstrap_accounts.(1) in
  (* deploy the events contract *)
  let* _address, _tx = deploy ~contract:events ~sender evm_setup in
  (* Emits two events: EventA and EventB *)
  let raw_emitBoth =
    "0xf88901843b9aca00826bf694d77420f73b4612a7a99dba8c2afd30a1886b034480a4cc79cf9d0000000000000000000000000000000000000000000000000000000000000064820a96a01350f66edc1a5bfa7dc8651d5735dbb343c491939a9e49b3f1a041b6a234df72a0028c5523a2bcc1077e090360a0e96ffaff7a2f26fd161b87107252e4bb83c47b"
  in
  (* Emits one event: EventA *)
  let raw_emitA =
    "0xf88980843b9aca0082644094d77420f73b4612a7a99dba8c2afd30a1886b034480a413c49adf000000000000000000000000000000000000000000000000000000000000000a820a95a0a46df17e7392d9777a94248e2dd6d9a0a097143cf915152d531c07fa604d2219a053c59f5e070adef0e2c443e5f7afb6435dfed20e04ddcfcfccb150972535cd2d"
  in
  let* _requests, _receipt, hashes =
    send_n_transactions
      ~sc_rollup_node
      ~client
      ~evm_node
      [raw_emitBoth; raw_emitA]
  in
  let* () =
    check_log_indices ~endpoint ~status:true ~tx:(List.hd hashes) [0l; 1l]
  in
  check_log_indices ~endpoint ~status:true ~tx:(List.nth hashes 1) [2l]

(* TODO: add internal parameters here (e.g the kernel version) *)
type config_result = {chain_id : int64}

let config_setup evm_setup =
  let web3_clientVersion =
    Evm_node.{method_ = "web3_clientVersion"; parameters = `A []}
  in
  let chain_id = Evm_node.{method_ = "eth_chainId"; parameters = `Null} in
  let* results =
    Evm_node.batch_evm_rpc evm_setup.evm_node [web3_clientVersion; chain_id]
  in
  match JSON.as_list results with
  | [web3_clientVersion; chain_id] ->
      (* We don't need to return the web3_clientVersion because,
         it might change after the upgrade.
         The only thing that we need to look out for is,
         are we able to retrieve it and deserialize it. *)
      let _sanity_check = JSON.(web3_clientVersion |-> "result" |> as_string) in
      return {chain_id = JSON.(chain_id |-> "result" |> as_int64)}
  | _ -> Test.fail "Unexpected result from batching two requests"

let ensure_config_setup_integrity ~config_result evm_setup =
  let* upcoming_config_setup = config_setup evm_setup in
  assert (config_result = upcoming_config_setup) ;
  unit

let ensure_block_integrity ~block_result evm_setup =
  let* block =
    Eth_cli.get_block
      ~block_id:(Int32.to_string block_result.Block.number)
      ~endpoint:evm_setup.endpoint
  in
  (* only the relevant fields *)
  assert (block.number = block_result.number) ;
  assert (block.hash = block_result.hash) ;
  assert (block.timestamp = block_result.timestamp) ;
  assert (block.transactions = block_result.transactions) ;
  unit

let latest_block ?(full_tx_objects = false) evm_node =
  Rpc.get_block_by_number ~full_tx_objects ~block:"latest" evm_node

type transfer_result = {
  sender_balance_before : Wei.t;
  sender_balance_after : Wei.t;
  sender_nonce_before : int64;
  sender_nonce_after : int64;
  value : Wei.t;
  tx_hash : string;
  tx_object : Transaction.transaction_object;
  tx_receipt : Transaction.transaction_receipt;
  receiver_balance_before : Wei.t;
  receiver_balance_after : Wei.t;
}

let get_tx_object ~endpoint ~tx_hash =
  let* tx_object = Eth_cli.transaction_get ~endpoint ~tx_hash in
  match tx_object with
  | Some tx_object -> return tx_object
  | None -> Test.fail "The transaction object of %s should be available" tx_hash

let ensure_transfer_result_integrity ~transfer_result ~sender ~receiver
    full_evm_setup =
  let endpoint = Evm_node.endpoint full_evm_setup.evm_node in
  let balance account = Eth_cli.balance ~account ~endpoint in
  let* sender_balance = balance sender.Eth_account.address in
  assert (sender_balance = transfer_result.sender_balance_after) ;
  let* receiver_balance = balance receiver.Eth_account.address in
  assert (receiver_balance = transfer_result.receiver_balance_after) ;
  let*@ sender_nonce =
    Rpc.get_transaction_count full_evm_setup.evm_node ~address:sender.address
  in
  assert (sender_nonce = transfer_result.sender_nonce_after) ;
  let* tx_object = get_tx_object ~endpoint ~tx_hash:transfer_result.tx_hash in
  assert (tx_object = transfer_result.tx_object) ;
  let*@! tx_receipt =
    Rpc.get_transaction_receipt
      ~tx_hash:transfer_result.tx_hash
      full_evm_setup.evm_node
  in
  assert (tx_receipt = transfer_result.tx_receipt) ;
  unit

let make_transfer ?data ~value ~sender ~receiver full_evm_setup =
  let endpoint = Evm_node.endpoint full_evm_setup.evm_node in
  let balance account = Eth_cli.balance ~account ~endpoint in
  let* sender_balance_before = balance sender.Eth_account.address in
  let* receiver_balance_before = balance receiver.Eth_account.address in
  let*@ sender_nonce_before =
    Rpc.get_transaction_count full_evm_setup.evm_node ~address:sender.address
  in
  let* tx_hash = send ~sender ~receiver ~value ?data full_evm_setup in
  let* () = check_tx_succeeded ~endpoint ~tx:tx_hash in
  let* sender_balance_after = balance sender.address in
  let* receiver_balance_after = balance receiver.address in
  let*@ sender_nonce_after =
    Rpc.get_transaction_count full_evm_setup.evm_node ~address:sender.address
  in
  let* tx_object = get_tx_object ~endpoint ~tx_hash in
  let*@! tx_receipt =
    Rpc.get_transaction_receipt ~tx_hash full_evm_setup.evm_node
  in
  return
    {
      sender_balance_before;
      sender_balance_after;
      sender_nonce_before;
      sender_nonce_after;
      value;
      tx_hash;
      tx_object;
      tx_receipt;
      receiver_balance_before;
      receiver_balance_after;
    }

let transfer ?data ~da_fee_per_byte ~expected_execution_gas ~evm_setup () =
  let* base_fee_per_gas = Rpc.get_gas_price evm_setup.evm_node in
  let sender, receiver =
    (Eth_account.bootstrap_accounts.(0), Eth_account.bootstrap_accounts.(1))
  in
  let* {
         sender_balance_before;
         sender_balance_after;
         sender_nonce_before;
         sender_nonce_after;
         value;
         tx_object;
         receiver_balance_before;
         receiver_balance_after;
         _;
       } =
    make_transfer
      ?data
      ~value:Wei.(Configuration.default_bootstrap_account_balance - one_eth)
      ~sender
      ~receiver
      evm_setup
  in
  let* receipt =
    Eth_cli.get_receipt ~endpoint:evm_setup.endpoint ~tx:tx_object.hash
  in
  let gas_used, gas_price =
    match receipt with
    | Some Transaction.{status = true; gasUsed; effectiveGasPrice; _} ->
        (gasUsed, effectiveGasPrice)
    | _ -> Test.fail "Transaction didn't succeed"
  in
  let fees = expected_gas_fees ~gas_price ~gas_used in
  Check.(
    Wei.(sender_balance_after = sender_balance_before - value - fees) Wei.typ)
    ~error_msg:
      "Unexpected sender balance after transfer, should be %R, but got %L" ;
  Check.(Wei.(receiver_balance_after = receiver_balance_before + value) Wei.typ)
    ~error_msg:
      "Unexpected receiver balance after transfer, should be %R, but got %L" ;
  Check.((sender_nonce_after = Int64.succ sender_nonce_before) int64)
    ~error_msg:
      "Unexpected sender nonce after transfer, should be %R, but got %L" ;
  (* Perform some sanity checks on the transaction object produced by the
     kernel. *)
  Check.((tx_object.from = sender.address) string)
    ~error_msg:"Unexpected transaction's sender" ;
  Check.((tx_object.to_ = Some receiver.address) (option string))
    ~error_msg:"Unexpected transaction's receiver" ;
  Check.((tx_object.value = value) Wei.typ)
    ~error_msg:"Unexpected transaction's value" ;
  let data = Option.value ~default:"0x" data in
  let data = String.sub data 2 (String.length data - 2) in
  let data_size = Bytes.length @@ Hex.to_bytes @@ `Hex data in
  check_tx_gas_for_fee
    ~da_fee_per_byte
    ~expected_execution_gas
    ~gas_used
    ~gas_price
    ~base_fee_per_gas
    ~data_size ;
  unit

let test_l2_transfer =
  let da_fee_per_byte = Wei.of_eth_string "0.000002" in
  let expected_execution_gas = 21000 in
  let test_f ~protocol:_ ~evm_setup =
    transfer ~evm_setup ~da_fee_per_byte ~expected_execution_gas ()
  in
  let title = "Check L2 transfers are applied" in
  let tags = ["evm"; "l2_transfer"] in
  register_both ~title ~tags ~da_fee_per_byte test_f

let test_chunked_transaction =
  let da_fee_per_byte = Wei.of_eth_string "0.000002" in
  let expected_execution_gas = 117000 in
  let test_f ~protocol:_ ~evm_setup =
    transfer
      ~data:("0x" ^ String.make 12_000 'a')
      ~da_fee_per_byte
      ~evm_setup
      ~expected_execution_gas
      ()
  in
  let title = "Check L2 chunked transfers are applied" in
  let tags = ["evm"; "l2_transfer"; "chunked"] in
  register_both ~title ~tags ~da_fee_per_byte test_f

let test_rpc_txpool_content =
  register_both
    ~tags:["evm"; "rpc"; "txpool_content"]
    ~title:"Check RPC txpool_content is available"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  (* The content of the txpool is not relevant for now, this test only checks
     the the RPC is correct, i.e. an object containing both the `pending` and
     `queued` fields, containing the correct objects: addresses pointing to a
     mapping of nonces to transactions. *)
  let* _result = Evm_node.txpool_content evm_node in
  unit

let test_rpc_web3_clientVersion =
  register_both
    ~tags:["evm"; "rpc"; "client_version"]
    ~title:"Check RPC web3_clientVersion"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let* web3_clientVersion =
    Evm_node.(
      call_evm_rpc evm_node {method_ = "web3_clientVersion"; parameters = `A []})
  in
  let* server_version = evm_node_version evm_node |> Runnable.run in
  Check.(
    (JSON.(web3_clientVersion |-> "result" |> as_string)
    = JSON.as_string server_version)
      string)
    ~error_msg:"Expected version %%R, got %%L." ;
  unit

let test_rpc_web3_sha3 =
  register_both ~tags:["evm"; "rpc"; "sha3"] ~title:"Check RPC web3_sha3"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  (* From the example provided in
     https://ethereum.org/en/developers/docs/apis/json-rpc/#web3_sha3 *)
  let input_data = "0x68656c6c6f20776f726c64" in
  let expected_reply =
    "0x47173285a8d7341e5e972fc677286384f802f8ef42a5ec5f03bbfa254cb01fad"
  in
  let* web3_sha3 =
    Evm_node.(
      call_evm_rpc
        evm_node
        {method_ = "web3_sha3"; parameters = `A [`String input_data]})
  in
  Check.((JSON.(web3_sha3 |-> "result" |> as_string) = expected_reply) string)
    ~error_msg:"Expected hash %%R, got %%L." ;
  unit

let test_simulate =
  register_proxy
    ~tags:["evm"; "simulate"]
    ~title:"A block can be simulated in the rollup node"
    (fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; _} ->
      let*@ block_number = Rpc.block_number evm_node in
      let* simulation_result =
        Sc_rollup_node.RPC.call sc_rollup_node
        @@ Sc_rollup_rpc.post_global_block_simulate
             ~insight_requests:
               [
                 `Durable_storage_key
                   ["evm"; "world_state"; "blocks"; "current"; "number"];
               ]
             []
      in
      let simulated_block_number =
        match simulation_result.insights with
        | [insight] -> Option.map Helpers.hex_string_to_int insight
        | _ -> None
      in
      Check.(
        (simulated_block_number = Some (Int32.to_int block_number + 1))
          (option int))
        ~error_msg:"The simulation should advance one L2 block" ;
      unit)

let test_full_blocks =
  register_proxy
    ~config:(`Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml"))
    ~tags:["evm"; "full_blocks"]
    ~title:
      "Check `eth_getBlockByNumber` with full blocks returns the correct \
       informations"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  let txs =
    read_tx_from_file ()
    |> List.filteri (fun i _ -> i < 5)
    |> List.map (fun (tx, _hash) -> tx)
  in
  let* _requests, receipt, _hashes =
    send_n_transactions ~sc_rollup_node ~client ~evm_node txs
  in
  let* block =
    Evm_node.(
      call_evm_rpc
        evm_node
        {
          method_ = "eth_getBlockByNumber";
          parameters =
            `A [`String (Format.sprintf "%#lx" receipt.blockNumber); `Bool true];
        })
  in
  let block = block |> Evm_node.extract_result |> Block.of_json in
  let block_number = block.number in
  (match block.Block.transactions with
  | Block.Empty -> Test.fail "Expected a non empty block"
  | Block.Full transactions ->
      List.iteri
        (fun index
             ({blockHash; blockNumber; transactionIndex; _} :
               Transaction.transaction_object) ->
          Check.((block.hash = blockHash) string)
            ~error_msg:
              (sf "The transaction should be in block %%L but found %%R") ;
          Check.((block_number = blockNumber) int32)
            ~error_msg:
              (sf "The transaction should be in block %%L but found %%R") ;
          Check.((Int32.of_int index = transactionIndex) int32)
            ~error_msg:
              (sf "The transaction should be at index %%L but found %%R"))
        transactions
  | Block.Hash _ -> Test.fail "Block is supposed to contain transaction objects") ;
  unit

let test_latest_block =
  register_proxy
    ~tags:["evm"; "blocks"; "latest"]
    ~title:
      "Check `eth_getBlockByNumber` works correctly when asking for the \
       `latest`"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  (* The first execution of the kernel actually builds two blocks: the genesis
     block and the block for the current inbox. As such, the latest block is
     always of level 1. *)
  let* latest_block =
    Evm_node.(
      call_evm_rpc
        evm_node
        {
          method_ = "eth_getBlockByNumber";
          parameters = `A [`String "latest"; `Bool false];
        })
  in
  let latest_block = latest_block |> Evm_node.extract_result |> Block.of_json in
  Check.((latest_block.Block.number = 1l) int32)
    ~error_msg:"Expected latest being block number %R, but got %L" ;
  unit

let test_eth_call_nullable_recipient =
  register_both
    ~tags:["evm"; "eth_call"; "null"]
    ~title:"Check `eth_call.to` input can be null"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let* call_result =
    Evm_node.(
      call_evm_rpc
        evm_node
        {
          method_ = "eth_call";
          parameters = `A [`O [("to", `Null)]; `String "latest"];
        })
  in
  (* Check the RPC returns a `result`. *)
  let _result = call_result |> Evm_node.extract_result in
  unit

let test_inject_100_transactions =
  register_proxy
    ~tags:["evm"; "bigger_blocks"]
    ~title:"Check blocks can contain more than 64 transactions"
    ~config:(`Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml"))
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  (* Retrieves all the messages and prepare them for the current rollup. *)
  let txs = read_tx_from_file () |> List.map (fun (tx, _hash) -> tx) in
  let* requests, receipt, _hashes =
    send_n_transactions ~sc_rollup_node ~client ~evm_node txs
  in
  let* block_with_100tx =
    Evm_node.(
      call_evm_rpc
        evm_node
        {
          method_ = "eth_getBlockByNumber";
          parameters =
            `A
              [`String (Format.sprintf "%#lx" receipt.blockNumber); `Bool false];
        })
  in
  let block_with_100tx =
    block_with_100tx |> Evm_node.extract_result |> Block.of_json
  in
  (match block_with_100tx.Block.transactions with
  | Block.Empty -> Test.fail "Expected a non empty block"
  | Block.Full _ ->
      Test.fail "Block is supposed to contain only transaction hashes"
  | Block.Hash hashes ->
      Check.((List.length hashes = List.length requests) int)
        ~error_msg:"Expected %R transactions in the latest block, got %L") ;

  let* _level = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let*@ latest_evm_level = Rpc.block_number evm_node in
  (* At each loop, the kernel reads the previous block. Until the patch, the
     kernel failed to read the previous block if there was more than 64 hash,
     this test ensures it works by assessing new blocks are produced. *)
  Check.((latest_evm_level >= Int32.succ block_with_100tx.Block.number) int32)
    ~error_msg:
      "Expected a new block after the one with 100 transactions, but level \
       hasn't changed" ;
  unit

let check_estimate_gas {evm_node; _} eth_call expected_gas =
  (* Make the call to the EVM node. *)
  let*@ r = Rpc.estimate_gas eth_call evm_node in
  (* Check the RPC result. *)
  Check.((r >= expected_gas) int64)
    ~error_msg:"Expected result greater than %R, but got %L" ;
  unit

let check_eth_call {evm_node; _} eth_call expected_result =
  (* Make the call to the EVM node. *)
  let* call_result =
    Evm_node.(
      call_evm_rpc
        evm_node
        {method_ = "eth_call"; parameters = `A [`O eth_call; `String "latest"]})
  in
  (* Check the RPC result. *)
  let r = call_result |> Evm_node.extract_result in
  Check.((JSON.as_string r = expected_result) string)
    ~error_msg:"Expected result %R, but got %L" ;
  unit

let test_eth_call_large =
  let test_f ~protocol:_ ~evm_setup =
    let sender = Eth_account.bootstrap_accounts.(0) in
    (* large request *)
    let eth_call =
      [
        ("to", Ezjsonm.encode_string sender.address);
        ("data", Ezjsonm.encode_string ("0x" ^ String.make 12_000 'a'));
      ]
    in

    check_eth_call evm_setup eth_call "0x"
  in
  let title = "eth_call with a large amount of data" in
  let tags = ["evm"; "eth_call"; "simulate"; "large"] in
  register_both ~title ~tags test_f

let test_estimate_gas =
  let test_f ~protocol:_ ~evm_setup =
    (* large request *)
    let data = read_file simple_storage.bin in
    let eth_call = [("data", Ezjsonm.encode_string @@ "0x" ^ data)] in

    check_estimate_gas evm_setup eth_call 23423L
  in

  let title = "eth_estimateGas for contract creation" in
  let tags = ["evm"; "eth_estimategas"; "simulate"] in
  register_both ~title ~tags test_f

let test_estimate_gas_additionnal_field =
  let test_f ~protocol:_ ~evm_setup =
    (* large request *)
    let data = read_file simple_storage.bin in
    let eth_call =
      [
        ( "from",
          Ezjsonm.encode_string @@ "0x6ce4d79d4e77402e1ef3417fdda433aa744c6e1c"
        );
        ("data", Ezjsonm.encode_string @@ "0x" ^ data);
        ("value", Ezjsonm.encode_string @@ "0x0");
        (* for some reason remix adds the "type" field *)
        ("type", Ezjsonm.encode_string @@ "0x1");
      ]
    in

    check_estimate_gas evm_setup eth_call 23423L
  in
  let title = "eth_estimateGas allows additional fields" in
  let tags = ["evm"; "eth_estimategas"; "simulate"; "remix"] in
  register_both ~title ~tags test_f

let test_eth_call_storage_contract =
  let test_f ~protocol:_ ~evm_setup:({evm_node; endpoint; _} as evm_setup) =
    let sender = Eth_account.bootstrap_accounts.(0) in

    (* deploy contract *)
    let* address, tx = deploy ~contract:simple_storage ~sender evm_setup in
    let* () = check_tx_succeeded ~endpoint ~tx in
    Check.(
      (String.lowercase_ascii address
      = "0xd77420f73b4612a7a99dba8c2afd30a1886b0344")
        string
        ~error_msg:"Expected address to be %R but was %L.") ;

    (* craft request *)
    let data = "0x4e70b1dc" in
    let eth_call =
      [
        ("to", Ezjsonm.encode_string address);
        ("data", Ezjsonm.encode_string data);
      ]
    in

    (* make call to proxy *)
    let* call_result =
      Evm_node.(
        call_evm_rpc
          evm_node
          {
            method_ = "eth_call";
            parameters = `A [`O eth_call; `String "latest"];
          })
    in

    let r = call_result |> Evm_node.extract_result in
    Check.(
      (JSON.as_string r
     = "0x0000000000000000000000000000000000000000000000000000000000000000")
        string)
      ~error_msg:"Expected result %R, but got %L" ;

    let* tx = send_call_set_storage_simple address sender 42 evm_setup in
    let* () = check_tx_succeeded ~endpoint ~tx in

    (* make call to proxy *)
    let* call_result =
      Evm_node.(
        call_evm_rpc
          evm_node
          {
            method_ = "eth_call";
            parameters = `A [`O eth_call; `String "latest"];
          })
    in
    let r = call_result |> Evm_node.extract_result in
    Check.(
      (JSON.as_string r
     = "0x000000000000000000000000000000000000000000000000000000000000002a")
        string)
      ~error_msg:"Expected result %R, but got %L" ;
    unit
  in
  let title = "Call a view" in
  let tags = ["evm"; "eth_call"; "simulate"] in
  register_both ~title ~tags test_f

let test_eth_call_storage_contract_eth_cli =
  let test_f ~protocol:_
      ~evm_setup:({evm_node; endpoint; sc_rollup_node; client; _} as evm_setup)
      =
    (* sanity *)
    let* call_result =
      Evm_node.(
        call_evm_rpc
          evm_node
          {
            method_ = "eth_call";
            parameters = `A [`O [("to", `Null)]; `String "latest"];
          })
    in
    (* Check the RPC returns a `result`. *)
    let _result = call_result |> Evm_node.extract_result in

    let sender = Eth_account.bootstrap_accounts.(0) in

    (* deploy contract send send 42 *)
    let* address, _tx = deploy ~contract:simple_storage ~sender evm_setup in
    let* tx = send_call_set_storage_simple address sender 42 evm_setup in
    let* () = check_tx_succeeded ~endpoint ~tx in

    (* make a call to proxy through eth-cli *)
    let call_num =
      Eth_cli.contract_call
        ~endpoint
        ~abi_label:simple_storage.label
        ~address
        ~method_call:"num()"
    in
    let* res =
      wait_for_application ~evm_node ~sc_rollup_node ~client call_num
    in

    Check.((String.trim res = "42") string)
      ~error_msg:"Expected result %R, but got %L" ;
    unit
  in
  let title = "Call a view through an ethereum client" in
  let tags = ["evm"; "eth_call"; "simulate"] in

  register_both ~title ~tags test_f

let test_preinitialized_evm_kernel =
  let administrator_key_path = Durable_storage_path.admin in
  let administrator_key = Eth_account.bootstrap_accounts.(0).address in
  let config =
    `Config
      Sc_rollup_helpers.Installer_kernel_config.
        [
          Set
            {
              value = Hex.(of_string administrator_key |> show);
              to_ = administrator_key_path;
            };
        ]
  in
  register_proxy
    ~tags:["evm"; "administrator"; "config"]
    ~title:"Creates a kernel with an initialized administrator key"
    ~config
  @@ fun ~protocol:_ ~evm_setup:{sc_rollup_node; _} ->
  let* found_administrator_key_hex =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Value
         ~key:administrator_key_path
         ()
  in
  let found_administrator_key =
    Option.map
      (fun administrator -> Hex.to_string (`Hex administrator))
      found_administrator_key_hex
  in
  Check.((Some administrator_key = found_administrator_key) (option string))
    ~error_msg:
      (sf "Expected to read %%L as administrator key, but found %%R instead") ;
  unit

let deposit ~amount_mutez ~bridge ~depositor ~receiver ~evm_node ~sc_rollup_node
    ~sc_rollup_address client =
  let* () =
    Client.transfer
      ~entrypoint:"deposit"
      ~arg:(sf "Pair %S %s" sc_rollup_address receiver)
      ~amount:amount_mutez
      ~giver:depositor.Account.public_key_hash
      ~receiver:bridge
      ~burn_cap:Tez.one
      client
  in
  let* () = Client.bake_for_and_wait ~keys:[] client in

  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  unit

let find_and_execute_withdrawal ~withdrawal_level ~commitment_period
    ~challenge_window ~evm_node ~sc_rollup_node ~sc_rollup_address ~client =
  (* Bake enough levels to have a commitment and cement it. *)
  let* _ =
    repeat
      ((commitment_period * challenge_window) + 3)
      (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in

  (* Construct and execute the outbox proof. *)
  let find_outbox level =
    let rec aux level' =
      if level' > level + 10 then
        Test.fail "Looked for an outbox for 10 levels, stopping the loop"
      else
        let* outbox =
          Sc_rollup_node.RPC.call sc_rollup_node
          @@ Sc_rollup_rpc.get_global_block_outbox ~outbox_level:level' ()
        in
        if
          JSON.is_null outbox
          || (JSON.is_list outbox && JSON.as_list outbox = [])
        then aux (level' + 1)
        else return (JSON.as_list outbox |> List.length, level')
    in
    aux level
  in
  let* size, withdrawal_level = find_outbox withdrawal_level in
  let execute_withdrawal withdrawal_level message_index =
    let* outbox_proof =
      Sc_rollup_node.RPC.call sc_rollup_node
      @@ Sc_rollup_rpc.outbox_proof_simple
           ~message_index
           ~outbox_level:withdrawal_level
           ()
    in
    let Sc_rollup_rpc.{proof; commitment_hash} =
      match outbox_proof with
      | Some r -> r
      | None -> Test.fail "No outbox proof found for the withdrawal"
    in
    let*! () =
      Client.Sc_rollup.execute_outbox_message
        ~hooks
        ~burn_cap:(Tez.of_int 10)
        ~rollup:sc_rollup_address
        ~src:Constant.bootstrap1.alias
        ~commitment_hash
        ~proof
        client
    in
    let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
    unit
  in
  let* () =
    Lwt_list.iter_s
      (fun message_index -> execute_withdrawal withdrawal_level message_index)
      (List.init size Fun.id)
  in
  return withdrawal_level

let withdraw ~commitment_period ~challenge_window ~amount_wei ~sender ~receiver
    ~evm_node ~sc_rollup_node ~sc_rollup_address ~client ~endpoint =
  let* withdrawal_level = Client.level client in

  (* Call the withdrawal precompiled contract. *)
  let* () =
    Eth_cli.add_abi ~label:"withdraw" ~abi:(withdrawal_abi_path ()) ()
  in
  let call_withdraw =
    Eth_cli.contract_send
      ~source_private_key:sender.Eth_account.private_key
      ~endpoint
      ~abi_label:"withdraw"
      ~address:"0xff00000000000000000000000000000000000001"
      ~method_call:(sf {|withdraw_base58("%s")|} receiver)
      ~value:amount_wei
      ~gas:50_000
  in
  let* _tx =
    wait_for_application ~evm_node ~sc_rollup_node ~client call_withdraw
  in
  let* _ =
    find_and_execute_withdrawal
      ~withdrawal_level
      ~commitment_period
      ~challenge_window
      ~evm_node
      ~sc_rollup_node
      ~sc_rollup_address
      ~client
  in
  unit

let check_balance ~receiver ~endpoint expected_balance =
  let* balance = Eth_cli.balance ~account:receiver ~endpoint in
  let balance = Wei.truncate_to_mutez balance in
  Check.((balance = Tez.to_mutez expected_balance) int)
    ~error_msg:(sf "Expected balance of %s should be %%R, but got %%L" receiver) ;
  unit

let test_deposit_and_withdraw =
  let admin = Constant.bootstrap5 in
  let commitment_period = 5 and challenge_window = 5 in
  register_proxy
    ~tags:["evm"; "deposit"; "withdraw"]
    ~title:"Deposit and withdraw tez"
    ~admin:(Some admin)
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~commitment_period
    ~challenge_window
  @@ fun ~protocol:_
             ~evm_setup:
               {
                 client;
                 sc_rollup_address;
                 l1_contracts;
                 sc_rollup_node;
                 endpoint;
                 evm_node;
                 _;
               } ->
  let {
    bridge;
    admin = _;
    kernel_governance = _;
    exchanger = _;
    sequencer_governance = _;
    kernel_security_governance = _;
  } =
    match l1_contracts with
    | Some x -> x
    | None -> Test.fail ~__LOC__ "The test needs the L1 bridge"
  in

  let amount_mutez = Tez.of_mutez_int 100_000_000 in
  let receiver =
    Eth_account.
      {
        address = "0x1074Fd1EC02cbeaa5A90450505cF3B48D834f3EB";
        private_key =
          "0xb7c548b5442f5b28236f0dcd619f65aaaafd952240908adcf9642d8e616587ee";
        public_key =
          "0466ed90f9a86c0908746475fbe0a40c72237de22d89076302e22c2a8da259b4aba5c7ee1f3dc3fd0b240645462620ae62b6fe8fe5b3464c3b1b4ae6c06c97b7b6";
      }
  in

  let* () =
    deposit
      ~amount_mutez
      ~sc_rollup_address
      ~bridge
      ~depositor:admin
      ~receiver:receiver.address
      ~evm_node
      ~sc_rollup_node
      client
  in
  let* () = check_balance ~receiver:receiver.address ~endpoint amount_mutez in

  let amount_wei = Wei.of_tez amount_mutez in
  (* Keep a small amount to pay for the gas. *)
  let amount_wei = Wei.(amount_wei - one_eth) in

  let withdraw_receiver = "tz1fp5ncDmqYwYC568fREYz9iwQTgGQuKZqX" in
  let* _tx =
    withdraw
      ~evm_node
      ~sc_rollup_address
      ~commitment_period
      ~challenge_window
      ~amount_wei
      ~sender:receiver
      ~receiver:withdraw_receiver
      ~sc_rollup_node
      ~client
      ~endpoint
  in

  let* balance = Client.get_balance_for ~account:withdraw_receiver client in
  let expected_balance = Tez.(amount_mutez - one) in
  Check.((balance = expected_balance) Tez.typ)
    ~error_msg:(sf "Expected %%R amount instead of %%L after withdrawal") ;
  return ()

let get_kernel_boot_wasm ~sc_rollup_node =
  let rpc_hooks : RPC_core.rpc_hooks =
    let on_request _verb ~uri:_ _data = Regression.capture "<boot.wasm>" in
    let on_response _status ~body:_ = Regression.capture "<boot.wasm>" in
    {on_request; on_response}
  in
  let* kernel_boot_opt =
    Sc_rollup_node.RPC.call sc_rollup_node ~log_response_body:false ~rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Value
         ~key:Durable_storage_path.kernel_boot_wasm
         ()
  in
  match kernel_boot_opt with
  | Some boot_wasm -> return boot_wasm
  | None -> failwith "Kernel `boot.wasm` should be accessible/readable."

let gen_test_kernel_upgrade ?setup_kernel_root_hash ?admin_contract ?timestamp
    ?(activation_timestamp = "0") ?evm_setup ?rollup_address
    ?(should_fail = false) ~installee ?with_administrator ?expect_l1_failure
    ?(admin = Constant.bootstrap1) ?(upgrador = admin) protocol =
  let* {
         node;
         client;
         sc_rollup_node;
         sc_rollup_address;
         evm_node;
         l1_contracts;
         _;
       } =
    match evm_setup with
    | Some evm_setup -> return evm_setup
    | None ->
        setup_evm_kernel
          ?setup_kernel_root_hash
          ?timestamp
          ?with_administrator
          ~admin:(Some admin)
          protocol
  in
  let admin_contract =
    match admin_contract with
    | Some x -> x
    | None ->
        let l1_contracts = Option.get l1_contracts in
        l1_contracts.admin
  in
  let sc_rollup_address =
    Option.value ~default:sc_rollup_address rollup_address
  in
  let preimages_dir = Sc_rollup_node.data_dir sc_rollup_node // "wasm_2_0_0" in
  let* {root_hash; _} =
    Sc_rollup_helpers.prepare_installer_kernel ~preimages_dir installee
  in
  let* payload = Evm_node.upgrade_payload ~root_hash ~activation_timestamp in
  let* kernel_boot_wasm_before_upgrade = get_kernel_boot_wasm ~sc_rollup_node in
  let* expected_kernel_boot_wasm =
    if should_fail then return kernel_boot_wasm_before_upgrade
    else return @@ Hex.show @@ Hex.of_string @@ read_file (Uses.path installee)
  in
  let* () =
    let* () =
      Client.transfer
        ?expect_failure:expect_l1_failure
        ~amount:Tez.zero
        ~giver:upgrador.public_key_hash
        ~receiver:admin_contract
        ~arg:(sf {|Pair "%s" 0x%s|} sc_rollup_address payload)
        ~burn_cap:Tez.one
        client
    in
    let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
    unit
  in
  let* kernel_boot_wasm_after_upgrade = get_kernel_boot_wasm ~sc_rollup_node in
  Check.((expected_kernel_boot_wasm = kernel_boot_wasm_after_upgrade) string)
    ~error_msg:(sf "Unexpected `boot.wasm`.") ;
  return
    ( sc_rollup_node,
      node,
      client,
      evm_node,
      kernel_boot_wasm_before_upgrade,
      root_hash )

let test_kernel_upgrade_evm_to_evm =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Ensures EVM kernel's upgrade integrity to itself"
  @@ fun protocol ->
  let* sc_rollup_node, _node, client, evm_node, _, _root_hash =
    gen_test_kernel_upgrade ~installee:Constant.WASM.evm_kernel protocol
  in
  (* We ensure the upgrade went well by checking if the kernel still produces
     blocks. *)
  let endpoint = Evm_node.endpoint evm_node in
  check_block_progression
    ~evm_node
    ~sc_rollup_node
    ~client
    ~endpoint
    ~expected_block_level:2

let test_kernel_upgrade_wrong_key =
  Protocol.register_test
    ~__FILE__
    ~tags:["administrator"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Ensures EVM kernel's upgrade fails with a wrong administrator key"
  @@ fun protocol ->
  let* _ =
    gen_test_kernel_upgrade
      ~expect_l1_failure:true
      ~should_fail:true
      ~installee:Constant.WASM.debug_kernel
      ~admin:Constant.bootstrap1
      ~upgrador:Constant.bootstrap2
      protocol
  in
  unit

let test_kernel_upgrade_wrong_rollup_address =
  Protocol.register_test
    ~__FILE__
    ~tags:["address"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Ensures EVM kernel's upgrade fails with a wrong rollup address"
  @@ fun protocol ->
  let* _ =
    gen_test_kernel_upgrade
      ~expect_l1_failure:true
      ~rollup_address:"sr1T13qeVewVm3tudQb8dwn8qRjptNo7KVkj"
      ~should_fail:true
      ~installee:Constant.WASM.debug_kernel
      protocol
  in
  unit

let test_kernel_upgrade_no_administrator =
  Protocol.register_test
    ~__FILE__
    ~tags:["administrator"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Ensures EVM kernel's upgrade fails if there is no administrator"
  @@ fun protocol ->
  let* _ =
    gen_test_kernel_upgrade
      ~should_fail:true
      ~installee:Constant.WASM.debug_kernel
      ~with_administrator:false
      protocol
  in
  unit

let test_kernel_upgrade_failing_migration =
  Protocol.register_test
    ~__FILE__
    ~tags:["migration"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.failed_migration;
      ])
    ~title:"Ensures EVM kernel's upgrade rollback when migration fails"
  @@ fun protocol ->
  let* ( sc_rollup_node,
         _node,
         client,
         evm_node,
         _original_kernel_boot_wasm,
         root_hash ) =
    gen_test_kernel_upgrade
      ~setup_kernel_root_hash:false
      ~installee:Constant.WASM.failed_migration
      ~should_fail:true
      protocol
  in
  let*@! found_root_hash = Rpc.tez_kernelRootHash evm_node in
  Check.((root_hash <> found_root_hash) string)
    ~error_msg:"The failed migration should not upgrade the kernel root hash" ;
  Check.(
    ("000000000000000000000000000000000000000000000000000000000000000000"
   = found_root_hash)
      string)
    ~error_msg:"The fallback root hash should be %L, got %R" ;
  (* We make sure that we can't read under the tmp file, after migration failed,
     everything is reverted. *)
  let* tmp_dummy =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Value
         ~key:"/tmp/__dummy"
         ()
  in
  (match tmp_dummy with
  | Some _ -> failwith "Nothing should be readable under the temporary dir."
  | None -> ()) ;
  (* We ensure that the fallback mechanism went well by checking if the
     kernel still produces blocks since it has booted back to the previous,
     original kernel. *)
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let endpoint = Evm_node.endpoint evm_node in
  check_block_progression
    ~evm_node
    ~sc_rollup_node
    ~client
    ~endpoint
    ~expected_block_level:3

let test_kernel_upgrade_via_governance =
  Protocol.register_test
    ~__FILE__
    ~tags:["migration"; "upgrade"; "kernel_governance"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Kernel upgrades using governance contract"
  @@ fun protocol ->
  let admin = Constant.bootstrap1 in
  let* evm_setup =
    setup_evm_kernel ~with_administrator:true ~admin:(Some admin) protocol
  in
  let l1_contracts = Option.get evm_setup.l1_contracts in
  let* _ =
    gen_test_kernel_upgrade
      ~evm_setup
      ~installee:Constant.WASM.debug_kernel
      ~admin_contract:l1_contracts.kernel_governance
      protocol
  in
  unit

let test_kernel_upgrade_via_kernel_security_governance =
  Protocol.register_test
    ~__FILE__
    ~tags:["migration"; "upgrade"; "kernel_security_governance"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Kernel upgrades using security governance contract"
  @@ fun protocol ->
  let admin = Constant.bootstrap1 in
  let* evm_setup =
    setup_evm_kernel ~with_administrator:true ~admin:(Some admin) protocol
  in
  let l1_contracts = Option.get evm_setup.l1_contracts in
  let* _ =
    gen_test_kernel_upgrade
      ~evm_setup
      ~installee:Constant.WASM.debug_kernel
      ~admin_contract:l1_contracts.kernel_security_governance
      protocol
  in
  unit

let test_rpc_sendRawTransaction =
  register_both
    ~tags:["evm"; "rpc"; "tx_hash"; "raw_tx"]
    ~title:
      "Ensure EVM node returns appropriate hash for any given transactions."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let txs =
    [
      "f86480825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a0964f3d64696410dc1054af0aca06d5a4005a3bdf3db0b919e3de207af93e1004a03eb79935b4e15a576955c104fd6a614437dd0464d382198dde4c52a8eed4061a";
      "f86480825208831e848094b53dc01974176e5dff2298c5a94343c2585e3c548080820a96a0542124cb9fe80b1c8bd18a07b6ea8292770055c06c2a1b7b0aa82e121c30d0a1a07e9092eb6d303b58c89475f147684a1ae44d0a0248a7409dfc15675555a467e6";
    ]
  in
  let* hashes =
    Lwt_list.map_p
      (fun raw_tx ->
        let*@ hash = Rpc.send_raw_transaction ~raw_tx evm_node in
        return hash)
      txs
  in
  let expected_hashes =
    [
      "0xb941cbf32821471381b6f003f9013b95c788ad24260d2af54848a5b504c09bb0";
      "0x6ddd857feb6c81405ea50fb12489ea00cd91193ae36cb41fc119999521422e3a";
    ]
  in
  Check.((hashes = expected_hashes) (list string))
    ~error_msg:"Unexpected returned hash, should be %R, but got %L" ;
  unit

let by_block_arg_string by =
  match by with `Hash -> "Hash" | `Number -> "Number"

let get_transaction_by_block_arg_and_index_request ~by arg index =
  let by = by_block_arg_string by in
  Evm_node.
    {
      method_ = "eth_getTransactionByBlock" ^ by ^ "AndIndex";
      parameters = `A [`String arg; `String index];
    }

let get_transaction_by_block_arg_and_index ~by evm_node block_hash index =
  let* transaction_object =
    Evm_node.call_evm_rpc
      evm_node
      (get_transaction_by_block_arg_and_index_request ~by block_hash index)
  in
  return
    JSON.(
      transaction_object |-> "result" |> Transaction.transaction_object_of_json)

let test_rpc_getTransactionByBlockArgAndIndex ~by ~evm_setup =
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let txs = read_tx_from_file () |> List.filteri (fun i _ -> i < 3) in
  let* _, _, hashes =
    send_n_transactions ~sc_rollup_node ~client ~evm_node (List.map fst txs)
  in
  Lwt_list.iter_s
    (fun transaction_hash ->
      let* receipt =
        wait_for_application
          ~evm_node
          ~sc_rollup_node
          ~client
          (wait_for_transaction_receipt ~evm_node ~transaction_hash)
      in
      let block_arg, index =
        ( (match by with
          | `Hash -> receipt.blockHash
          | `Number -> Int32.to_string receipt.blockNumber),
          receipt.transactionIndex )
      in
      let* transaction_object =
        get_transaction_by_block_arg_and_index
          ~by
          evm_node
          block_arg
          (Int32.to_string index)
      in
      Check.(
        ((transaction_object.hash = transaction_hash) string)
          ~error_msg:"Incorrect transaction hash, should be %R, but got %L.") ;
      unit)
    hashes

let test_rpc_getCode =
  register_both ~tags:["evm"; "rpc"; "get_code"] ~title:"RPC method eth_getCode"
  @@ fun ~protocol:_ ~evm_setup ->
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* address, _ = deploy ~contract:simple_storage ~sender evm_setup in
  let*@ code = Rpc.get_code ~address evm_setup.evm_node in
  let expected_code =
    "0x608060405234801561001057600080fd5b50600436106100415760003560e01c80634e70b1dc1461004657806360fe47b1146100645780636d4ce63c14610080575b600080fd5b61004e61009e565b60405161005b91906100d0565b60405180910390f35b61007e6004803603810190610079919061011c565b6100a4565b005b6100886100ae565b60405161009591906100d0565b60405180910390f35b60005481565b8060008190555050565b60008054905090565b6000819050919050565b6100ca816100b7565b82525050565b60006020820190506100e560008301846100c1565b92915050565b600080fd5b6100f9816100b7565b811461010457600080fd5b50565b600081359050610116816100f0565b92915050565b600060208284031215610132576101316100eb565b5b600061014084828501610107565b9150509291505056fea2646970667358221220ec57e49a647342208a1f5c9b1f2049bf1a27f02e19940819f38929bf67670a5964736f6c63430008120033"
  in
  Check.((code = expected_code) string)
    ~error_msg:"Expected code is %R, but got %L" ;
  unit

let test_rpc_getTransactionByHash =
  register_both
    ~tags:["evm"; "rpc"; "get_transaction_by"; "transaction_by_hash"]
    ~title:"RPC method eth_getTransactionByHash"
    ~da_fee_per_byte:(Wei.of_eth_string "0.000004")
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let receiver = Eth_account.bootstrap_accounts.(1) in
  let value = Wei.one_eth in
  let estimateGas =
    [
      ("from", `String sender.address);
      ("to", `String receiver.address);
      ("value", `String (Wei.to_string value));
    ]
  in
  let*@ expected_gas = Rpc.estimate_gas estimateGas evm_node in
  let submitted_gas = Int64.mul expected_gas 2L in
  let* expected_gas_price =
    Rpc.get_gas_price evm_node |> Lwt.map Int64.of_int32
  in
  let submitted_gas_price = Int64.mul expected_gas_price 2L in
  let send =
    Eth_cli.transaction_send
      ~source_private_key:sender.Eth_account.private_key
      ~to_public_key:receiver.Eth_account.address
      ~value
      ~endpoint:(Evm_node.endpoint evm_node)
      ~gas_price:(Wei.to_wei_z (Z.of_int64 submitted_gas_price))
      ~gas_limit:(Z.of_int64 submitted_gas)
  in
  let* transaction_hash =
    wait_for_application ~evm_node ~sc_rollup_node ~client send
  in
  let*@ transaction_object =
    Rpc.get_transaction_by_hash ~transaction_hash evm_node
  in
  Check.(
    ((transaction_object.hash = transaction_hash) string)
      ~error_msg:"Incorrect transaction hash, should be %R, but got %L.") ;
  Check.(
    ((transaction_object.gas = submitted_gas) int64)
      ~error_msg:"Incorrect gas on transaction, should be %R, but got %L.") ;
  Check.(
    ((transaction_object.gasPrice = submitted_gas_price) int64)
      ~error_msg:"Incorrect gasPrice on transaction, should be %R, but got %L.") ;
  unit

let test_rpc_getTransactionByBlockHashAndIndex =
  let config =
    `Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml")
  in
  register_both
    ~tags:["evm"; "rpc"; "get_transaction_by"; "block_hash_and_index"]
    ~title:"RPC method eth_getTransactionByBlockHashAndIndex"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
    ~config
  @@ fun ~protocol:_ -> test_rpc_getTransactionByBlockArgAndIndex ~by:`Hash

let test_rpc_getTransactionByBlockNumberAndIndex =
  let config =
    `Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml")
  in
  register_both
    ~tags:["evm"; "rpc"; "get_transaction_by"; "block_number_and_index"]
    ~title:"RPC method eth_getTransactionByBlockNumberAndIndex"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
    ~config
  @@ fun ~protocol:_ -> test_rpc_getTransactionByBlockArgAndIndex ~by:`Number

type storage_migration_results = {
  transfer_result : transfer_result;
  block_result : Block.t;
  config_result : config_result;
}

(* This is the test generator that will trigger the sanity checks for migration
   tests.
   Note that:
   - it uses the latest version of the ghostnet EVM rollup as a starter kernel.
   - the upgrade of the kernel during the test will always target the latest one
     on master.
   - everytime a new path/rpc/object is stored in the kernel, a new sanity check
     MUST be generated. *)
let gen_kernel_migration_test ?config ?(admin = Constant.bootstrap5)
    ~scenario_prior ~scenario_after protocol =
  let* evm_setup =
    setup_evm_kernel
      ~da_fee_per_byte:Wei.zero
      ~minimum_base_fee_per_gas:(Wei.of_string "21000")
      ?config
      ~kernel_installee:Constant.WASM.ghostnet_evm_kernel
      ~admin:(Some admin)
      protocol
  in
  (* Load the EVM rollup's storage and sanity check results. *)
  let* evm_node =
    Evm_node.init
      ~mode:(Proxy {devmode = false})
      (Sc_rollup_node.endpoint evm_setup.sc_rollup_node)
  in
  let endpoint = Evm_node.endpoint evm_node in
  let* sanity_check =
    scenario_prior ~evm_setup:{evm_setup with evm_node; endpoint}
  in
  (* Upgrade the kernel. *)
  let* _ =
    gen_test_kernel_upgrade
      ~evm_setup
      ~installee:Constant.WASM.evm_kernel
      ~admin
      protocol
  in
  let* _ =
    (* wait for the migration to be processed *)
    next_evm_level
      ~evm_node
      ~sc_rollup_node:evm_setup.sc_rollup_node
      ~client:evm_setup.client
  in
  let* evm_node =
    Evm_node.init
      ~mode:(Proxy {devmode = true})
      (Sc_rollup_node.endpoint evm_setup.sc_rollup_node)
  in
  let evm_setup = {evm_setup with evm_node} in
  (* Check the values after the upgrade with [sanity_check] results. *)
  scenario_after ~evm_setup ~sanity_check

let test_kernel_migration =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "migration"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Ensures EVM kernel's upgrade succeed with potential migration(s)."
  @@ fun protocol ->
  let sender, receiver =
    (Eth_account.bootstrap_accounts.(0), Eth_account.bootstrap_accounts.(1))
  in
  let scenario_prior ~evm_setup =
    let* transfer_result =
      make_transfer
        ~value:Wei.(Configuration.default_bootstrap_account_balance - one_eth)
        ~sender
        ~receiver
        evm_setup
    in
    let*@ block_result = latest_block evm_setup.evm_node in
    let* config_result = config_setup evm_setup in
    return {transfer_result; block_result; config_result}
  in
  let scenario_after ~evm_setup ~sanity_check =
    let* () =
      ensure_transfer_result_integrity
        ~sender
        ~receiver
        ~transfer_result:sanity_check.transfer_result
        evm_setup
    in
    let* () =
      ensure_block_integrity ~block_result:sanity_check.block_result evm_setup
    in
    ensure_config_setup_integrity
      ~config_result:sanity_check.config_result
      evm_setup
  in
  gen_kernel_migration_test ~scenario_prior ~scenario_after protocol

let test_deposit_dailynet =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "deposit"; "dailynet"]
    ~uses:(fun _protocol ->
      Constant.
        [
          octez_smart_rollup_node;
          smart_rollup_installer;
          octez_evm_node;
          Constant.WASM.evm_kernel;
        ])
    ~title:"deposit on dailynet"
  @@ fun protocol ->
  let bridge_address = "KT1QwBaLj5TRaGU3qkU4ZKKQ5mvNvyyzGBFv" in
  let exchanger_address = "KT1FHqsvc7vRS3u54L66DdMX4gb6QKqxJ1JW" in
  let rollup_address = "sr1RYurGZtN8KNSpkMcCt9CgWeUaNkzsAfXf" in

  let mockup_client = Client.create_with_mode Mockup in
  let make_bootstrap_contract ~address ~code ~storage ?typecheck () =
    let* code_json = Client.convert_script_to_json ~script:code mockup_client in
    let* storage_json =
      Client.convert_data_to_json ~data:storage ?typecheck mockup_client
    in
    let script : Ezjsonm.value =
      `O [("code", code_json); ("storage", storage_json)]
    in
    return
      Protocol.
        {delegate = None; amount = Tez.of_int 0; script; hash = Some address}
  in

  (* Creates the exchanger contract. *)
  let* exchanger_contract =
    make_bootstrap_contract
      ~address:exchanger_address
      ~code:(exchanger_path ())
      ~storage:"Unit"
      ()
  in
  (* Creates the bridge contract initialized with exchanger contract. *)
  let* bridge_contract =
    make_bootstrap_contract
      ~address:bridge_address
      ~code:(bridge_path ())
      ~storage:(sf "Pair %S None" exchanger_address)
      ()
  in

  (* Creates the EVM rollup that listens to the bootstrap smart contract exchanger. *)
  let* {
         bootstrap_smart_rollup = evm;
         smart_rollup_node_data_dir;
         smart_rollup_node_extra_args;
       } =
    setup_bootstrap_smart_rollup
      ~name:"evm"
      ~address:rollup_address
      ~parameters_ty:evm_type
      ~installee:Constant.WASM.evm_kernel
      ~config:(`Path Base.(project_root // "etherlink/config/dailynet.yaml"))
      ()
  in

  (* Setup a chain where the EVM rollup, the exchanger contract and the bridge
     are all originated. *)
  let* node, client =
    setup_l1
      ~bootstrap_smart_rollups:[evm]
      ~bootstrap_contracts:[exchanger_contract; bridge_contract]
      protocol
  in

  let sc_rollup_node =
    Sc_rollup_node.create
      Operator
      node
      ~data_dir:smart_rollup_node_data_dir
      ~base_dir:(Client.base_dir client)
      ~default_operator:Constant.bootstrap1.public_key_hash
  in
  let* () = Client.bake_for_and_wait ~keys:[] client in

  let* () =
    Sc_rollup_node.run
      sc_rollup_node
      rollup_address
      smart_rollup_node_extra_args
  in

  let* evm_node =
    Evm_node.init
      ~mode:(Proxy {devmode = true})
      (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let endpoint = Evm_node.endpoint evm_node in

  (* Deposit tokens to the EVM rollup. *)
  let amount_mutez = Tez.of_mutez_int 100_000_000 in
  let receiver = "0x119811f34EF4491014Fbc3C969C426d37067D6A4" in

  let* () =
    deposit
      ~amount_mutez
      ~bridge:bridge_address
      ~depositor:Constant.bootstrap2
      ~receiver
      ~evm_node
      ~sc_rollup_node
      ~sc_rollup_address:rollup_address
      client
  in

  (* Check the balance in the EVM rollup. *)
  check_balance ~receiver ~endpoint amount_mutez

let test_cannot_prepayed_leads_to_no_inclusion =
  register_both
    ~tags:["evm"; "prepay"; "inclusion"]
    ~title:
      "Not being able to prepay a transaction leads to it not being included."
    ~bootstrap_accounts:[||]
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  (* No bootstrap accounts, so no one has funds. *)
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  (* This is a transfer from Eth_account.bootstrap_accounts.(0) to
     Eth_account.bootstrap_accounts.(1).  We do not use eth-cli in
     this test because we want the results of the simulation. *)
  let raw_transfer =
    "0xf86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let*@? error = Rpc.send_raw_transaction ~raw_tx:raw_transfer evm_node in
  Check.(
    ((error.message = "Cannot prepay transaction.") string)
      ~error_msg:"The transaction should fail") ;
  unit

let test_cannot_prepayed_with_delay_leads_to_no_injection =
  register_both
    ~tags:["evm"; "prepay"; "injection"]
    ~title:
      "Not being able to prepay a transaction that was included leads to it \
       not being injected."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; endpoint; _}
    ->
  let sender, to_public_key =
    ( Eth_account.bootstrap_accounts.(0),
      "0xE7f682c226d7269C7247b878B3F94c7a8d31FEf5" )
  in
  let transaction_included =
    Eth_cli.transaction_send
      ~source_private_key:sender.Eth_account.private_key
      ~to_public_key
      ~value:Wei.one
      ~endpoint
  in
  (* Transaction from previous sender to the same address but with nonce 1 and
     a gas computation that will lead it to not being able to be prepayed hence
     rejected at injection. *)
  let raw_tx =
    "f86501830186a0830186a094e7f682c226d7269c7247b878b3f94c7a8d31fef58080820a95a0a9afcb6020f31b62e45778a051c62e71ce5c52789ba6ab487812f21271a98291a03673d60e267b6d32ecd22403cb54c088ee897e0c1862aa3f48039671503957d1"
  in
  let*@ transaction_hash = Rpc.send_raw_transaction ~raw_tx evm_node in
  let* _will_succeed =
    wait_for_application ~evm_node ~sc_rollup_node ~client transaction_included
  in
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let wait_for_failure () =
    let* _ =
      wait_for_application
        ~evm_node
        ~sc_rollup_node
        ~client
        (wait_for_transaction_receipt ~evm_node ~transaction_hash)
    in
    Test.fail "Unreachable state, transaction will never be injected."
  in
  Lwt.catch wait_for_failure (function _ -> unit)

let test_rpc_sendRawTransaction_nonce_too_low =
  register_both
    ~tags:["evm"; "rpc"; "nonce"]
    ~title:"Returns an error if the nonce is too low"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  (* Nonce: 0 *)
  let raw_tx =
    "0xf86c80825208831e8480940000000000000000000000000000000000000000888ac7230489e8000080820a96a038294f867266c767aee6c3b54a0c444368fb8d5e90353219bce1da78de16aea4a018a7d3c58ddb1f6b33bad5dde106843acfbd6467e5df181d22270229dcfdf601"
  in
  let*@ transaction_hash = Rpc.send_raw_transaction ~raw_tx evm_node in
  let* _ =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (wait_for_transaction_receipt ~evm_node ~transaction_hash)
  in
  let*@? error = Rpc.send_raw_transaction ~raw_tx evm_node in
  Check.(
    ((error.message = "Nonce too low.") string)
      ~error_msg:"The transaction should fail") ;
  unit

let test_rpc_sendRawTransaction_nonce_too_high =
  register_both
    ~tags:["evm"; "rpc"; "nonce"]
    ~title:"Accepts transactions with nonce too high."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  (* Nonce: 1 *)
  let raw_tx =
    "0xf86c01825208831e8480940000000000000000000000000000000000000000888ac7230489e8000080820a95a0a349864bedc9b84aea88cda197e96538c62c242286ead58eb7180a611f850237a01206525ff16ae5b708ee02b362f9b4d7565e0d7e9b4c536d7ef7dec81cda3ac7"
  in
  let* result = Rpc.send_raw_transaction ~raw_tx evm_node in
  Check.(
    ((Result.is_ok result = true) bool) ~error_msg:"The transaction should fail") ;
  unit

let test_deposit_before_and_after_migration =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "migration"; "deposit"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Deposit before and after migration"
  @@ fun protocol ->
  let admin = Constant.bootstrap5 in
  let receiver = "0x119811f34EF4491014Fbc3C969C426d37067D6A4" in
  let amount_mutez = Tez.of_mutez_int 50_000_000 in

  let scenario_prior
      ~evm_setup:
        {
          l1_contracts;
          sc_rollup_node;
          sc_rollup_address;
          client;
          endpoint;
          evm_node;
          _;
        } =
    let {bridge; _} =
      match l1_contracts with Some x -> x | None -> assert false
    in
    let* () =
      deposit
        ~amount_mutez
        ~bridge
        ~depositor:admin
        ~receiver
        ~evm_node
        ~sc_rollup_node
        ~sc_rollup_address
        client
    in
    check_balance ~receiver ~endpoint amount_mutez
  in
  let scenario_after
      ~evm_setup:
        {
          l1_contracts;
          sc_rollup_node;
          sc_rollup_address;
          client;
          endpoint;
          evm_node;
          _;
        } ~sanity_check:_ =
    let {bridge; _} =
      match l1_contracts with Some x -> x | None -> assert false
    in
    let* () =
      deposit
        ~amount_mutez
        ~bridge
        ~depositor:admin
        ~receiver
        ~evm_node
        ~sc_rollup_node
        ~sc_rollup_address
        client
    in
    check_balance ~receiver ~endpoint Tez.(amount_mutez + amount_mutez)
  in
  gen_kernel_migration_test ~admin ~scenario_prior ~scenario_after protocol

let test_block_storage_before_and_after_migration =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "migration"; "block"; "storage"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Block storage before and after migration"
  @@ fun protocol ->
  let block_id = "1" in
  let scenario_prior ~evm_setup:{endpoint; evm_node; sc_rollup_node; client; _}
      =
    let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
    let* (block : Block.t) = Eth_cli.get_block ~block_id ~endpoint in
    return block
  in
  let scenario_after ~evm_setup:{endpoint; _} ~(sanity_check : Block.t) =
    let* (block : Block.t) = Eth_cli.get_block ~block_id ~endpoint in
    (* Compare fields stored before migration *)
    assert (block.number = sanity_check.number) ;
    assert (block.hash = sanity_check.hash) ;
    assert (block.timestamp = sanity_check.timestamp) ;
    assert (block.transactions = sanity_check.transactions) ;
    unit
  in
  gen_kernel_migration_test ~scenario_prior ~scenario_after protocol

let test_rpc_sendRawTransaction_invalid_chain_id =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "rpc"; "chain_id"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Returns an error if the chainId is not correct."
  @@ fun protocol ->
  let* {evm_node; _} = setup_evm_kernel ~admin:None protocol in
  (* Nonce: 0, chainId: 4242*)
  let raw_tx =
    "0xf86a8080831e8480940000000000000000000000000000000000000000888ac7230489e8000080822148a0e09f1fb4920f2e64a274b83d925890dd0b109fdf31f2811a781e918118daf34aa00f425e9a93bd92d710d3d323998b093a8c7d497d2af688c062a8099b076813e8"
  in
  let*@? error = Rpc.send_raw_transaction ~raw_tx evm_node in
  Check.(
    ((error.message = "Invalid chain id.") string)
      ~error_msg:"The transaction should fail") ;
  unit

let test_kernel_upgrade_version_change =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "upgrade"; "version"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Kernel version changes after an upgrade"
  @@ fun protocol ->
  let scenario_prior ~evm_setup =
    let*@ old_ = Rpc.tez_kernelVersion evm_setup.evm_node in
    return old_
  in
  let scenario_after ~evm_setup ~sanity_check:old =
    let*@ new_ = Rpc.tez_kernelVersion evm_setup.evm_node in
    Check.((old <> new_) string)
      ~error_msg:"The kernel version must change after an upgrade" ;
    unit
  in
  gen_kernel_migration_test ~scenario_prior ~scenario_after protocol

(** This tests that giving epoch (or any timestamps from the past) as
    the activation timestamp results in a immediate upgrade. *)
let test_kernel_upgrade_epoch =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "upgrade"; "timestamp"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Upgrade immediatly when activation timestamp is epoch"
  @@ fun protocol ->
  let* _ =
    gen_test_kernel_upgrade
      ~activation_timestamp:"0"
      ~installee:Constant.WASM.debug_kernel
      protocol
  in
  unit

(** This tests that the kernel waits the activation timestamp to apply
    the upgrade.  *)
let test_kernel_upgrade_delay =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "upgrade"; "timestamp"; "delay"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.debug_kernel;
      ])
    ~title:"Upgrade after a delay when activation timestamp is in the future"
  @@ fun protocol ->
  let timestamp = Client.(At (Time.of_notation_exn "2020-01-01T00:00:00Z")) in
  let activation_timestamp = "2020-01-01T00:00:10Z" in
  (* It shoulnd't be upgrade in a single block, which {!gen_test_kernel_upgrade}
     expect. *)
  let* sc_rollup_node, _node, client, evm_node, _, _root_hash =
    gen_test_kernel_upgrade
      ~timestamp
      ~activation_timestamp
      ~installee:Constant.WASM.debug_kernel
      ~should_fail:true
      protocol
  in
  let* _ =
    repeat 5 (fun _ ->
        let* _ = next_evm_level ~sc_rollup_node ~client ~evm_node in
        unit)
  in
  let kernel_debug_content = read_file (Uses.path Constant.WASM.debug_kernel) in
  let* kernel = get_kernel_boot_wasm ~sc_rollup_node in
  Check.((kernel <> kernel_debug_content) string)
    ~error_msg:(sf "The kernel hasn't upgraded") ;
  unit

let test_transaction_storage_before_and_after_migration =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "migration"; "transaction"; "storage"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Transaction storage before and after migration"
  @@ fun protocol ->
  let config =
    `Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml")
  in
  let txs = read_tx_from_file () |> List.filteri (fun i _ -> i < 3) in
  let raw_txs, tx_hashes = List.split txs in
  let check_one evm_setup tx_hash =
    let*@ _receipt = Rpc.get_transaction_receipt ~tx_hash evm_setup.evm_node in
    let* _tx_object = get_tx_object ~endpoint:evm_setup.endpoint ~tx_hash in
    unit
  in
  let scenario_prior
      ~evm_setup:({sc_rollup_node; client; evm_node; _} as evm_setup) =
    let* _requests, _receipt, _hashes =
      send_n_transactions ~sc_rollup_node ~client ~evm_node raw_txs
    in
    Lwt_list.iter_p (check_one evm_setup) tx_hashes
  in
  let scenario_after ~evm_setup ~sanity_check:() =
    Lwt_list.iter_p (check_one evm_setup) tx_hashes
  in
  gen_kernel_migration_test ~config ~scenario_prior ~scenario_after protocol

let test_kernel_root_hash_originate_absent =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "kernel_root_hash"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Kernel root hash is absent at origination if not provided"
  @@ fun protocol ->
  let* {evm_node; _} =
    setup_evm_kernel ~admin:None ~setup_kernel_root_hash:false protocol
  in
  let*@ kernel_root_hash_opt = Rpc.tez_kernelRootHash evm_node in
  Assert.is_none ~loc:__LOC__ kernel_root_hash_opt ;
  unit

let test_kernel_root_hash_originate_present =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "kernel_root_hash"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"tez_kernelRootHash takes root hash provided by the installer"
  @@ fun protocol ->
  let* {evm_node; kernel_root_hash; _} =
    setup_evm_kernel ~admin:None ~setup_kernel_root_hash:true protocol
  in
  let*@! found_kernel_root_hash = Rpc.tez_kernelRootHash evm_node in
  Check.((kernel_root_hash = found_kernel_root_hash) string)
    ~error_msg:
      "tez_kernelRootHash should return root hash set by installer after \
       origination" ;
  unit

let test_kernel_root_hash_after_upgrade =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "kernel_root_hash"; "upgrade"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"tez_kernelRootHash is set after upgrade"
  @@ fun protocol ->
  let* _sc_rollup_node, _node, _client, evm_node, _, root_hash =
    gen_test_kernel_upgrade
      ~activation_timestamp:"0"
      ~installee:Constant.WASM.evm_kernel
      protocol
  in
  let*@! found_kernel_root_hash = Rpc.tez_kernelRootHash evm_node in
  Check.((found_kernel_root_hash = root_hash) string)
    ~error_msg:"Found incorrect kernel root hash (expected %L, got %R)" ;
  unit

let register_evm_migration ~protocols =
  test_kernel_migration protocols ;
  test_deposit_before_and_after_migration protocols ;
  test_block_storage_before_and_after_migration protocols ;
  test_transaction_storage_before_and_after_migration protocols

let block_transaction_count_by ~by arg =
  let method_ = "eth_getBlockTransactionCountBy" ^ by_block_arg_string by in
  Evm_node.{method_; parameters = `A [`String arg]}

let get_block_transaction_count_by evm_node ~by arg =
  let* transaction_count =
    Evm_node.call_evm_rpc evm_node (block_transaction_count_by ~by arg)
  in
  return JSON.(transaction_count |-> "result" |> as_int64)

let test_rpc_getBlockTransactionCountBy =
  let config =
    `Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml")
  in
  register_both
    ~tags:["evm"; "rpc"; "get_block_transaction_count_by"]
    ~title:
      "RPC methods eth_getBlockTransactionCountByHash and \
       eth_getBlockTransactionCountByNumber"
    ~config
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let txs = read_tx_from_file () |> List.filteri (fun i _ -> i < 5) in
  let* _, receipt, _ =
    send_n_transactions ~sc_rollup_node ~client ~evm_node (List.map fst txs)
  in
  let* block = get_block_by_hash evm_setup receipt.blockHash in
  let expected_count =
    match block.transactions with
    | Empty -> 0L
    | Hash l -> Int64.of_int @@ List.length l
    | Full l -> Int64.of_int @@ List.length l
  in
  let* transaction_count =
    get_block_transaction_count_by evm_node ~by:`Hash receipt.blockHash
  in
  Check.((transaction_count = expected_count) int64)
    ~error_msg:
      "Expected %R transactions with eth_getBlockTransactionCountByHash, but \
       got %L" ;
  let* transaction_count =
    get_block_transaction_count_by
      evm_node
      ~by:`Number
      (Int32.to_string receipt.blockNumber)
  in
  Check.((transaction_count = expected_count) int64)
    ~error_msg:
      "Expected %R transactions with eth_getBlockTransactionCountByNumber, but \
       got %L" ;
  unit

let uncle_count_by_block_arg_request ~by arg =
  let method_ = "eth_getUncleCountByBlock" ^ by_block_arg_string by in
  Evm_node.{method_; parameters = `A [`String arg]}

let get_uncle_count_by_block_arg evm_node ~by arg =
  let* uncle_count =
    Evm_node.call_evm_rpc evm_node (uncle_count_by_block_arg_request ~by arg)
  in
  return JSON.(uncle_count |-> "result" |> as_int64)

let test_rpc_getUncleCountByBlock =
  register_both
    ~tags:["evm"; "rpc"; "get_uncle_count_by_block"]
    ~title:
      "RPC methods eth_getUncleCountByBlockHash and \
       eth_getUncleCountByBlockNumber"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let* block = Eth_cli.get_block ~block_id:"0" ~endpoint:evm_node_endpoint in
  let* uncle_count =
    get_uncle_count_by_block_arg evm_node ~by:`Hash block.hash
  in
  Check.((uncle_count = Int64.zero) int64)
    ~error_msg:
      "Expected %R uncles with eth_getUncleCountByBlockHash, but got %L" ;
  let* uncle_count =
    get_uncle_count_by_block_arg
      evm_node
      ~by:`Number
      (Int32.to_string block.number)
  in
  Check.((uncle_count = Int64.zero) int64)
    ~error_msg:
      "Expected %R uncles with eth_getUncleCountByBlockNumber, but got %L" ;
  unit

let uncle_by_block_arg_and_index_request ~by arg index =
  let by = by_block_arg_string by in
  Evm_node.
    {
      method_ = "eth_getUncleByBlock" ^ by ^ "AndIndex";
      parameters = `A [`String arg; `String index];
    }

let get_uncle_by_block_arg_and_index ~by evm_node arg index =
  let* block =
    Evm_node.call_evm_rpc
      evm_node
      (uncle_by_block_arg_and_index_request ~by arg index)
  in
  let result = JSON.(block |-> "result") in
  if JSON.is_null result then return None
  else return @@ Some (result |> Block.of_json)

let test_rpc_getUncleByBlockArgAndIndex =
  register_both
    ~tags:["evm"; "rpc"; "get_uncle_by_block_arg_and_index"]
    ~title:
      "RPC methods eth_getUncleByBlockHashAndIndex and \
       eth_getUncleByBlockNumberAndIndex"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let evm_node_endpoint = Evm_node.endpoint evm_node in
  let block_id = "0" in
  let* block = Eth_cli.get_block ~block_id ~endpoint:evm_node_endpoint in
  let* uncle =
    get_uncle_by_block_arg_and_index ~by:`Hash evm_node block.hash block_id
  in
  assert (Option.is_none uncle) ;
  let* uncle =
    get_uncle_by_block_arg_and_index
      ~by:`Number
      evm_node
      (Int32.to_string block.number)
      block_id
  in
  assert (Option.is_none uncle) ;
  unit

let test_simulation_eip2200 =
  register_both
    ~tags:["evm"; "loop"; "simulation"; "eip2200"]
    ~title:"Simulation is EIP2200 resilient"
  @@ fun ~protocol:_ ~evm_setup ->
  let {sc_rollup_node; client; endpoint; evm_node; _} = evm_setup in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* loop_address, _tx = deploy ~contract:loop ~sender evm_setup in
  (* If we support EIP-2200, the simulation gives an amount of gas
     insufficient for the execution. As we do the simulation with an
     enormous gas limit, we never trigger EIP-2200. *)
  let call =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:loop.label
      ~address:loop_address
      ~method_call:"loop(5)"
  in
  let* _tx = wait_for_application ~evm_node ~sc_rollup_node ~client call in
  unit

let test_rpc_sendRawTransaction_with_consecutive_nonce =
  register_both
    ~tags:["evm"; "rpc"; "tx_nonce"]
    ~title:"Can submit many transactions."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; client; sc_rollup_node; _} ->
  (* TODO: https://gitlab.com/tezos/tezos/-/issues/6520 *)
  (* Nonce: 0*)
  let tx_1 =
    "0xf86480825208831e84809400000000000000000000000000000000000000008080820a96a0718d24970c6d2fc794e972f4319caf24a939ff3d822959c7e6b022813d16c8c4a04535ad83a67307759569b1e2087b0b79f80d4502027b6d1d52e3c072634b3f8b"
  in
  let*@ hash_1 = Rpc.send_raw_transaction ~raw_tx:tx_1 evm_node in
  (* TODO: https://gitlab.com/tezos/tezos/-/issues/6520 *)
  (* Nonce: 1*)
  let tx_2 =
    "0xf86401825208831e84809400000000000000000000000000000000000000008080820a95a01f47f2ec950d998bd99f7ff656a7f13a385603373f0e96130290ba2869f56515a018bd20697ab1f3cd82891663c62f514de7b2deeee2ed569e85b3aa351e1b1c3b"
  in
  let*@ hash_2 = Rpc.send_raw_transaction ~raw_tx:tx_2 evm_node in
  let* _ =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (wait_for_transaction_receipt ~evm_node ~transaction_hash:hash_1)
  in
  let* _ =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (wait_for_transaction_receipt ~evm_node ~transaction_hash:hash_2)
  in
  unit

let test_rpc_sendRawTransaction_not_included =
  register_both
    ~tags:["evm"; "rpc"; "tx_nonce"; "no_inclusion"]
    ~title:
      "Tx with nonce too high are not included without previous transactions."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; client; sc_rollup_node; endpoint; _}
    ->
  (* TODO: https://gitlab.com/tezos/tezos/-/issues/6520 *)
  (* Nonce: 1 *)
  let tx =
    "f86401825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a07298a47ad7fcbe70dc9d3705af6e47147364c5ac8ede95fb561ffaa3443dd776a07042e72941ffdef02c773b7289d7e4241a5c819e78c7bfb362c7f151b0ba3e9e"
  in
  let*@ tx_hash =
    wait_for_application ~evm_node ~sc_rollup_node ~client (fun () ->
        Rpc.send_raw_transaction ~raw_tx:tx evm_node)
  in
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  (* Check if txs is not included *)
  let* receipt = Eth_cli.get_receipt ~endpoint ~tx:tx_hash in
  Check.((Option.is_none receipt = true) bool)
    ~error_msg:"Receipt should not be present" ;

  unit

let test_rpc_gasPrice =
  register_both
    ~tags:["evm"; "rpc"; "gas_price"]
    ~title:"RPC methods eth_gasPrice"
  @@ fun ~protocol:_ ~evm_setup:{evm_node; _} ->
  let expected_gas_price = Wei.of_gwei_string "1" in
  let* gas_price =
    Evm_node.(
      let* price =
        call_evm_rpc evm_node {method_ = "eth_gasPrice"; parameters = `A []}
      in
      return JSON.(price |-> "result" |> as_int64 |> Z.of_int64 |> Wei.to_wei_z))
  in
  Check.((gas_price = expected_gas_price) Wei.typ)
    ~error_msg:"Expected %R, but got %L" ;
  unit

let send_foo_mapping_storage contract_address sender
    {sc_rollup_node; client; endpoint; evm_node; _} =
  let call_foo (sender : Eth_account.t) =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:mapping_storage.label
      ~address:contract_address
      ~method_call:"foo()"
  in
  wait_for_application ~evm_node ~sc_rollup_node ~client (call_foo sender)

let test_rpc_getStorageAt =
  register_both
    ~tags:["evm"; "rpc"; "get_storage_at"]
    ~title:"RPC methods eth_getStorageAt"
  @@ fun ~protocol:_ ~evm_setup ->
  let {endpoint; evm_node; _} = evm_setup in
  let sender = Eth_account.bootstrap_accounts.(0) in
  (* deploy contract *)
  let* address, _tx = deploy ~contract:mapping_storage ~sender evm_setup in
  (* Example from
      https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getstorageat
  *)
  let expected_value0 = 1234 in
  let expected_value1 = 5678 in

  (* set values *)
  let* tx = send_foo_mapping_storage address sender evm_setup in
  let* () = check_tx_succeeded ~endpoint ~tx in
  let* hex_value =
    Evm_node.(
      let* value =
        call_evm_rpc
          evm_node
          {
            method_ = "eth_getStorageAt";
            parameters = `A [`String address; `String "0x0"; `String "latest"];
          }
      in
      return JSON.(value |-> "result" |> as_string))
  in
  Check.(
    (Durable_storage_path.no_0x hex_value = hex_256_of expected_value0) string)
    ~error_msg:"Expected %R, but got %L" ;
  let pos = Helpers.mapping_position sender.address 1 in
  let* hex_value =
    Evm_node.(
      let* value =
        call_evm_rpc
          evm_node
          {
            method_ = "eth_getStorageAt";
            parameters = `A [`String address; `String pos; `String "latest"];
          }
      in
      return JSON.(value |-> "result" |> as_string))
  in
  Check.(
    (Durable_storage_path.no_0x hex_value = hex_256_of expected_value1) string)
    ~error_msg:"Expected %R, but got %L" ;
  unit

let test_accounts_double_indexing =
  register_proxy
    ~tags:["evm"; "accounts"; "index"]
    ~title:"Accounts have a unique index"
  @@ fun ~protocol:_ ~evm_setup:full_evm_setup ->
  let check_accounts_length expected_length =
    let* length =
      Sc_rollup_node.RPC.call full_evm_setup.sc_rollup_node
      @@ Sc_rollup_rpc.get_global_block_durable_state_value
           ~pvm_kind:"wasm_2_0_0"
           ~operation:Sc_rollup_rpc.Value
           ~key:"/evm/world_state/indexes/accounts/length"
           ()
    in
    let length = Option.map Helpers.hex_string_to_int length in
    Check.((length = Some expected_length) (option int))
      ~error_msg:"Expected %R accounts, got %L" ;
    unit
  in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let receiver = Eth_account.bootstrap_accounts.(1) in
  (* Send a first transaction, there must be 2 indexes. *)
  let* _tx_hash = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
  let* () = check_accounts_length 2 in
  (* After a second transaction with the same accounts, there still must
     be 2 indexes. *)
  let* _tx_hash = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
  let* () = check_accounts_length 2 in
  unit

let test_originate_evm_kernel_and_dump_pvm_state =
  register_proxy
    ~tags:["evm"]
    ~title:"Originate EVM kernel with installer and dump PVM state"
  @@ fun ~protocol:_ ~evm_setup:{client; sc_rollup_node; evm_node; _} ->
  (* First run of the installed EVM kernel, it will initialize the directory
     "eth_accounts". *)
  let* _level = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let dump = Temp.file "dump.json" in
  let* () = Sc_rollup_node.dump_durable_storage ~sc_rollup_node ~dump () in
  let installer = Installer_kernel_config.of_json dump in

  (* Check the consistency of the PVM state as queried by RPCs and the dumped PVM state. *)
  Lwt_list.iter_s
    (function
      (* We consider only the Set instruction because the dump durable storage
         command of the node produce only this instruction. *)
      | Installer_kernel_config.Set {value; to_} ->
          let* expected_value =
            Sc_rollup_node.RPC.call sc_rollup_node
            @@ Sc_rollup_rpc.get_global_block_durable_state_value
                 ~pvm_kind:"wasm_2_0_0"
                 ~operation:Sc_rollup_rpc.Value
                 ~key:to_
                 ()
          in
          let expected_value =
            match expected_value with
            | Some expected_value -> expected_value
            | None ->
                Test.fail "The key %S doesn't exist in the durable storage" to_
          in
          Check.((expected_value = value) string)
            ~error_msg:
              (sf "Value found in installer is %%R but expected %%L at %S" to_) ;
          unit
      | _ -> assert false)
    installer

(** Test that a contract can be called,
    and that the call can modify the storage.  *)
let test_l2_call_inter_contract =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "l2_deploy"; "l2_call"; "inter_contract"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Check L2 inter contract call"
  @@ fun protocol ->
  (* setup *)
  let* ({evm_node; sc_rollup_node; client; _} as evm_setup) =
    setup_evm_kernel ~admin:None protocol
  in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in

  (* deploy Callee contract *)
  let* callee_address, _tx = deploy ~contract:callee ~sender evm_setup in

  (* set 20 directly in the Callee *)
  let* tx =
    let call_set_directly (sender : Eth_account.t) n =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:callee.label
        ~address:callee_address
        ~method_call:(Printf.sprintf "setX(%d)" n)
    in
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_set_directly sender 20)
  in

  let* () = check_tx_succeeded ~endpoint ~tx in
  let* () = check_storage_size sc_rollup_node ~address:callee_address 1 in
  let* () =
    check_nb_in_storage ~evm_setup ~address:callee_address ~nth:0 ~expected:20
  in

  (* deploy caller contract *)
  let* caller_address, _tx = deploy ~contract:caller ~sender evm_setup in

  (* set 10 through the caller *)
  let* tx =
    let call_set_from_caller (sender : Eth_account.t) n =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:caller.label
        ~address:caller_address
        ~method_call:(Printf.sprintf "setX(\"%s\", %d)" callee_address n)
    in
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_set_from_caller sender 10)
  in

  let* () = check_tx_succeeded ~endpoint ~tx in
  let* () = check_storage_size sc_rollup_node ~address:callee_address 1 in
  let* () =
    check_nb_in_storage ~evm_setup ~address:callee_address ~nth:0 ~expected:10
  in
  unit

let get_logs_request ?from_block ?to_block ?address ?topics () =
  let parse_topic = function
    | [] -> `Null
    | [t] -> `String t
    | l -> `A (List.map (fun s -> `String s) l)
  in
  let parse_address = function
    | `Single a -> `String a
    | `List l -> `A (List.map (fun a -> `String a) l)
  in
  let parameters : JSON.u =
    `A
      [
        `O
          (Option.fold
             ~none:[]
             ~some:(fun f -> [("fromBlock", `String f)])
             from_block
          @ Option.fold
              ~none:[]
              ~some:(fun t -> [("toBlock", `String t)])
              to_block
          @ Option.fold
              ~none:[]
              ~some:(fun a -> [("address", parse_address a)])
              address
          @ Option.fold
              ~none:[]
              ~some:(fun t -> [("topics", `A (List.map parse_topic t))])
              topics);
      ]
  in
  Evm_node.{method_ = "eth_getLogs"; parameters}

let get_logs ?from_block ?to_block ?address ?topics evm_node =
  let* response =
    Evm_node.call_evm_rpc
      evm_node
      (get_logs_request ?from_block ?to_block ?address ?topics ())
  in
  return
    JSON.(response |-> "result" |> as_list |> List.map Transaction.logs_of_json)

let test_rpc_getLogs =
  register_both ~tags:["evm"; "rpc"; "get_logs"] ~title:"Check getLogs RPC"
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; client; sc_rollup_node; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let player = Eth_account.bootstrap_accounts.(1) in
  (* deploy the contract *)
  let* address, _tx = deploy ~contract:erc20 ~sender evm_setup in
  let address = String.lowercase_ascii address in
  Check.(
    (address = "0xd77420f73b4612a7a99dba8c2afd30a1886b0344")
      string
      ~error_msg:"Expected address to be %R but was %L.") ;
  (* minting / burning *)
  let call_mint (sender : Eth_account.t) n =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:erc20.label
      ~address
      ~method_call:(Printf.sprintf "mint(%d)" n)
  in
  let call_burn ?(expect_failure = false) (sender : Eth_account.t) n =
    Eth_cli.contract_send
      ~expect_failure
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:erc20.label
      ~address
      ~method_call:(Printf.sprintf "burn(%d)" n)
  in
  let transfer_event_topic =
    let h =
      Tezos_crypto.Hacl.Hash.Keccak_256.digest
        (Bytes.of_string "Transfer(address,address,uint256)")
    in
    "0x" ^ Hex.show (Hex.of_bytes h)
  in
  let zero_address = "0x" ^ String.make 64 '0' in
  let burn_logs sender amount =
    [
      ( address,
        [transfer_event_topic; hex_256_of_address sender; zero_address],
        "0x" ^ hex_256_of amount );
    ]
  in
  (* sender mints 42 *)
  let* tx1 =
    wait_for_application ~evm_node ~sc_rollup_node ~client (call_mint sender 42)
  in
  (* player mints 100 *)
  let* _tx =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_mint player 100)
  in
  (* sender burns 42 *)
  let* _tx =
    wait_for_application ~evm_node ~sc_rollup_node ~client (call_burn sender 42)
  in
  (* Check that there have been 3 logs in total *)
  let* all_logs = get_logs ~from_block:"0" evm_node in
  Check.((List.length all_logs = 3) int) ~error_msg:"Expected %R logs, got %L" ;
  (* Check that the [address] contract has produced 3 logs in total *)
  let* contract_logs =
    get_logs ~from_block:"0" ~address:(`Single address) evm_node
  in
  Check.((List.length contract_logs = 3) int)
    ~error_msg:"Expected %R logs, got %L" ;
  (* Same check also works if [address] is the second in the addresses
     list *)
  let* contract_logs =
    get_logs
      ~from_block:"0"
      ~address:(`List ["0x0000000000000000000000000000000000000000"; address])
      evm_node
  in
  Check.((List.length contract_logs = 3) int)
    ~error_msg:"Expected %R logs, got %L" ;
  (* Check that there have been 3 logs with the transfer event topic *)
  let* transfer_logs =
    get_logs ~from_block:"0" ~topics:[[transfer_event_topic]] evm_node
  in
  Check.((List.length transfer_logs = 3) int)
    ~error_msg:"Expected %R logs, got %L" ;
  (* Check that [sender] appears in 2 logs.
     Note: this would also match on a transfer from zero to zero. *)
  let* sender_logs =
    get_logs
      ~from_block:"0"
      ~topics:
        [
          [];
          [hex_256_of_address sender; zero_address];
          [hex_256_of_address sender; zero_address];
        ]
      evm_node
  in
  Check.((List.length sender_logs = 2) int)
    ~error_msg:"Expected %R logs, got %L" ;
  (* Look for a specific log, for the sender burn. *)
  let* sender_burn_logs =
    get_logs
      ~from_block:"0"
      ~topics:
        [[transfer_event_topic]; [hex_256_of_address sender]; [zero_address]]
      evm_node
  in
  Check.(
    (List.map Transaction.extract_log_body sender_burn_logs
    = burn_logs sender 42)
      (list (tuple3 string (list string) string)))
    ~error_msg:"Expected logs %R, got %L" ;
  (* Check that a specific block has a log *)
  let*@! tx1_receipt = Rpc.get_transaction_receipt ~tx_hash:tx1 evm_node in
  let* tx1_block_logs =
    get_logs
      ~from_block:(Int32.to_string tx1_receipt.blockNumber)
      ~to_block:(Int32.to_string tx1_receipt.blockNumber)
      evm_node
  in
  Check.((List.length tx1_block_logs = 1) int)
    ~error_msg:"Expected %R logs, got %L" ;
  (* Check no logs after transactions *)
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let*@ no_logs_start = Rpc.block_number evm_node in
  let* new_logs =
    get_logs ~from_block:(Int32.to_string no_logs_start) evm_node
  in
  Check.((List.length new_logs = 0) int) ~error_msg:"Expected %R logs, got %L" ;
  unit

let test_tx_pool_replacing_transactions =
  register_both
    ~tags:["evm"; "tx_pool"]
    ~title:"Transactions can be replaced"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  let bob = Eth_account.bootstrap_accounts.(0) in
  let*@ bob_nonce = Rpc.get_transaction_count evm_node ~address:bob.address in
  (* nonce: 0, private_key: bootstrappe_account(0), amount: 10; max_fees: 21000*)
  let tx_a =
    "0xf86b80825208825208940000000000000000000000000000000000000000888ac7230489e8000080820a95a05fc733145b2066166e074bc42239a7312b2358f5cbf9ce17bab404abd1dfaff0a0493e763aa933d3eb724d75f9ad6fb4bbffdf3d54568d44d6f70cfcf0a07dc4f8"
  in
  (* nonce: 0, private_key: bootstrappe_account(0), amount: 5; max_fees: 30000*)
  let tx_b =
    "0xf86b80827530825208940000000000000000000000000000000000000000884563918244f4000080820a96a008410806e7a3c6b403bbfa99d82886e5460921a664410eaea5fe99050c4dc63da031c3eb45ac8a42600b27029d1c910b4c0006f1f435a29f91626964a8cf25da3f"
  in
  (* Send the transactions to the proxy*)
  let*@ _tx_a_hash = Rpc.send_raw_transaction ~raw_tx:tx_a evm_node in
  let*@ tx_b_hash = Rpc.send_raw_transaction ~raw_tx:tx_b evm_node in
  let* receipt =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (wait_for_transaction_receipt ~evm_node ~transaction_hash:tx_b_hash)
  in
  let*@ new_bob_nonce =
    Rpc.get_transaction_count evm_node ~address:bob.address
  in
  Check.((receipt.status = true) bool) ~error_msg:"Transaction has failed" ;
  Check.((new_bob_nonce = Int64.(add bob_nonce one)) int64)
    ~error_msg:"Bob has sent more than one transaction" ;
  unit

let test_l2_nested_create =
  register_both
    ~tags:["evm"; "l2_deploy"; "l2_create"; "inter_contract"]
    ~title:"Check L2 nested create"
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* nested_create_address, _tx =
    deploy ~contract:nested_create ~sender evm_setup
  in
  let* tx1 =
    let call_create (sender : Eth_account.t) n =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:nested_create.label
        ~address:nested_create_address
        ~method_call:(Printf.sprintf "create(%d)" n)
    in
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_create sender 1)
  in
  let* tx2 =
    let call_create (sender : Eth_account.t) n salt =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:nested_create.label
        ~address:nested_create_address
        ~method_call:(Printf.sprintf "create2(%d, \"%s\")" n salt)
    in
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_create sender 1 "0x")
  in
  let* () = check_tx_succeeded ~endpoint ~tx:tx1 in
  let* () = check_tx_succeeded ~endpoint ~tx:tx2 in
  unit

let test_block_hash_regression =
  Protocol.register_regression_test
    ~__FILE__
    ~tags:["evm"; "block"; "hash"; "regression"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_evm_node;
        Constant.octez_smart_rollup_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Regression test for L2 block hash"
  @@ fun protocol ->
  let config =
    `Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml")
  in
  (* We use a timestamp equal to the next day after genesis.
     The genesis timestamp can be found in tezt/lib_tezos/client.ml *)
  let* {evm_node; sc_rollup_node; client; _} =
    setup_evm_kernel
      ~config
      ~admin:None
      ~timestamp:(At (Option.get @@ Ptime.of_date (2018, 7, 1)))
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      protocol
  in
  let txs = read_tx_from_file () |> List.filteri (fun i _ -> i < 3) in
  let raw_txs, _tx_hashes = List.split txs in
  let* _requests, receipt, _hashes =
    send_n_transactions ~sc_rollup_node ~client ~evm_node raw_txs
  in
  Regression.capture @@ sf "Block hash: %s" receipt.blockHash ;
  unit

let test_l2_revert_returns_unused_gas =
  register_both
    ~tags:["evm"]
    ~title:"Check L2 revert returns unused gas"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* _revert_address, _tx = deploy ~contract:revert ~sender evm_setup in
  (* Tx data is constructed by:
     cd src/kernel_evm/benchmarks/scripts
     node sign_tx.js ../../../../etherlink/tezt/tests/evm_kernel_inputs/call_revert.json "9722f6cc9ff938e63f8ccb74c3daa6b45837e5c5e3835ac08c44c50ab5f39dc0"
  *)
  let tx =
    "0xf8690183010000830186a094d77420f73b4612a7a99dba8c2afd30a1886b03448084c0406226820a96a0869b3a97d2c87d41c22eaeafba2644c276e74267998dff3504d1d2b35fae0e2ba058f0661adcff7d2abd3c6eb4d663e4731c838f6ef15ebb797b88db87c4fee39b"
  in
  let* balance_before = Eth_cli.balance ~account:sender.address ~endpoint in
  let*@ transaction_hash = Rpc.send_raw_transaction ~raw_tx:tx evm_node in
  let* transaction_receipt =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (wait_for_transaction_receipt ~evm_node ~transaction_hash)
  in
  let gas_used = transaction_receipt.gasUsed in
  let* () = check_tx_failed ~endpoint ~tx:transaction_hash in
  Check.((gas_used < 100000L) int64)
    ~error_msg:"Expected gas usage less than %R logs, got %L" ;
  let* balance_after = Eth_cli.balance ~account:sender.address ~endpoint in
  let gas_fee_paid = Wei.(balance_before - balance_after) in
  let gas_price = transaction_receipt.effectiveGasPrice in
  let expected_gas_fee_paid = expected_gas_fees ~gas_price ~gas_used in
  Check.((expected_gas_fee_paid = gas_fee_paid) Wei.typ)
    ~error_msg:"Expected gas fee paid to be %L, got %R" ;
  unit

let test_l2_create_collision =
  register_both
    ~tags:["evm"; "l2_create"; "collision"]
    ~title:"Check L2 create collision"
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* create2_address, _tx = deploy ~contract:create2 ~sender evm_setup in

  let call_create2 (sender : Eth_account.t) ~expect_failure =
    Eth_cli.contract_send
      ~expect_failure
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:create2.label
      ~address:create2_address
      ~method_call:(Printf.sprintf "create2()")
  in

  let* tx1 =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_create2 sender ~expect_failure:false)
  in

  let* tx2 =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_create2 sender ~expect_failure:true)
  in

  let* () = check_tx_succeeded ~tx:tx1 ~endpoint in
  check_tx_failed ~tx:tx2 ~endpoint

let test_l2_intermediate_OOG_call =
  register_both
    ~tags:["evm"; "out_of_gas"; "call"]
    ~title:
      "Check that an L2 call to a smart contract with an intermediate call \
       that runs out of gas still succeeds."
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* random_contract_address, _tx =
    deploy ~contract:simple_storage ~sender evm_setup
  in
  let* oog_call_address, _tx = deploy ~contract:oog_call ~sender evm_setup in
  let call_oog (sender : Eth_account.t) ~expect_failure =
    Eth_cli.contract_send
      ~expect_failure
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:oog_call.label
      ~address:oog_call_address
      ~method_call:
        (Printf.sprintf "sendViaCall(\"%s\")" random_contract_address)
  in
  let* tx =
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_oog sender ~expect_failure:false)
  in
  check_tx_succeeded ~tx ~endpoint

let test_l2_ether_wallet =
  register_both
    ~tags:["evm"; "l2_call"; "wallet"]
    ~title:"Check ether wallet functions correctly"
  @@ fun ~protocol:_ ~evm_setup ->
  let {evm_node; sc_rollup_node; client; _} = evm_setup in
  let endpoint = Evm_node.endpoint evm_node in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* ether_wallet_address, _tx =
    deploy ~contract:ether_wallet ~sender evm_setup
  in
  let* tx1 =
    let transaction =
      Eth_cli.transaction_send
        ~source_private_key:sender.private_key
        ~to_public_key:ether_wallet_address
        ~value:(Wei.of_eth_int 100)
        ~endpoint
    in
    wait_for_application ~evm_node ~sc_rollup_node ~client transaction
  in
  let* tx2 =
    let call_withdraw (sender : Eth_account.t) n =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:ether_wallet.label
        ~address:ether_wallet_address
        ~method_call:(Printf.sprintf "withdraw(%d)" n)
    in
    wait_for_application
      ~evm_node
      ~sc_rollup_node
      ~client
      (call_withdraw sender 100)
  in
  let* () = check_tx_succeeded ~endpoint ~tx:tx1 in
  let* () = check_tx_succeeded ~endpoint ~tx:tx2 in
  unit

let test_keep_alive =
  Protocol.register_test
    ~__FILE__
    ~tags:["keep_alive"; "proxy"]
    ~title:"Proxy mode keep alive argument"
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    (fun protocol ->
      let* {sc_rollup_node; sc_rollup_address; evm_node; endpoint = _; _} =
        setup_evm_kernel ~admin:None protocol
      in
      (* Stop the EVM and rollup nodes. *)
      let* () = Evm_node.terminate evm_node in
      let* () = Sc_rollup_node.terminate sc_rollup_node in
      (* Restart the evm node without keep alive, expected to fail. *)
      let process = Evm_node.spawn_run evm_node in
      let* () =
        Process.check_error ~msg:(rex "the communication was lost") process
      in
      (* Restart with keep alive. The EVM node is waiting for the connection. *)
      let* () =
        Evm_node.run ~wait:false ~extra_arguments:["--keep-alive"] evm_node
      in
      let* () = Evm_node.wait_for_retrying_connect evm_node in
      (* Restart the rollup node to restore the connection. *)
      let* () = Sc_rollup_node.run sc_rollup_node sc_rollup_address [] in
      let* () = Evm_node.wait_for_ready evm_node in
      (* The EVM node should respond to RPCs. *)
      let*@ _block_number = Rpc.block_number evm_node in
      (* Stop the rollup node, the EVM node no longer properly respond to RPCs. *)
      let* () = Sc_rollup_node.terminate sc_rollup_node in
      let*@? error = Rpc.block_number evm_node in
      Check.(error.message =~ rex "the communication was lost")
        ~error_msg:
          "The RPC was supposed to failed because of lost communication" ;
      (* Restart the EVM node, do the same RPC. *)
      let* () = Sc_rollup_node.run sc_rollup_node sc_rollup_address [] in
      let*@ _block_number = Rpc.block_number evm_node in
      unit)

let test_regression_block_hash_gen =
  (* This test is created because of bug in blockConstant in simulation,
     which caused the simulation to return a wrong estimate of gas limit,
     leading to failed contract deployment for block_hash_gen.
     This test checks regression for the fix *)
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "l2_call"; "block_hash"; "timestamp"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Random generation based on block hash and timestamp"
  @@ fun protocol ->
  (* Ok this one is tricky. As far as I understand the test can be
     flaky because the estimateGas does not provide enough
     gas. However, all estimateGas are run on the same block but do
     not provide the same response, as the block number is constant I
     make the timestamp constant as well to make the test more
     predictible. I am not sure about the fix. In the worst case it
     does not change the test semantics. *)
  let timestamp = Client.(At (Time.of_notation_exn "2020-01-01T00:00:00Z")) in
  let* ({evm_node; sc_rollup_node; client; _} as evm_setup) =
    setup_evm_kernel ~admin:None ~timestamp protocol
  in
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* _address, _tx = deploy ~contract:block_hash_gen ~sender evm_setup in
  unit

let test_reboot_out_of_ticks =
  register_proxy
    ~tags:["evm"; "reboot"; "loop"; "out_of_ticks"]
    ~title:
      "Check that the kernel can handle transactions that take too many ticks \
       for a single run"
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; node; client; _} ->
  (* Retrieves all the messages and prepare them for the current rollup. *)
  let txs =
    read_file (kernel_inputs_path ^ "/loops-out-of-ticks")
    |> String.trim |> String.split_on_char '\n'
  in
  (* The first three transactions are sent in a separate block, to handle any nonce issue. *)
  let first_block, second_block, third_block, fourth_block =
    match txs with
    | faucet1 :: faucet2 :: create :: rem ->
        ([faucet1], [faucet2], [create], rem)
    | _ ->
        failwith
          "The prepared transactions should contain at least 3 transactions"
  in
  let* () =
    Lwt_list.iter_s
      (fun block ->
        let* _requests, _receipt, _hashes =
          send_n_transactions
            ~sc_rollup_node
            ~client
            ~evm_node
            ~wait_for_blocks:5
            block
        in
        unit)
      [first_block; second_block; third_block]
  in
  let* total_tick_number_before_expected_reboots =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_total_ticks ()
  in
  let* l1_level_before_out_of_ticks = Node.get_level node in
  let* requests, receipt, _hashes =
    send_n_transactions
      ~sc_rollup_node
      ~client
      ~evm_node
      ~wait_for_blocks:5
      (* By default, it waits for 3 blocks. We need to take into account the
         blocks before the inclusion which is generally 2. The loops can be a
         bit long to execute, as such the inclusion test might fail before the
         execution is over, making it flaky. *)
      fourth_block
  in
  let* total_tick_number_with_expected_reboots =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_total_ticks ()
  in
  let*@ block_with_out_of_ticks =
    Rpc.get_block_by_number
      ~block:(Format.sprintf "%#lx" receipt.blockNumber)
      evm_node
  in
  (* Check that all the transactions are actually included in the same block,
     otherwise it wouldn't make sense to continue. *)
  (match block_with_out_of_ticks.Block.transactions with
  | Block.Empty -> Test.fail "Expected a non empty block"
  | Block.Full _ ->
      Test.fail "Block is supposed to contain only transaction hashes"
  | Block.Hash hashes ->
      Check.((List.length hashes = List.length requests) int)
        ~error_msg:"Expected %R transactions in the resulting block, got %L") ;

  (* Check the number of ticks spent during the period when there should have
     been a reboot due to out of ticks. There have been a reboot if the number
     of ticks is not `number of blocks` * `ticks per l1 level`. *)
  let* l1_level_after_out_of_ticks = Node.get_level node in
  let number_of_blocks =
    l1_level_after_out_of_ticks - l1_level_before_out_of_ticks
  in
  let ticks_after_expected_reboot =
    total_tick_number_with_expected_reboots
    - total_tick_number_before_expected_reboots
  in

  (* The PVM takes 11G ticks for collecting inputs, 11G for a kernel_run. As such,
     an L1 level is at least 22G ticks. *)
  let ticks_per_snapshot =
    Tezos_protocol_alpha.Protocol.Sc_rollup_wasm.V2_0_0.ticks_per_snapshot
    |> Z.to_int
  in
  let min_ticks_per_l1_level = ticks_per_snapshot * 2 in
  Check.(
    (ticks_after_expected_reboot
    >= (min_ticks_per_l1_level * number_of_blocks) + ticks_per_snapshot)
      int)
    ~error_msg:
      "The number of ticks spent during the period should be higher or equal \
       than %R, but got %L, which implies there have been no reboot, contrary \
       to what was expected." ;
  unit

let test_l2_timestamp_opcode =
  let test ~protocol:_ ~evm_setup =
    let {evm_node; sc_rollup_node; client; _} = evm_setup in
    let endpoint = Evm_node.endpoint evm_node in
    let sender = Eth_account.bootstrap_accounts.(0) in
    let* timestamp_address, _tx =
      deploy ~contract:timestamp ~sender evm_setup
    in

    let* set_timestamp_tx =
      let call_create =
        Eth_cli.contract_send
          ~source_private_key:sender.private_key
          ~endpoint
          ~abi_label:timestamp.label
          ~address:timestamp_address
          ~method_call:(Printf.sprintf "setTimestamp()")
      in
      wait_for_application ~evm_node ~sc_rollup_node ~client call_create
    in

    let* saved_timestamp =
      Eth_cli.contract_call
        ~endpoint
        ~abi_label:timestamp.label
        ~address:timestamp_address
        ~method_call:(Printf.sprintf "getSavedTimestamp()")
        ()
    in
    let saved_timestamp = Int64.of_string (String.trim saved_timestamp) in

    (* This call being done after saving the timestamp, it should be higher. *)
    let* simulated_timestamp =
      Eth_cli.contract_call
        ~endpoint
        ~abi_label:timestamp.label
        ~address:timestamp_address
        ~method_call:(Printf.sprintf "getTimestamp()")
        ()
    in
    let simulated_timestamp =
      Int64.of_string (String.trim simulated_timestamp)
    in

    let* () = check_tx_succeeded ~endpoint ~tx:set_timestamp_tx in
    Check.(
      (saved_timestamp < simulated_timestamp)
        int64
        ~error_msg:
          "Simulated timestamp (%R) should be higher than the one saved from a \
           previous block (%L)") ;
    unit
  in
  register_both
    ~tags:["evm"; "timestamp"; "opcode"]
    ~title:"Check L2 opcode timestamp"
    test

let test_migrate_proxy_to_sequencer_future =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "rollup_node"; "init"; "migration"; "sequencer"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:
      "migrate from proxy to sequencer using a sequencer admin contract with a \
       future timestamp"
  @@ fun protocol ->
  let genesis_timestamp =
    Client.(At (Time.of_notation_exn "2020-01-01T00:00:00Z"))
  in
  (* 1s per block, 10 block. *)
  let activation_timestamp = "2020-01-01T00:00:10Z" in
  let sequencer_admin = Constant.bootstrap5 in
  let sequencer_key = Constant.bootstrap4 in
  let* ({
          evm_node = proxy_node;
          sc_rollup_node;
          client;
          kernel;
          sc_rollup_address;
          l1_contracts;
          _;
        } as full_evm_setup) =
    setup_evm_kernel
      ~timestamp:genesis_timestamp
      ~sequencer_admin
      ~admin:(Some Constant.bootstrap3)
      protocol
  in
  (* Send a transaction in proxy mode. *)
  let* () =
    let sender = Eth_account.bootstrap_accounts.(0) in
    let receiver = Eth_account.bootstrap_accounts.(1) in
    let* tx = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
    check_tx_succeeded ~endpoint:(Evm_node.endpoint proxy_node) ~tx
  in
  (* Send the internal message to add a sequencer on the rollup. *)
  let sequencer_governance_contract =
    match
      Option.bind l1_contracts (fun {sequencer_governance; _} ->
          sequencer_governance)
    with
    | Some contract -> contract
    | None -> Test.fail "missing sequencer admin contract"
  in
  let* () =
    sequencer_upgrade
      ~sc_rollup_address
      ~sequencer_admin:sequencer_admin.alias
      ~sequencer_governance_contract
      ~client
      ~upgrade_to:sequencer_key.alias
      ~activation_timestamp
      ~pool_address:Eth_account.bootstrap_accounts.(0).address
  in
  let sequencer_node =
    let mode =
      Evm_node.Sequencer
        {
          initial_kernel = kernel;
          preimage_dir = Sc_rollup_node.data_dir sc_rollup_node // "wasm_2_0_0";
          private_rpc_port = Some (Port.fresh ());
          time_between_blocks = Some Nothing;
          sequencer = sequencer_key.alias;
          genesis_timestamp = None;
          max_blueprints_lag = None;
          max_blueprints_ahead = None;
          max_blueprints_catchup = None;
          catchup_cooldown = None;
          max_number_of_chunks = None;
          devmode = true;
          wallet_dir = Some (Client.base_dir client);
          tx_pool_timeout_limit = None;
          tx_pool_addr_limit = None;
          tx_pool_tx_per_addr_limit = None;
        }
    in
    Evm_node.create ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let* () =
    repeat 10 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  (* Run the sequencer from the rollup node state. *)
  let* () =
    Evm_node.init_from_rollup_node_data_dir
      ~devmode:true
      sequencer_node
      sc_rollup_node
  in
  let* () = Evm_node.run sequencer_node in
  (* Same head after initialisation. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in
  (* Produce a block in sequencer. *)
  let*@ _ = Rpc.produce_block sequencer_node in
  let* () =
    bake_until_sync
      ~sc_rollup_node
      ~client
      ~sequencer:sequencer_node
      ~proxy:proxy_node
      ()
  in
  (* Same head after first sequencer produced block. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in

  (* Send a transaction to sequencer. *)
  let* () =
    let sender = Eth_account.bootstrap_accounts.(0) in
    let receiver = Eth_account.bootstrap_accounts.(1) in
    let full_evm_setup = {full_evm_setup with evm_node = sequencer_node} in
    let* tx = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
    check_tx_succeeded ~endpoint:(Evm_node.endpoint sequencer_node) ~tx
  in
  let* () =
    bake_until_sync
      ~sc_rollup_node
      ~client
      ~sequencer:sequencer_node
      ~proxy:proxy_node
      ()
  in
  (* Same head after sequencer transaction. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in
  unit

let test_migrate_proxy_to_sequencer_past =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "rollup_node"; "init"; "migration"; "sequencer"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:
      "migrate from proxy to sequencer using a sequencer admin contract with a \
       past timestamp"
  @@ fun protocol ->
  let sequencer_admin = Constant.bootstrap5 in
  let sequencer_key = Constant.bootstrap4 in
  let* ({
          evm_node = proxy_node;
          sc_rollup_node;
          client;
          kernel;
          sc_rollup_address;
          l1_contracts;
          _;
        } as full_evm_setup) =
    setup_evm_kernel ~sequencer_admin ~admin:(Some Constant.bootstrap3) protocol
  in
  (* Send a transaction in proxy mode. *)
  let* () =
    let sender = Eth_account.bootstrap_accounts.(0) in
    let receiver = Eth_account.bootstrap_accounts.(1) in
    let* tx = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
    check_tx_succeeded ~endpoint:(Evm_node.endpoint proxy_node) ~tx
  in
  (* Send the internal message to add a sequencer on the rollup. *)
  let sequencer_governance_contract =
    match
      Option.bind l1_contracts (fun {sequencer_governance; _} ->
          sequencer_governance)
    with
    | Some contract -> contract
    | None -> Test.fail "missing sequencer admin contract"
  in
  let* () =
    sequencer_upgrade
      ~sc_rollup_address
      ~sequencer_admin:sequencer_admin.alias
      ~sequencer_governance_contract
      ~client
      ~upgrade_to:sequencer_key.alias
      ~activation_timestamp:"0"
      ~pool_address:Eth_account.bootstrap_accounts.(0).address
  in
  let* () =
    (* We need to bake 3 blocks, because otherwise the sequencer upgrade event
       is re-received by the EVM node. This is because `init from rollup node`
       reads the HEAD context of the rollup node, but the EVM node interacts
       with the rollup node two blocks in the past. As a consequence, without
       baking these blocks, the EVM node will virtually handle the sequencer
       upgrade event twice.

       However, the EVM node does not deal with sequencer event gracefully
       right now. It works for preventing the old sequencer to produce
       blueprints, but not for the new sequencer to start producing blueprints.

       This is because of the blueprint deletion mechanism of the kernel.
       When the sequencer upgrade is applied at the end of stage-1, the
       pending blueprints are deleted. This means the bluperint currently
       applied in `apply_blueprint` is deleted, meaning nothing is executed
       in the stage-2. *)
    repeat 3 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let sequencer_node =
    let mode =
      Evm_node.Sequencer
        {
          initial_kernel = kernel;
          preimage_dir = Sc_rollup_node.data_dir sc_rollup_node // "wasm_2_0_0";
          private_rpc_port = Some (Port.fresh ());
          time_between_blocks = Some Nothing;
          sequencer = sequencer_key.alias;
          genesis_timestamp = None;
          max_blueprints_lag = None;
          max_blueprints_ahead = None;
          max_blueprints_catchup = None;
          catchup_cooldown = None;
          max_number_of_chunks = None;
          devmode = true;
          wallet_dir = Some (Client.base_dir client);
          tx_pool_timeout_limit = None;
          tx_pool_addr_limit = None;
          tx_pool_tx_per_addr_limit = None;
        }
    in
    Evm_node.create ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in
  (* Run the sequencer from the rollup node state. *)
  let* () =
    Evm_node.init_from_rollup_node_data_dir
      ~devmode:true
      sequencer_node
      sc_rollup_node
  in
  let* () = Evm_node.run sequencer_node in
  (* Same head after initialisation. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in

  (* Produce a block in sequencer. *)
  let*@ _ = Rpc.produce_block sequencer_node in
  let* () =
    bake_until_sync
      ~sc_rollup_node
      ~client
      ~sequencer:sequencer_node
      ~proxy:proxy_node
      ()
  in
  (* Same head after first sequencer produced block. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in

  (* Send a transaction to sequencer. *)
  let* () =
    let sender = Eth_account.bootstrap_accounts.(0) in
    let receiver = Eth_account.bootstrap_accounts.(1) in
    let full_evm_setup = {full_evm_setup with evm_node = sequencer_node} in
    let* tx = send ~sender ~receiver ~value:Wei.one_eth full_evm_setup in
    check_tx_succeeded ~endpoint:(Evm_node.endpoint sequencer_node) ~tx
  in
  let* () =
    bake_until_sync
      ~sc_rollup_node
      ~client
      ~sequencer:sequencer_node
      ~proxy:proxy_node
      ()
  in
  (* Same head after sequencer transaction. *)
  let* () =
    check_head_consistency
      ~left:sequencer_node
      ~right:proxy_node
      ~error_msg:"block hash is not equal (sequencer: %L; rollup: %R)"
      ()
  in

  unit

let test_ghostnet_kernel =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "ghostnet"; "version"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_evm_node;
        Constant.octez_smart_rollup_node;
        Constant.smart_rollup_installer;
        Constant.WASM.ghostnet_evm_kernel;
      ])
    ~title:"Regression test for Ghostnet kernel"
  @@ fun protocol ->
  let* {evm_node; _} =
    setup_evm_kernel
      ~kernel_installee:Constant.WASM.ghostnet_evm_kernel
      ~admin:None
      protocol
  in
  let*@ version = Rpc.tez_kernelVersion evm_node in
  Check.((version = Constant.WASM.ghostnet_evm_commit) string)
    ~error_msg:"The ghostnet kernel has version %L but constant says %R" ;
  unit

let test_estimate_gas_out_of_ticks =
  register_both
    ~tags:["evm"; "estimate_gas"; "out_of_ticks"; "simulate"]
    ~title:"estimateGas works with out of ticks"
  @@ fun ~protocol:_ ~evm_setup:({evm_node; _} as evm_setup) ->
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* loop_address, _tx = deploy ~contract:loop ~sender evm_setup in
  (* Call estimateGas with an out of ticks transaction. *)
  let estimateGas =
    [
      ("from", `String sender.address);
      (* The data payload was retrieved by calling `loop(100000)` and reversed
         engineer the data field. *)
      ( "data",
        `String
          "0x0b7d796e00000000000000000000000000000000000000000000000000000000000186a0"
      );
      ("to", `String loop_address);
    ]
  in
  let*@? {message; code = _; data = _} =
    Rpc.estimate_gas estimateGas evm_node
  in
  Check.(message =~ rex "The transaction would exhaust all the ticks")
    ~error_msg:"The estimate gas should fail with out of ticks message." ;
  unit

let test_l2_call_selfdetruct_contract_in_same_transaction =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "l2_call"; "selfdestrcut"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Check destruct contract in same transaction can be called"
  @@ fun protocol ->
  let* ({evm_node; sc_rollup_node; client; _} as evm_setup) =
    setup_evm_kernel ~admin:None protocol
  in
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* _address, _tx = deploy ~contract:call_selfdestruct ~sender evm_setup in
  unit

let test_call_recursive_contract_estimate_gas =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "l2_call"; "estimate_gas"; "recursive"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Check recursive contract gasLimit is high enough"
  @@ fun protocol ->
  let* ({endpoint; sc_rollup_node; client; evm_node; _} as evm_setup) =
    setup_evm_kernel ~admin:None protocol
  in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* recursive_address, _tx = deploy ~contract:recursive ~sender evm_setup in
  let call () =
    Eth_cli.contract_send
      ~source_private_key:sender.private_key
      ~endpoint
      ~abi_label:recursive.label
      ~address:recursive_address
      ~method_call:"call(40)"
      ()
  in
  let* tx = wait_for_application ~evm_node ~sc_rollup_node ~client call in
  let* () = check_tx_succeeded ~endpoint ~tx in
  unit

let test_transaction_exhausting_ticks_is_rejected =
  register_both
    ~tags:["evm"; "loop"; "out_of_ticks"; "rejected"]
    ~title:
      "Check that the node will reject a transaction that wouldn't fit in a \
       kernel run."
    ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
  @@ fun ~protocol:_ ~evm_setup:{evm_node; sc_rollup_node; client; _} ->
  (* Retrieves all the messages and prepare them for the current rollup. *)
  let txs =
    read_file (kernel_inputs_path ^ "/loops-exhaust-ticks")
    |> String.trim |> String.split_on_char '\n'
  in
  (* The first three transactions are sent in a separate block, to handle any nonce issue. *)
  let first_block, second_block, third_block, loop_out_of_ticks =
    match txs with
    | [faucet1; faucet2; create; loop_out_of_ticks] ->
        ([faucet1], [faucet2], [create], loop_out_of_ticks)
    | _ -> failwith "The prepared transactions should contain 4 transactions"
  in
  let* () =
    Lwt_list.iter_s
      (fun block ->
        let* _requests, _receipt, _hashes =
          send_n_transactions
            ~sc_rollup_node
            ~client
            ~evm_node
            ~wait_for_blocks:5
            block
        in
        unit)
      [first_block; second_block; third_block]
  in
  let* result = Rpc.send_raw_transaction ~raw_tx:loop_out_of_ticks evm_node in
  (match result with
  | Ok _ -> Test.fail "The transaction should have been rejected by the node"
  | Error _ -> ()) ;
  unit

let test_reveal_storage =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "reveal_storage"]
    ~title:"Reveal storage"
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
  @@ fun protocol ->
  (* Start a regular rollup. *)
  let* {evm_node; sc_rollup_node; client; _} =
    setup_evm_kernel ~admin:None protocol
  in
  let* () =
    repeat 6 (fun _ -> next_evm_level ~evm_node ~sc_rollup_node ~client)
  in
  let*@ first_rollup_head = Rpc.get_block_by_number ~block:"latest" evm_node in

  (* Dump the storage of the smart rollup node and convert it into a RLP file
     the kernel can read. *)
  let dump_json = Temp.file "dump.json" in
  let dump_rlp = Temp.file "dump.rlp" in
  let* () =
    Sc_rollup_node.dump_durable_storage ~sc_rollup_node ~dump:dump_json ()
  in
  let* () = Evm_node.transform_dump ~dump_json ~dump_rlp in

  (* Get root hash of the storage configuration *)
  let config_preimages_dir = Temp.dir "config_preimages" in
  let* {root_hash = configuration_root_hash; _} =
    prepare_installer_kernel_with_arbitrary_file
      ~preimages_dir:config_preimages_dir
      dump_rlp
  in

  (* Start a new EVM rollup chain, but this time, with a ad-hoc config that
     allows to duplicate the state of the previous one.

     The only way for this new rollup to see initialized balances is for the
     duplication process to work. *)
  let config =
    `Config
      Sc_rollup_helpers.Installer_kernel_config.
        [
          Reveal
            {
              hash = configuration_root_hash;
              to_ = Durable_storage_path.reveal_config;
            };
        ]
  in

  (* Setup the new rollup, but do not force the installation of the kernel as
     we need to setup the preimage directory first. *)
  let* {evm_node; sc_rollup_node; client; _} =
    setup_evm_kernel
      ~admin:None
      ~config
      ~force_install_kernel:false
      ~bootstrap_accounts:[||]
      protocol
  in

  (* Copy the config preimages directory contents into the preimages directory
     of the new rollup node. *)
  let* _ =
    Lwt_unix.system
      Format.(
        sprintf
          "cp %s/* %s"
          config_preimages_dir
          (Sc_rollup_node.data_dir sc_rollup_node // "wasm_2_0_0"))
  in

  (* Force the installation of the kernel of the new chain *)
  let* _ = next_evm_level ~evm_node ~client ~sc_rollup_node in

  (* Check the head. We produced one additional head with the bake above. *)
  let*@ copied_rollup_head =
    Rpc.get_block_by_number
      ~block:(first_rollup_head.number |> Int32.to_string)
      evm_node
  in
  Check.((copied_rollup_head.hash = first_rollup_head.hash) string)
    ~error_msg:"Head should be the same in the copy" ;
  unit

let call_get_hash ~address ~block_number
    {sc_rollup_node; client; endpoint; evm_node; _} =
  let call_get_hash block_number =
    Eth_cli.contract_call
      ~endpoint
      ~abi_label:blockhash.label
      ~address
      ~method_call:(Printf.sprintf "getHash(%d)" block_number)
  in
  wait_for_application
    ~evm_node
    ~sc_rollup_node
    ~client
    (call_get_hash block_number)

let test_blockhash_opcode =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "blockhash"; "opcode"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Check if blockhash opcode returns the actual hash of the block"
  @@ fun protocol ->
  let* ({evm_node; sc_rollup_node; client; endpoint; _} as evm_setup) =
    setup_evm_kernel ~admin:None protocol
  in
  let* () =
    repeat 3 (fun () -> next_evm_level ~evm_node ~client ~sc_rollup_node)
  in
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* address, tx = deploy ~contract:blockhash ~sender evm_setup in
  let* () = check_tx_succeeded ~endpoint ~tx in
  let* expected_block_hash =
    let* block = Eth_cli.get_block ~block_id:"2" ~endpoint in
    return block.hash
  in
  (* The client's response is read from stdout, we have to remove the new line
     symbol. *)
  let* block_hash =
    call_get_hash ~address ~block_number:2 evm_setup
    |> Lwt.map (fun s -> String.sub s 0 (String.length s - 1))
  in
  Check.((block_hash = expected_block_hash) string)
    ~error_msg:
      "The block hash should be the same when called from an RPC and return by \
       the BLOCKHASH opcode, got %L, but %R was expected." ;
  unit

let test_revert_is_correctly_propagated =
  register_both
    ~tags:["evm"; "revert"]
    ~title:"Check that the node propagates reverts reason correctly."
  @@ fun ~protocol:_ ~evm_setup:({evm_node; _} as evm_setup) ->
  let sender = Eth_account.bootstrap_accounts.(0) in
  let* error_address, _tx = deploy ~contract:error ~sender evm_setup in
  let* data =
    Eth_cli.encode_method ~abi_label:error.label ~method_:"testRevert(0)"
  in
  let* call = Rpc.call ~to_:error_address ~data evm_node in
  match call with
  | Ok _ -> Test.fail "Call should have reverted"
  | Error {data = None; _} ->
      Test.fail "Call should have reverted with a reason"
  | Error {data = Some _reason; _} ->
      (* TODO: #6893
         eth-cli cannot decode an encoded string using Ethereum format. *)
      unit

(** Test that the kernel can handle more than 100 withdrawals withdrawals
    per level, which is currently the limit of outbox messages in the L1. *)
let test_outbox_size_limit_resilience ~slow =
  let admin = Constant.bootstrap5 in
  let commitment_period = 5 and challenge_window = 5 in
  let slow_str = if slow then "slow" else "fast" in
  register_proxy
    ~tags:(["evm"; "withdraw"; "outbox"] @ if slow then [Tag.slow] else [])
    ~title:(sf "Outbox size limit resilience (%s)" slow_str)
    ~admin:(Some admin)
    ~commitment_period
    ~challenge_window
  @@ fun ~protocol:_ ~evm_setup ->
  let {
    evm_node;
    sc_rollup_node;
    client;
    endpoint;
    sc_rollup_address;
    l1_contracts;
    _;
  } =
    evm_setup
  in
  (* Deposit tickets to the rollup to perform the withdrawals. *)
  let* () =
    let bridge =
      let l1_contracts = Option.get l1_contracts in
      l1_contracts.bridge
    in
    Client.transfer
      ~entrypoint:"deposit"
      ~arg:
        (sf
           "Pair %S 0x1074Fd1EC02cbeaa5A90450505cF3B48D834f3EB"
           sc_rollup_address)
      ~amount:(Tez.of_int 1000)
      ~giver:Constant.bootstrap5.public_key_hash
      ~receiver:bridge
      ~burn_cap:Tez.one
      client
  in
  let* _ = next_evm_level ~evm_node ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0) in
  (* Deploy the spam contract. *)
  let* contract, _tx = deploy ~contract:spam_withdrawal ~sender evm_setup in

  (* Start by giving funds to the contract. This cannot be done in one go
     because the stupid [eth-cli] doesn't include the transfer in gas
     estimation, which makes the next call fail. *)
  let* _tx_give_fund =
    let give_funds () =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:spam_withdrawal.label
        ~address:contract
        ~method_call:"giveFunds()"
        ~value:(Wei.of_eth_int 200)
    in
    wait_for_application ~evm_node ~sc_rollup_node ~client (give_funds ())
  in

  let* withdrawal_level = Client.level client in

  (* Produce 120 withdrawals by calling the spam entrypoint. *)
  let* do_withdrawals =
    let do_withdrawals () =
      Eth_cli.contract_send
        ~source_private_key:sender.private_key
        ~endpoint
        ~abi_label:spam_withdrawal.label
        ~address:contract
        ~method_call:"doWithdrawals(120)"
        ~value:(Wei.of_eth_int 200)
    in
    wait_for_application ~evm_node ~sc_rollup_node ~client (do_withdrawals ())
  in
  (* The transaction tries to do more than 100 outbox messages in a Tezos level.
     If the kernel is not smart about it, it will hard fail and revert its state.
     Therefore checking if the transaction is a success is a good indicator
     of the correct behavior. *)
  let* () = check_tx_succeeded ~endpoint ~tx:do_withdrawals in

  if slow then (
    (* Execute the first 100 withdrawals *)
    let* actual_withdrawal_level =
      find_and_execute_withdrawal
        ~withdrawal_level
        ~commitment_period
        ~challenge_window
        ~evm_node
        ~sc_rollup_node
        ~sc_rollup_address
        ~client
    in
    let* balance =
      Client.get_balance_for
        ~account:"tz1WrbkDrzKVqcGXkjw4Qk4fXkjXpAJuNP1j"
        client
    in
    Check.((balance = Tez.of_int 100) Tez.typ)
      ~error_msg:"Expected balance of %R, got %L" ;
    (* Execute the next 20 withdrawals *)
    let* _ =
      find_and_execute_withdrawal
        ~withdrawal_level:(actual_withdrawal_level + 1)
        ~commitment_period
        ~challenge_window
        ~evm_node
        ~sc_rollup_node
        ~sc_rollup_address
        ~client
    in
    let* balance =
      Client.get_balance_for
        ~account:"tz1WrbkDrzKVqcGXkjw4Qk4fXkjXpAJuNP1j"
        client
    in
    Check.((balance = Tez.of_int 120) Tez.typ)
      ~error_msg:"Expected balance of %R, got %L" ;
    unit)
  else unit

let test_tx_pool_timeout =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "tx_pool"; "timeout"]
    ~title:"Check that transactions correctly timeout."
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
  @@ fun protocol ->
  let sequencer_admin = Constant.bootstrap1 in
  let admin = Some Constant.bootstrap3 in
  let setup_mode =
    Setup_sequencer
      {
        time_between_blocks = Some Nothing;
        sequencer = sequencer_admin;
        devmode = true;
      }
  in
  let ttl = 15 in
  let* {evm_node = sequencer_node; _} =
    setup_evm_kernel
      ~sequencer_admin
      ~admin
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      ~tx_pool_timeout_limit:ttl
      ~setup_mode
      protocol
  in
  (* We send one transaction and produce a block immediatly to check that it's included
     as it should (within the TTL that was set). *)
  let tx =
    (* {  "chainId": "1337",
          "type": "LegacyTransaction",
          "valid": true,
          "hash": "0xb941cbf32821471381b6f003f9013b95c788ad24260d2af54848a5b504c09bb0",
          "nonce": "0",
          "gasPrice": "21000",
          "gasLimit": "2000000",
          "from": "0x6ce4d79d4E77402e1ef3417Fdda433aA744C6e1c",
          "to": "0x6ce4d79d4e77402e1ef3417fdda433aa744c6e1c",
          "v": "0a95",
          "r": "964f3d64696410dc1054af0aca06d5a4005a3bdf3db0b919e3de207af93e1004",
          "s": "3eb79935b4e15a576955c104fd6a614437dd0464d382198dde4c52a8eed4061a",
          "value": "0" } *)
    "f86480825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a0964f3d64696410dc1054af0aca06d5a4005a3bdf3db0b919e3de207af93e1004a03eb79935b4e15a576955c104fd6a614437dd0464d382198dde4c52a8eed4061a"
  in
  let*@ tx_hash_expected = Rpc.send_raw_transaction ~raw_tx:tx sequencer_node in
  let*@ block_number = Rpc.produce_block sequencer_node in
  let*@ block =
    Rpc.get_block_by_number ~block:(Int.to_string block_number) sequencer_node
  in
  let tx_hash =
    match block.transactions with
    | Hash txs -> List.hd txs
    | Empty ->
        Test.fail
          "Inspected block should contain a list of one transaction hash and \
           not be empty."
    | Full _ ->
        Test.fail
          "Inspected block should contain a list of one transaction hash, not \
           full objects."
  in
  Check.((tx_hash = tx_hash_expected) string)
    ~error_msg:"Expected transaction hash is %R, got %L" ;
  (* We send one transaction and produce a block after the TTL to check that the
     produced block is empty. *)
  let tx' =
    (* {  "chainId": "1337",
          "type": "LegacyTransaction",
          "valid": true,
          "hash": "0x51a24a5cf2eb3095f522e4c500b1bf5b0de6476f04a108ea1005cfef7ceec750",
          "nonce": "1",
          "gasPrice": "21000",
          "gasLimit": "2000000",
          "from": "0x6ce4d79d4E77402e1ef3417Fdda433aA744C6e1c",
          "to": "0x6ce4d79d4e77402e1ef3417fdda433aa744c6e1c",
          "v": "0a95",
          "r": "7298a47ad7fcbe70dc9d3705af6e47147364c5ac8ede95fb561ffaa3443dd776",
          "s": "7042e72941ffdef02c773b7289d7e4241a5c819e78c7bfb362c7f151b0ba3e9e",
          "value": "0" } *)
    "f86401825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a07298a47ad7fcbe70dc9d3705af6e47147364c5ac8ede95fb561ffaa3443dd776a07042e72941ffdef02c773b7289d7e4241a5c819e78c7bfb362c7f151b0ba3e9e"
  in
  let*@ _tx_hash' = Rpc.send_raw_transaction ~raw_tx:tx' sequencer_node in
  let* () = Lwt_unix.sleep (Int.to_float ttl *. 1.5) in
  let*@ block_number = Rpc.produce_block sequencer_node in
  let*@ block =
    Rpc.get_block_by_number ~block:(Int.to_string block_number) sequencer_node
  in
  match block.transactions with
  | Empty -> unit
  | _ -> Test.fail "Inspected block shoud be empty."

let test_tx_pool_address_boundaries =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "tx_pool"; "address"; "boundaries"]
    ~title:
      "Check that the boundaries set for the transaction pool are properly \
       behaving."
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
  @@ fun protocol ->
  let sequencer_admin = Constant.bootstrap1 in
  let admin = Some Constant.bootstrap3 in
  let setup_mode =
    Setup_sequencer
      {
        time_between_blocks = Some Nothing;
        sequencer = sequencer_admin;
        devmode = true;
      }
  in
  let* {evm_node = sequencer_node; _} =
    setup_evm_kernel
      ~sequencer_admin
      ~admin
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      ~tx_pool_addr_limit:1
      ~tx_pool_tx_per_addr_limit:1
      ~setup_mode
      protocol
  in
  let tx =
    (* { "chainId": "1337",
          "type": "LegacyTransaction",
          "valid": true,
          "hash": "0xb941cbf32821471381b6f003f9013b95c788ad24260d2af54848a5b504c09bb0",
          "nonce": "0",
          "gasPrice": "21000",
          "gasLimit": "2000000",
          "from": "0x6ce4d79d4E77402e1ef3417Fdda433aA744C6e1c",
          "to": "0x6ce4d79d4e77402e1ef3417fdda433aa744c6e1c",
          "v": "0a95",
          "r": "964f3d64696410dc1054af0aca06d5a4005a3bdf3db0b919e3de207af93e1004",
          "s": "3eb79935b4e15a576955c104fd6a614437dd0464d382198dde4c52a8eed4061a",
          "value": "0" } *)
    "f86480825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a0964f3d64696410dc1054af0aca06d5a4005a3bdf3db0b919e3de207af93e1004a03eb79935b4e15a576955c104fd6a614437dd0464d382198dde4c52a8eed4061a"
  in
  let tx' =
    (* { "chainId": "1337",
         "type": "LegacyTransaction",
         "valid": true,
         "hash": "0x51a24a5cf2eb3095f522e4c500b1bf5b0de6476f04a108ea1005cfef7ceec750",
         "nonce": "1",
         "gasPrice": "21000",
         "gasLimit": "2000000",
         "from": "0x6ce4d79d4E77402e1ef3417Fdda433aA744C6e1c",
         "to": "0x6ce4d79d4e77402e1ef3417fdda433aa744c6e1c",
         "v": "0a95",
         "r": "7298a47ad7fcbe70dc9d3705af6e47147364c5ac8ede95fb561ffaa3443dd776",
         "s": "7042e72941ffdef02c773b7289d7e4241a5c819e78c7bfb362c7f151b0ba3e9e",
         "value": "0" } *)
    "f86401825208831e8480946ce4d79d4e77402e1ef3417fdda433aa744c6e1c8080820a95a07298a47ad7fcbe70dc9d3705af6e47147364c5ac8ede95fb561ffaa3443dd776a07042e72941ffdef02c773b7289d7e4241a5c819e78c7bfb362c7f151b0ba3e9e"
  in
  let tx'' =
    (* { "chainId": "1337",
         "type": "LegacyTransaction",
         "valid": true,
         "hash": "0x25a2f2e9c1cadada66ce255e609c0ace80435b0b595371a5da2bb104757e6ade",
         "nonce": "0",
         "gasPrice": "21000",
         "gasLimit": "23300",
         "from": "0xB53dc01974176E5dFf2298C5a94343c2585E3c54",
         "to": "0xb53dc01974176e5dff2298c5a94343c2585e3c54",
         "v": "0a95",
         "r": "9bc3d2c48b9d3db98b277ddb804941deeb899d65b2a22c76600810270d1bcfcf",
         "s": "5a3c7ead9bbf152acd4f7ea01a4cec70c921cde466840a9bdad4c2d8939963ef",
         "value": "100000" } *)
    "f86680825208825b0494b53dc01974176e5dff2298c5a94343c2585e3c54830186a080820a95a09bc3d2c48b9d3db98b277ddb804941deeb899d65b2a22c76600810270d1bcfcfa05a3c7ead9bbf152acd4f7ea01a4cec70c921cde466840a9bdad4c2d8939963ef"
  in
  let*@ tx_hash_expected = Rpc.send_raw_transaction ~raw_tx:tx sequencer_node in
  (* Limitation on the number of transaction per address *)
  let*@? rejected_transaction' =
    Rpc.send_raw_transaction ~raw_tx:tx' sequencer_node
  in
  Check.(
    (rejected_transaction'.message
   = "Limit of transaction for a user was reached. Transaction is rejected.")
      string)
    ~error_msg:"This transaction should be rejected with error msg %R not %L" ;
  (* Limitation on the number of allowed address inside the transaction pool *)
  let*@? rejected_transaction'' =
    Rpc.send_raw_transaction ~raw_tx:tx'' sequencer_node
  in
  Check.(
    (rejected_transaction''.message
   = "The transaction pool has reached its maximum threshold for user \
      transactions. Transaction is rejected.")
      string)
    ~error_msg:"This transaction should be rejected with error msg %R not %L" ;
  let*@ block_number = Rpc.produce_block sequencer_node in
  let*@ block =
    Rpc.get_block_by_number ~block:(Int.to_string block_number) sequencer_node
  in
  let tx_hash =
    match block.transactions with
    | Hash txs -> List.hd txs
    | Empty ->
        Test.fail
          "Inspected block should contain a list of one transaction hash and \
           not be empty."
    | Full _ ->
        Test.fail
          "Inspected block should contain a list of one transaction hash, not \
           full objects."
  in
  Check.((tx_hash = tx_hash_expected) string)
    ~error_msg:"Expected transaction hash is %R, got %L" ;
  unit

let register_evm_node ~protocols =
  test_originate_evm_kernel protocols ;
  test_kernel_root_hash_originate_absent protocols ;
  test_kernel_root_hash_originate_present protocols ;
  test_kernel_root_hash_after_upgrade protocols ;
  test_evm_node_connection protocols ;
  test_consistent_block_hashes protocols ;
  test_rpc_getBalance protocols ;
  test_rpc_getCode protocols ;
  test_rpc_blockNumber protocols ;
  test_rpc_net_version protocols ;
  test_rpc_getBlockByNumber protocols ;
  test_rpc_getBlockByHash protocols ;
  test_rpc_getTransactionCount protocols ;
  test_rpc_getTransactionCountBatch protocols ;
  test_rpc_batch protocols ;
  test_l2_block_size_non_zero protocols ;
  test_l2_blocks_progression protocols ;
  test_l2_transfer protocols ;
  test_chunked_transaction protocols ;
  test_rpc_txpool_content protocols ;
  test_rpc_web3_clientVersion protocols ;
  test_rpc_web3_sha3 protocols ;
  test_simulate protocols ;
  test_full_blocks protocols ;
  test_latest_block protocols ;
  test_eth_call_nullable_recipient protocols ;
  test_l2_deploy_simple_storage protocols ;
  test_l2_call_simple_storage protocols ;
  test_l2_deploy_erc20 protocols ;
  test_deploy_contract_for_shanghai protocols ;
  test_inject_100_transactions protocols ;
  test_eth_call_storage_contract protocols ;
  test_eth_call_storage_contract_eth_cli protocols ;
  test_eth_call_large protocols ;
  test_preinitialized_evm_kernel protocols ;
  test_deposit_and_withdraw protocols ;
  test_estimate_gas protocols ;
  test_estimate_gas_additionnal_field protocols ;
  test_kernel_upgrade_epoch protocols ;
  test_kernel_upgrade_delay protocols ;
  test_kernel_upgrade_evm_to_evm protocols ;
  test_kernel_upgrade_wrong_key protocols ;
  test_kernel_upgrade_wrong_rollup_address protocols ;
  test_kernel_upgrade_no_administrator protocols ;
  test_kernel_upgrade_failing_migration protocols ;
  test_kernel_upgrade_version_change protocols ;
  test_kernel_upgrade_via_governance protocols ;
  test_kernel_upgrade_via_kernel_security_governance protocols ;
  test_rpc_sendRawTransaction protocols ;
  test_deposit_dailynet protocols ;
  test_cannot_prepayed_leads_to_no_inclusion protocols ;
  test_cannot_prepayed_with_delay_leads_to_no_injection protocols ;
  test_rpc_sendRawTransaction_nonce_too_low protocols ;
  test_rpc_sendRawTransaction_nonce_too_high protocols ;
  test_rpc_sendRawTransaction_invalid_chain_id protocols ;
  test_rpc_getTransactionByBlockHashAndIndex protocols ;
  test_rpc_getTransactionByBlockNumberAndIndex protocols ;
  test_rpc_getTransactionByHash protocols ;
  test_rpc_getBlockTransactionCountBy protocols ;
  test_rpc_getUncleCountByBlock protocols ;
  test_rpc_getUncleByBlockArgAndIndex protocols ;
  test_simulation_eip2200 protocols ;
  test_rpc_gasPrice protocols ;
  test_rpc_getStorageAt protocols ;
  test_accounts_double_indexing protocols ;
  test_rpc_sendRawTransaction_with_consecutive_nonce protocols ;
  test_rpc_sendRawTransaction_not_included protocols ;
  test_originate_evm_kernel_and_dump_pvm_state protocols ;
  test_l2_call_inter_contract protocols ;
  test_rpc_getLogs protocols ;
  test_log_index protocols ;
  test_tx_pool_replacing_transactions protocols ;
  test_l2_nested_create protocols ;
  test_block_hash_regression protocols ;
  test_l2_revert_returns_unused_gas protocols ;
  test_l2_create_collision protocols ;
  test_l2_intermediate_OOG_call protocols ;
  test_l2_ether_wallet protocols ;
  test_keep_alive protocols ;
  test_regression_block_hash_gen protocols ;
  test_reboot_out_of_ticks protocols ;
  test_l2_timestamp_opcode protocols ;
  test_migrate_proxy_to_sequencer_past protocols ;
  test_migrate_proxy_to_sequencer_future protocols ;
  test_ghostnet_kernel protocols ;
  test_estimate_gas_out_of_ticks protocols ;
  test_l2_call_selfdetruct_contract_in_same_transaction protocols ;
  test_transaction_exhausting_ticks_is_rejected protocols ;
  test_reveal_storage protocols ;
  test_call_recursive_contract_estimate_gas protocols ;
  test_blockhash_opcode protocols ;
  test_revert_is_correctly_propagated protocols ;
  test_outbox_size_limit_resilience ~slow:true protocols ;
  test_outbox_size_limit_resilience ~slow:false protocols ;
  test_tx_pool_timeout protocols ;
  test_tx_pool_address_boundaries protocols

let protocols = Protocol.all

let () =
  register_evm_node ~protocols ;
  register_evm_migration ~protocols
