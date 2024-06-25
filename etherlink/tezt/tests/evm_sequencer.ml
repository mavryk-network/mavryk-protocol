(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2024 Trilitech <contact@trili.tech>                         *)
(* Copyright (c) 2024 Functori <contact@functori.com>                        *)
(*                                                                           *)
(*****************************************************************************)

(* Testing
   -------
   Component:    Smart Optimistic Rollups: Etherlink Sequencer
   Requirement:  make -f etherlink.mk build
                 npm install eth-cli
   Invocation:   dune exec etherlink/tezt/tests/main.exe -- --file evm_sequencer.ml
*)

open Sc_rollup_helpers
open Rpc.Syntax
open Contract_path

module Sequencer_rpc = struct
  let get_blueprint sequencer number =
    Runnable.run
    @@ Curl.get
         ~args:["--fail"]
         (Evm_node.endpoint sequencer
         ^ "/evm/blueprint/" ^ Int64.to_string number)

  let get_smart_rollup_address sequencer =
    let* res =
      Runnable.run
      @@ Curl.get
           ~args:["--fail"]
           (Evm_node.endpoint sequencer ^ "/evm/smart_rollup_address")
    in
    return (JSON.as_string res)
end

let uses _protocol =
  [
    Constant.octez_smart_rollup_node;
    Constant.octez_evm_node;
    Constant.smart_rollup_installer;
    Constant.WASM.evm_kernel;
  ]

open Helpers

let base_fee_for_hardcoded_tx = Wei.to_wei_z @@ Z.of_int 21000

let arb_da_fee_for_delayed_inbox = Wei.of_eth_int 10_000
(* da fee doesn't apply to delayed inbox, set it arbitrarily high
   to prove this *)

type l1_contracts = {
  delayed_transaction_bridge : string;
  exchanger : string;
  bridge : string;
  admin : string;
  sequencer_governance : string;
}

type sequencer_setup = {
  node : Node.t;
  client : Client.t;
  sc_rollup_address : string;
  sc_rollup_node : Sc_rollup_node.t;
  observer : Evm_node.t;
  sequencer : Evm_node.t;
  proxy : Evm_node.t;
  l1_contracts : l1_contracts;
}

let setup_l1_contracts ?(dictator = Constant.bootstrap2) client =
  (* Originates the delayed transaction bridge. *)
  let* delayed_transaction_bridge =
    Client.originate_contract
      ~alias:"evm-seq-delayed-bridge"
      ~amount:Tez.zero
      ~src:Constant.bootstrap1.public_key_hash
      ~prg:(delayed_path ())
      ~burn_cap:Tez.one
      client
  in
  let* () = Client.bake_for_and_wait ~keys:[] client in
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
  and* admin =
    Client.originate_contract
      ~alias:"evm-admin"
      ~amount:Tez.zero
      ~src:Constant.bootstrap3.public_key_hash
      ~init:(sf "%S" dictator.Account.public_key_hash)
      ~prg:(admin_path ())
      ~burn_cap:Tez.one
      client
    (* Originates the administrator contract. *)
  and* sequencer_governance =
    Client.originate_contract
      ~alias:"evm-sequencer-admin"
      ~amount:Tez.zero
      ~src:Constant.bootstrap4.public_key_hash
      ~init:(sf "%S" dictator.Account.public_key_hash)
      ~prg:(admin_path ())
      ~burn_cap:Tez.one
      client
  in
  let* () = Client.bake_for_and_wait ~keys:[] client in
  return
    {delayed_transaction_bridge; exchanger; bridge; admin; sequencer_governance}

let setup_sequencer ?(devmode = true) ?config ?genesis_timestamp
    ?time_between_blocks ?max_blueprints_lag ?max_blueprints_ahead
    ?max_blueprints_catchup ?catchup_cooldown ?delayed_inbox_timeout
    ?delayed_inbox_min_levels ?max_number_of_chunks
    ?(bootstrap_accounts = Eth_account.bootstrap_accounts)
    ?(sequencer = Constant.bootstrap1) ?sequencer_pool_address
    ?(kernel = Constant.WASM.evm_kernel) ?da_fee ?minimum_base_fee_per_gas
    ?preimages_dir protocol =
  let* node, client = setup_l1 ?timestamp:genesis_timestamp protocol in
  let* l1_contracts = setup_l1_contracts client in
  let sc_rollup_node =
    Sc_rollup_node.create
      ~default_operator:Constant.bootstrap1.public_key_hash
      Batcher
      node
      ~base_dir:(Client.base_dir client)
  in
  let preimages_dir =
    Option.value
      ~default:(Sc_rollup_node.data_dir sc_rollup_node // "wasm_2_0_0")
      preimages_dir
  in
  let base_config =
    Configuration.make_config
      ~bootstrap_accounts
      ~sequencer:sequencer.public_key
      ~delayed_bridge:l1_contracts.delayed_transaction_bridge
      ~ticketer:l1_contracts.exchanger
      ~administrator:l1_contracts.admin
      ~sequencer_governance:l1_contracts.sequencer_governance
      ?minimum_base_fee_per_gas
      ?da_fee_per_byte:da_fee
      ?delayed_inbox_timeout
      ?delayed_inbox_min_levels
      ?sequencer_pool_address
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
  let* {output; _} = prepare_installer_kernel ~preimages_dir ?config kernel in
  let* sc_rollup_address =
    originate_sc_rollup
      ~keys:[]
      ~kind:"wasm_2_0_0"
      ~boot_sector:("file:" ^ output)
      ~parameters_ty:Helpers.evm_type
      client
  in
  let* () =
    Sc_rollup_node.run sc_rollup_node sc_rollup_address [Log_kernel_debug]
  in
  let private_rpc_port = Some (Port.fresh ()) in
  let mode =
    Evm_node.Sequencer
      {
        initial_kernel = output;
        preimage_dir = preimages_dir;
        private_rpc_port;
        time_between_blocks;
        sequencer = sequencer.alias;
        genesis_timestamp;
        max_blueprints_lag;
        max_blueprints_ahead;
        max_blueprints_catchup;
        catchup_cooldown;
        max_number_of_chunks;
        devmode;
        wallet_dir = Some (Client.base_dir client);
        tx_pool_timeout_limit = None;
        tx_pool_addr_limit = None;
        tx_pool_tx_per_addr_limit = None;
      }
  in
  let* sequencer =
    Evm_node.init ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let* observer =
    Evm_node.init
      ~mode:
        (Observer
           {
             initial_kernel = output;
             preimages_dir;
             rollup_node_endpoint = Sc_rollup_node.endpoint sc_rollup_node;
           })
      (Evm_node.endpoint sequencer)
  in
  let* proxy =
    Evm_node.init
      ~mode:(Proxy {devmode})
      (Sc_rollup_node.endpoint sc_rollup_node)
  in
  return
    {
      node;
      client;
      sequencer;
      proxy;
      observer;
      l1_contracts;
      sc_rollup_address;
      sc_rollup_node;
    }

let send_raw_transaction_to_delayed_inbox ?(wait_for_next_level = true)
    ?(amount = Tez.one) ?expect_failure ~sc_rollup_node ~client ~l1_contracts
    ~sc_rollup_address ?(sender = Constant.bootstrap2) raw_tx =
  let expected_hash =
    `Hex raw_tx |> Hex.to_bytes |> Tezos_crypto.Hacl.Hash.Keccak_256.digest
    |> Hex.of_bytes |> Hex.show
  in
  let* () =
    Client.transfer
      ~arg:(sf "Pair %S 0x%s" sc_rollup_address raw_tx)
      ~amount
      ~giver:sender.public_key_hash
      ~receiver:l1_contracts.delayed_transaction_bridge
      ~burn_cap:Tez.one
      ?expect_failure
      client
  in
  let* () =
    if wait_for_next_level then
      let* _ = next_rollup_node_level ~sc_rollup_node ~client in
      unit
    else unit
  in
  Lwt.return expected_hash

let send_deposit_to_delayed_inbox ~amount ~l1_contracts ~depositor ~receiver
    ~sc_rollup_node ~sc_rollup_address client =
  let* () =
    Client.transfer
      ~entrypoint:"deposit"
      ~arg:(sf "Pair %S %s" sc_rollup_address receiver)
      ~amount
      ~giver:depositor.Account.public_key_hash
      ~receiver:l1_contracts.bridge
      ~burn_cap:Tez.one
      client
  in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  unit

let test_remove_sequencer =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "admin"]
    ~title:"Remove sequencer via sequencer admin contract"
    ~uses
  @@ fun protocol ->
  let* {
         sequencer;
         proxy;
         sc_rollup_node;
         client;
         sc_rollup_address;
         l1_contracts;
         observer;
         _;
       } =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in
  (* Produce blocks to show that both the sequencer and proxy are not
     progressing. *)
  let* _ =
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  (* Both are at genesis *)
  let*@ sequencer_head = Rpc.block_number sequencer in
  let*@ proxy_head = Rpc.block_number proxy in
  Check.((sequencer_head = 0l) int32)
    ~error_msg:"Sequencer should be at genesis" ;
  Check.((sequencer_head = proxy_head) int32)
    ~error_msg:"Sequencer and proxy should have the same block number" ;
  (* Remove the sequencer via the sequencer-admin contract. *)
  let* () =
    Client.transfer
      ~amount:Tez.zero
      ~giver:Constant.bootstrap2.public_key_hash
      ~receiver:l1_contracts.sequencer_governance
      ~arg:(sf "Pair %S 0x" sc_rollup_address)
      ~burn_cap:Tez.one
      client
  in
  let* exit_code = Evm_node.wait_for_shutdown_event sequencer
  and* missing_block_nb = Evm_node.wait_for_rollup_node_ahead observer
  and* () =
    (* Produce L1 blocks to show that only the proxy is progressing *)
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  Check.((exit_code = 100) int) ~error_msg:"Expected exit code %R, got %L" ;
  (* Sequencer is at genesis, proxy is at [advance]. *)
  Check.((missing_block_nb = 1) int)
    ~error_msg:"Sequencer should be missing block %L" ;
  let*@ proxy_head = Rpc.block_number proxy in
  Check.((proxy_head > 0l) int32) ~error_msg:"Proxy should have advanced" ;

  unit

let test_persistent_state =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"]
    ~title:"Sequencer state is persistent across runs"
    ~uses
  @@ fun protocol ->
  let* {sequencer; _} = setup_sequencer protocol in
  (* Force the sequencer to produce a block. *)
  let*@ _ = Rpc.produce_block sequencer in
  (* Ask for the current block. *)
  let*@ block_number = Rpc.block_number sequencer in
  Check.is_true
    ~__LOC__
    (block_number > 0l)
    ~error_msg:"The sequencer should have produced a block" ;
  (* Terminate the sequencer. *)
  let* () = Evm_node.terminate sequencer in
  (* Restart it. *)
  let* () = Evm_node.run sequencer in
  (* Assert the block number is at least [block_number]. Asserting
     that the block number is exactly the same as {!block_number} can
     be flaky if a block is produced between the restart and the
     RPC. *)
  let*@ new_block_number = Rpc.block_number sequencer in
  Check.is_true
    ~__LOC__
    (new_block_number >= block_number)
    ~error_msg:"The sequencer should have produced a block" ;
  unit

let test_publish_blueprints =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "data"]
    ~title:"Sequencer publishes the blueprints to L1"
    ~uses
  @@ fun protocol ->
  let* {sequencer; proxy; client; sc_rollup_node; _} =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in
  let* _ =
    repeat 5 (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in

  let* () = Evm_node.wait_for_blueprint_injected ~timeout:5. sequencer 5 in

  (* At this point, the evm node should called the batcher endpoint to publish
     all the blueprints. Stopping the node is then not a problem. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  (* We have unfortunately noticed that the test can be flaky. Sometimes,
     the following RPC is done before the proxy being initialised, even though
     we wait for it. The source of flakiness is unknown but happens very rarely,
     we put a small sleep to make the least flaky possible. *)
  let* () = Lwt_unix.sleep 2. in
  check_head_consistency ~left:sequencer ~right:proxy ()

let test_sequencer_too_ahead =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "max_blueprint_ahead"]
    ~title:"Sequencer locks production if it's too ahead"
    ~uses
  @@ fun protocol ->
  let max_blueprints_ahead = 5 in
  let* {sequencer; sc_rollup_node; proxy; client; sc_rollup_address; _} =
    setup_sequencer ~max_blueprints_ahead ~time_between_blocks:Nothing protocol
  in
  let* () = bake_until_sync ~sc_rollup_node ~proxy ~sequencer ~client () in
  let* () = Sc_rollup_node.terminate sc_rollup_node in
  let* () =
    repeat (max_blueprints_ahead * 2) (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  and* () = Evm_node.wait_for_block_producer_locked sequencer in
  let*@ block_number = Rpc.block_number sequencer in
  Check.((block_number = 6l) int32)
    ~error_msg:"The sequencer should have been locked" ;
  let* () = Sc_rollup_node.run sc_rollup_node sc_rollup_address []
  and* () = Evm_node.wait_for_rollup_node_follower_connection_acquired sequencer
  and* () = Evm_node.wait_for_rollup_node_follower_connection_acquired proxy in
  let* () = bake_until_sync ~sc_rollup_node ~proxy ~sequencer ~client () in
  let* _ =
    repeat 2 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let new_blocks = 3l in
  let* () =
    repeat (Int32.to_int new_blocks) (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in
  let previous_block_number = block_number in
  let*@ block_number = Rpc.block_number sequencer in
  Check.((block_number = Int32.add previous_block_number new_blocks) int32)
    ~error_msg:"The sequencer should have been unlocked" ;
  unit

let test_resilient_to_rollup_node_disconnect =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "data"; Tag.flaky]
    ~title:"Sequencer is resilient to rollup node disconnection"
    ~uses
  @@ fun protocol ->
  (* The objective of this test is to show that the sequencer can deal with
     rollup node outage. The logic of the sequencer at the moment is to
     wait for its advance on the rollup node to be more than [max_blueprints_lag]
     before sending at most [max_blueprints_catchup] blueprints. The sequencer
     waits for [catchup_cooldown] L1 blocks before checking if it needs to push
     new blueprints again. This scenario checks this logic. *)
  let max_blueprints_lag = 10 in
  let max_blueprints_catchup = max_blueprints_lag - 3 in
  let catchup_cooldown = 10 in
  let first_batch_blueprints_count = 5 in
  let ensure_rollup_node_publish = 5 in

  let* {
         sequencer;
         proxy;
         sc_rollup_node;
         sc_rollup_address;
         client;
         observer;
         _;
       } =
    setup_sequencer
      ~max_blueprints_lag
      ~max_blueprints_catchup
      ~catchup_cooldown
      ~time_between_blocks:Nothing
      protocol
  in

  (* Produce blueprints *)
  let* _ =
    repeat first_batch_blueprints_count (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in
  let* () =
    Evm_node.wait_for_blueprint_injected
      ~timeout:(float_of_int first_batch_blueprints_count)
      sequencer
      first_batch_blueprints_count
  in

  (* Produce some L1 blocks so that the rollup node publishes the blueprints. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  (* Check sequencer and rollup consistency *)
  let* () =
    check_head_consistency
      ~error_msg:"The head should be the same before the outage"
      ~left:sequencer
      ~right:proxy
      ()
  in

  (* Kill the rollup node *)
  let* () = Sc_rollup_node.terminate sc_rollup_node in

  (* The sequencer node should keep producing blocks, enough so that
     it cannot catchup in one go. *)
  let* _ =
    repeat (2 * max_blueprints_lag) (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in

  let* () =
    Evm_node.wait_for_blueprint_applied
      sequencer
      ~timeout:5.
      (first_batch_blueprints_count + (2 * max_blueprints_lag))
  and* () =
    Evm_node.wait_for_blueprint_applied
      observer
      ~timeout:5.
      (first_batch_blueprints_count + (2 * max_blueprints_lag))
  in

  (* Kill the sequencer node, restart the rollup node, restart the sequencer to
     reestablish the connection *)
  let* () = Sc_rollup_node.run sc_rollup_node sc_rollup_address [] in
  let* () = Sc_rollup_node.wait_for_ready sc_rollup_node
  and* () = Evm_node.wait_for_rollup_node_follower_connection_acquired sequencer
  and* () = Evm_node.wait_for_rollup_node_follower_connection_acquired observer
  and* () = Evm_node.wait_for_rollup_node_follower_connection_acquired proxy in

  (* Produce enough blocks in advance to ensure the sequencer node will catch
     up at the end. *)
  let* _ =
    repeat max_blueprints_lag (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in

  let* () =
    Evm_node.wait_for_blueprint_applied
      sequencer
      ~timeout:5.
      (first_batch_blueprints_count + (2 * max_blueprints_catchup) + 1)
  and* () =
    Evm_node.wait_for_blueprint_applied
      observer
      ~timeout:5.
      (first_batch_blueprints_count + (2 * max_blueprints_catchup) + 1)
  in

  (* Give some time for the sequencer node to inject the first round of
     blueprints *)
  let* _ =
    repeat ensure_rollup_node_publish (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in

  let*@ rollup_node_head = Rpc.get_block_by_number ~block:"latest" proxy in
  Check.(
    (rollup_node_head.number
    = Int32.(of_int (first_batch_blueprints_count + max_blueprints_catchup)))
      int32)
    ~error_msg:
      "The rollup node should have received the first round of lost blueprints" ;

  (* Go through several cooldown periods to let the sequencer sends the rest of
     the blueprints. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  (* We have unfortunately noticed that the test can be flaky. Sometimes,
     the following RPC is done before the proxy being initialised, even though
     we wait for it. The source of flakiness is unknown but happens very rarely,
     we put a small sleep to make the least flaky possible. *)
  let* () = Lwt_unix.sleep 2. in
  (* Check the consistency again *)
  check_head_consistency
    ~error_msg:
      "The head should be the same after the outage. Sequencer: {%L}, proxy: \
       {%R}"
    ~left:sequencer
    ~right:proxy
    ()

let test_can_fetch_blueprint =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "data"]
    ~title:"Sequencer can provide blueprints on demand"
    ~uses
  @@ fun protocol ->
  let* {sequencer; _} = setup_sequencer ~time_between_blocks:Nothing protocol in
  let number_of_blocks = 5 in
  let* _ =
    repeat number_of_blocks (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in

  let* () = Evm_node.wait_for_blueprint_injected ~timeout:5. sequencer 5 in

  let* blueprints =
    fold number_of_blocks [] (fun i acc ->
        let* blueprint =
          Sequencer_rpc.get_blueprint sequencer Int64.(of_int @@ (i + 1))
        in
        return (blueprint :: acc))
  in

  (* Test for uniqueness  *)
  let blueprints_uniq =
    List.sort_uniq
      (fun b1 b2 -> String.compare (JSON.encode b1) (JSON.encode b2))
      blueprints
  in
  if List.length blueprints = List.length blueprints_uniq then unit
  else
    Test.fail
      ~__LOC__
      "At least two blueprints from a different level are equal."

let test_can_fetch_smart_rollup_address =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "rpc"]
    ~title:"Sequencer can return the smart rollup address on demand"
    ~uses
  @@ fun protocol ->
  let* {sequencer; sc_rollup_address; _} =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in
  let* claimed_address = Sequencer_rpc.get_smart_rollup_address sequencer in

  Check.((sc_rollup_address = claimed_address) string)
    ~error_msg:"Returned address is not the expected one" ;

  unit

let test_send_transaction_to_delayed_inbox =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"]
    ~title:"Send a transaction to the delayed inbox"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {client; l1_contracts; sc_rollup_address; sc_rollup_node; _} =
    setup_sequencer ~da_fee:arb_da_fee_for_delayed_inbox protocol
  in
  let raw_transfer =
    "f86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let send ~amount ?expect_failure () =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      ~amount
      ?expect_failure
      raw_transfer
  in
  (* Test that paying less than 1XTZ is not allowed. *)
  let* _hash =
    send ~amount:(Tez.parse_floating "0.9") ~expect_failure:true ()
  in
  (* Test the correct case where the user burns 1XTZ to send the transaction. *)
  let* hash = send ~amount:Tez.one ~expect_failure:false () in
  (* Assert that the expected transaction hash is found in the delayed inbox
     durable storage path. *)
  let* delayed_transactions_hashes =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:"/evm/delayed-inbox"
         ()
  in
  Check.(list_mem string hash delayed_transactions_hashes)
    ~error_msg:"hash %L should be present in the delayed inbox %R" ;
  (* Test that paying more than 1XTZ is allowed. *)
  let* _hash =
    send ~amount:(Tez.parse_floating "1.1") ~expect_failure:false ()
  in
  unit

let test_send_deposit_to_delayed_inbox =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "deposit"]
    ~title:"Send a deposit to the delayed inbox"
    ~uses
  @@ fun protocol ->
  let* {client; l1_contracts; sc_rollup_address; sc_rollup_node; _} =
    setup_sequencer ~da_fee:arb_da_fee_for_delayed_inbox protocol
  in
  let amount = Tez.of_int 16 in
  let depositor = Constant.bootstrap5 in
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
    send_deposit_to_delayed_inbox
      ~amount
      ~l1_contracts
      ~depositor
      ~receiver:receiver.address
      ~sc_rollup_node
      ~sc_rollup_address
      client
  in
  let* delayed_transactions_hashes =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:"/evm/delayed-inbox"
         ()
  in
  Check.(
    list_mem
      string
      "a07feb67aff94089c8d944f5f8ffb5acc37306da9102fc310264e90999a42eb1"
      delayed_transactions_hashes)
    ~error_msg:"the deposit is not present in the delayed inbox" ;
  unit

let test_rpc_produceBlock =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "produce_block"]
    ~title:"RPC method produceBlock"
    ~uses
  @@ fun protocol ->
  (* Set a large [time_between_blocks] to make sure the block production is
     triggered by the RPC call. *)
  let* {sequencer; _} = setup_sequencer ~time_between_blocks:Nothing protocol in
  let*@ start_block_number = Rpc.block_number sequencer in
  let*@ _ = Rpc.produce_block sequencer in
  let*@ new_block_number = Rpc.block_number sequencer in
  Check.((Int32.succ start_block_number = new_block_number) int32)
    ~error_msg:"Expected new block number to be %L, but got: %R" ;
  unit

let wait_for_event ?(timeout = 30.) ?(levels = 10) event_watcher ~sequencer
    ~sc_rollup_node ~client ~error_msg =
  let event_value = ref None in
  let _ =
    let* return_value = event_watcher in
    event_value := Some return_value ;
    unit
  in
  let rec rollup_node_loop n =
    if n = 0 then Test.fail error_msg
    else
      let* _ = next_rollup_node_level ~sc_rollup_node ~client in
      let*@ _ = Rpc.produce_block sequencer in
      if Option.is_some !event_value then unit else rollup_node_loop (n - 1)
  in
  let* () = Lwt.pick [rollup_node_loop levels; Lwt_unix.sleep timeout] in
  match !event_value with
  | Some value -> return value
  | None -> Test.fail ~loc:__LOC__ "Waiting for event failed"

let wait_for_delayed_inbox_add_tx_and_injected ~sequencer ~sc_rollup_node
    ~client =
  let event_watcher =
    let added = Evm_node.wait_for_evm_event New_delayed_transaction sequencer in
    let injected = Evm_node.wait_for_block_producer_tx_injected sequencer in
    let* (_transaction_kind, added_hash), injected_hash =
      Lwt.both added injected
    in
    Check.((added_hash = injected_hash) string)
      ~error_msg:"Injected hash %R is not the expected one %L" ;
    Lwt.return_unit
  in
  wait_for_event
    event_watcher
    ~sequencer
    ~sc_rollup_node
    ~client
    ~error_msg:
      "Timed out while waiting for transaction to be added to the delayed \
       inbox and injected"

let check_delayed_inbox_is_empty ~sc_rollup_node =
  let* subkeys =
    Sc_rollup_node.RPC.call sc_rollup_node ~rpc_hooks:Tezos_regression.rpc_hooks
    @@ Sc_rollup_rpc.get_global_block_durable_state_value
         ~pvm_kind:"wasm_2_0_0"
         ~operation:Sc_rollup_rpc.Subkeys
         ~key:Durable_storage_path.delayed_inbox
         ()
  in
  Check.((List.length subkeys = 1) int)
    ~error_msg:"Expected no elements in the delayed inbox" ;
  unit

let test_delayed_transfer_is_included =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "inclusion"]
    ~title:"Delayed transaction is included"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {
         client;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         observer;
         _;
       } =
    setup_sequencer ~da_fee:arb_da_fee_for_delayed_inbox protocol
  in
  let endpoint = Evm_node.endpoint sequencer in
  (* This is a transfer from Eth_account.bootstrap_accounts.(0) to
     Eth_account.bootstrap_accounts.(1). *)
  let raw_transfer =
    "f86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let sender = Eth_account.bootstrap_accounts.(0).address in
  let receiver = Eth_account.bootstrap_accounts.(1).address in
  let* sender_balance_prev = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_prev = Eth_cli.balance ~account:receiver ~endpoint in
  let* tx_hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      raw_transfer
  in
  let* () =
    wait_for_delayed_inbox_add_tx_and_injected
      ~sequencer
      ~sc_rollup_node
      ~client
  in
  let* () = bake_until_sync ~sc_rollup_node ~proxy ~sequencer ~client () in
  let* () = check_delayed_inbox_is_empty ~sc_rollup_node in
  let* sender_balance_next = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_next = Eth_cli.balance ~account:receiver ~endpoint in
  Check.((sender_balance_prev <> sender_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((receiver_balance_prev <> receiver_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((sender_balance_prev > sender_balance_next) Wei.typ)
    ~error_msg:"Expected a smaller balance" ;
  Check.((receiver_balance_next > receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected a bigger balance" ;
  let*@! (_receipt : Transaction.transaction_receipt) =
    Rpc.get_transaction_receipt ~tx_hash observer
  in
  unit

let test_largest_delayed_transfer_is_included =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "inclusion"]
    ~title:"Largest possible delayed transaction is included"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {
         client;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         _;
       } =
    setup_sequencer ~da_fee:arb_da_fee_for_delayed_inbox protocol
  in
  let _endpoint = Evm_node.endpoint sequencer in
  (* This is the largest ethereum transaction we transfer via the bridge contract. *)
  let transfer_that_fits =
    "f90fb58209138502540be40082520894b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a7640000b90f4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000025a0f42f0b16afabe4ab2ecc258987540f63706283e7ad054a06ef2cc762bc32ad0da07edfd65f510c8c7abac684b4a820e1d54182cd67aeec7cff3b089f84fc8c4698"
  in
  let len_transfer_that_fits = String.length transfer_that_fits / 2 in
  Log.info "Maximum size allowed is %d" len_transfer_that_fits ;
  (* We assert that this is the largest by sending a transaction that is 1 byte
     larger, the protocol refuses it. *)
  let transfer_too_big =
    "f90fb68209138502540be40082520894b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a7640000b90f460000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026a094cee0c8af621cd6ff1cace4265311ee1497e62216413a2db989e26a471fe904a0277da4faf3652d2f3413e00887da47c64fde06da7f1c6c87276bc937ed1c7530"
  in
  let len_transfer_too_big = String.length transfer_too_big / 2 in
  assert (len_transfer_that_fits + 1 = len_transfer_too_big) ;
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      ~expect_failure:true
      transfer_too_big
  in
  (* Now we check that the largest possible transaction is included by the sequencer. *)
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      ~expect_failure:false
      transfer_that_fits
  in
  let* () =
    wait_for_delayed_inbox_add_tx_and_injected
      ~sequencer
      ~sc_rollup_node
      ~client
  in
  let* () = bake_until_sync ~sc_rollup_node ~proxy ~sequencer ~client () in
  let* () = check_delayed_inbox_is_empty ~sc_rollup_node in
  unit

let test_delayed_deposit_is_included =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "inclusion"; "deposit"]
    ~title:"Delayed deposit is included"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {
         client;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         _;
       } =
    setup_sequencer ~da_fee:arb_da_fee_for_delayed_inbox protocol
  in
  let endpoint = Evm_node.endpoint sequencer in

  let amount = Tez.of_int 16 in
  let depositor = Constant.bootstrap5 in
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
  let* receiver_balance_prev =
    Eth_cli.balance ~account:receiver.address ~endpoint
  in
  let* () =
    send_deposit_to_delayed_inbox
      ~amount
      ~l1_contracts
      ~depositor
      ~receiver:receiver.address
      ~sc_rollup_node
      ~sc_rollup_address
      client
  in
  let* () =
    wait_for_delayed_inbox_add_tx_and_injected
      ~sequencer
      ~sc_rollup_node
      ~client
  in
  let* () = bake_until_sync ~sc_rollup_node ~proxy ~sequencer ~client () in
  let* () = check_delayed_inbox_is_empty ~sc_rollup_node in
  let* receiver_balance_next =
    Eth_cli.balance ~account:receiver.address ~endpoint
  in
  Check.((receiver_balance_next > receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected a bigger balance" ;
  unit

(** test to initialise a sequencer data dir based on a rollup node
        data dir *)
let test_init_from_rollup_node_data_dir =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "rollup_node"; "init"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:"Init evm node sequencer data dir from a rollup node data dir"
  @@ fun protocol ->
  let* {sc_rollup_node; sequencer; proxy; client; _} =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in
  (* a sequencer is needed to produce an initial block *)
  let* () =
    repeat 5 (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in
  let* () = Evm_node.terminate sequencer in
  let evm_node' =
    Evm_node.create
      ~mode:(Evm_node.mode sequencer)
      (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let* () =
    (* bake 2 blocks so rollup context is for the finalized l1 level
       and can't be reorged. *)
    repeat 2 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in

  let* () =
    Evm_node.init_from_rollup_node_data_dir
      ~devmode:true
      evm_node'
      sc_rollup_node
  in
  let* () = Evm_node.run evm_node' in

  let* () = check_head_consistency ~left:evm_node' ~right:proxy () in

  let*@ _ = Rpc.produce_block evm_node' in
  let* () =
    bake_until_sync ~sc_rollup_node ~client ~sequencer:evm_node' ~proxy ()
  in

  let* () = check_head_consistency ~left:evm_node' ~right:proxy () in

  unit

let test_init_from_rollup_node_with_delayed_inbox =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "rollup_node"; "init"; "delayed_inbox"]
    ~uses:(fun _protocol ->
      [
        Constant.octez_smart_rollup_node;
        Constant.octez_evm_node;
        Constant.smart_rollup_installer;
        Constant.WASM.evm_kernel;
      ])
    ~title:
      "Init evm node sequencer data dir from a rollup node data dir with \
       delayed items"
  @@ fun protocol ->
  let* {
         sc_rollup_node;
         sequencer;
         proxy;
         client;
         l1_contracts;
         sc_rollup_address;
         _;
       } =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in

  (* a sequencer is needed to produce an initial block *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in
  let* () = Evm_node.terminate sequencer in

  (* deposit *)
  let amount = Tez.of_int 16 in
  let depositor = Constant.bootstrap5 in
  let receiver = Eth_account.bootstrap_accounts.(0) in
  let* () =
    send_deposit_to_delayed_inbox
      ~amount
      ~l1_contracts
      ~depositor
      ~receiver:receiver.address
      ~sc_rollup_node
      ~sc_rollup_address
      client
  in

  (* start a new sequnecer *)
  let evm_node' =
    Evm_node.create
      ~mode:(Evm_node.mode sequencer)
      (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let* () =
    (* bake 2 blocks so rollup context is for the finalized l1 level
       and can't be reorged. *)
    repeat 2 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in

  let* () =
    Evm_node.init_from_rollup_node_data_dir
      ~devmode:true
      evm_node'
      sc_rollup_node
  in

  let* () = Evm_node.run evm_node' in

  let* () = check_head_consistency ~left:evm_node' ~right:proxy () in

  let*@ _ = Rpc.produce_block evm_node' in
  let* () =
    bake_until_sync ~sc_rollup_node ~client ~sequencer:evm_node' ~proxy ()
  in

  let* () = check_head_consistency ~left:evm_node' ~right:proxy () in

  unit

let test_observer_applies_blueprint =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "observer"]
    ~title:"Can start an Observer node"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let tbb = 3. in
  let* {sequencer = sequencer_node; observer = observer_node; _} =
    setup_sequencer ~time_between_blocks:(Time_between_blocks tbb) protocol
  in
  let levels_to_wait = 3 in
  let timeout = tbb *. float_of_int levels_to_wait *. 2. in

  let* _ =
    Evm_node.wait_for_blueprint_applied ~timeout observer_node levels_to_wait
  and* _ =
    Evm_node.wait_for_blueprint_applied ~timeout sequencer_node levels_to_wait
  in

  let* () =
    check_block_consistency
      ~left:sequencer_node
      ~right:observer_node
      ~block:(`Level (Int32.of_int levels_to_wait))
      ()
  in

  (* We stop and start the sequencer, to ensure the observer node correctly
     reconnects to it. *)
  let* () = Evm_node.wait_for_retrying_connect observer_node
  and* () =
    let* () = Evm_node.terminate sequencer_node in
    Evm_node.run sequencer_node
  in

  let levels_to_wait = 2 * levels_to_wait in

  let* _ =
    Evm_node.wait_for_blueprint_applied ~timeout observer_node levels_to_wait
  and* _ =
    Evm_node.wait_for_blueprint_applied ~timeout sequencer_node levels_to_wait
  in

  let* () =
    check_block_consistency
      ~left:sequencer_node
      ~right:observer_node
      ~block:(`Level (Int32.of_int levels_to_wait))
      ()
  in

  unit

let test_observer_applies_blueprint_when_restarted =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "observer"]
    ~title:"Can restart an Observer node"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {sequencer; observer; _} =
    setup_sequencer ~time_between_blocks:Nothing protocol
  in

  (* We produce a block and check the observer applies it. *)
  let* _ = Evm_node.wait_for_blueprint_applied observer 1
  and* _ = Rpc.produce_block sequencer in

  (* We restart the observer *)
  let* () = Evm_node.terminate observer in
  let* () = Evm_node.run observer in

  (* We produce a block and check the observer applies it. *)
  let* _ = Evm_node.wait_for_blueprint_applied observer 2
  and* _ = Rpc.produce_block sequencer in

  unit

let test_observer_forwards_transaction =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "observer"; "transaction"]
    ~title:"Observer forwards transaction"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let tbb = 1. in
  let* {sequencer = sequencer_node; observer = observer_node; _} =
    setup_sequencer ~time_between_blocks:(Time_between_blocks tbb) protocol
  in
  (* Ensure the sequencer has produced the block. *)
  let* () =
    Evm_node.wait_for_blueprint_applied ~timeout:10.0 sequencer_node 1
  in
  (* Ensure the observer node has a correctly initialized local state. *)
  let* () = Evm_node.wait_for_blueprint_applied ~timeout:10.0 observer_node 1 in

  let* txn =
    Eth_cli.transaction_send
      ~source_private_key:Eth_account.bootstrap_accounts.(1).private_key
      ~to_public_key:Eth_account.bootstrap_accounts.(2).address
      ~value:Wei.one
      ~endpoint:(Evm_node.endpoint observer_node)
      ()
  in

  let* receipt =
    Eth_cli.get_receipt ~endpoint:(Evm_node.endpoint sequencer_node) ~tx:txn
  in

  match receipt with
  | Some receipt when receipt.status -> unit
  | Some _ ->
      Test.fail
        "transaction receipt received from the sequencer, but transaction \
         failed"
  | None ->
      Test.fail
        "Missing receipt in the sequencer node for transaction successfully \
         injected in the observer"

let test_sequencer_is_reimbursed =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "transaction"]
    ~title:"Sequencer is reimbursed for DA fees"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let tbb = 1. in
  (* We use an arbitrary address for the pool address, the goal is just to
     verify its balance increases. *)
  let sequencer_pool_address = "0xb7a97043983f24991398e5a82f63f4c58a417185" in
  let* {sequencer = sequencer_node; _} =
    setup_sequencer
      ~da_fee:Wei.one
      ~time_between_blocks:(Time_between_blocks tbb)
      ~sequencer_pool_address
      protocol
  in

  let* balance =
    Eth_cli.balance
      ~account:sequencer_pool_address
      ~endpoint:Evm_node.(endpoint sequencer_node)
  in

  Check.((Wei.zero = balance) Wei.typ)
    ~error_msg:"Balance of the sequencer address pool should be null" ;

  (* Ensure the sequencer has produced the block. *)
  let* () =
    Evm_node.wait_for_blueprint_applied ~timeout:10.0 sequencer_node 1
  in

  let* txn =
    Eth_cli.transaction_send
      ~source_private_key:Eth_account.bootstrap_accounts.(1).private_key
      ~to_public_key:Eth_account.bootstrap_accounts.(2).address
      ~value:Wei.one
      ~endpoint:(Evm_node.endpoint sequencer_node)
      ()
  in

  let* receipt =
    Eth_cli.get_receipt ~endpoint:(Evm_node.endpoint sequencer_node) ~tx:txn
  in

  match receipt with
  | Some receipt when receipt.status ->
      let* balance =
        Eth_cli.balance
          ~account:sequencer_pool_address
          ~endpoint:Evm_node.(endpoint sequencer_node)
      in

      Check.((Wei.zero < balance) Wei.typ)
        ~error_msg:"Balance of the sequencer address pool should not be null" ;
      unit
  | Some _ ->
      Test.fail
        "transaction receipt received from the sequencer, but transaction \
         failed"
  | None ->
      Test.fail
        "Missing receipt in the sequencer node for transaction successfully \
         injected in the observer"

(** This tests the situation where the kernel has an upgrade and the
    sequencer upgrade by following the event of the kernel. *)
let test_self_upgrade_kernel =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "upgrade"; "self"]
    ~title:"EVM Kernel can upgrade to itself"
    ~uses:(fun protocol -> uses protocol)
  @@ fun protocol ->
  (* Add a delay between first block and activation timestamp. *)
  let genesis_timestamp =
    Client.(At (Time.of_notation_exn "2020-01-01T00:00:00Z"))
  in
  let activation_timestamp = "2020-01-01T00:00:10Z" in

  let* {
         sc_rollup_node;
         l1_contracts;
         sc_rollup_address;
         client;
         sequencer;
         proxy;
         observer;
         _;
       } =
    setup_sequencer ~genesis_timestamp ~time_between_blocks:Nothing protocol
  in
  (* Sends the upgrade to L1, but not to the sequencer. *)
  let* () =
    upgrade
      ~sc_rollup_node
      ~sc_rollup_address
      ~admin:Constant.bootstrap2.public_key_hash
      ~admin_contract:l1_contracts.admin
      ~client
      ~upgrade_to:Constant.WASM.evm_kernel
      ~activation_timestamp
  in

  (* Per the activation timestamp, the state will remain synchronised until
     the kernel is upgraded. *)
  let* _ =
    repeat 2 (fun () ->
        let* _ =
          Rpc.produce_block ~timestamp:"2020-01-01T00:00:05Z" sequencer
        in
        unit)
  in

  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy ()
  and* _upgrade_info = Evm_node.wait_for_pending_upgrade sequencer
  and* _upgrade_info_observer = Evm_node.wait_for_pending_upgrade observer in

  let* () =
    check_head_consistency
      ~left:sequencer
      ~right:proxy
      ~error_msg:"The head should be the same before the upgrade"
      ()
  in

  (* Produce a block after activation timestamp, both the rollup
     node and the sequencer will upgrade to itself. *)
  let* _ =
    repeat 2 (fun () ->
        let* _ =
          Rpc.produce_block ~timestamp:"2020-01-01T00:00:15Z" sequencer
        in
        unit)
  and* _ = Evm_node.wait_for_successful_upgrade sequencer
  and* _ = Evm_node.wait_for_successful_upgrade observer in
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  let* () =
    check_head_consistency
      ~left:sequencer
      ~right:proxy
      ~error_msg:"The head should be the same after the upgrade"
      ()
  in

  unit

(** This tests the situation where the kernel has an upgrade and the
    sequencer upgrade by following the event of the kernel. *)
let test_upgrade_kernel_auto_sync =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "upgrade"; "auto"; "sync"]
    ~title:"Rollup-node kernel upgrade is applied to the sequencer state."
    ~uses
  @@ fun protocol ->
  (* Add a delay between first block and activation timestamp. *)
  let genesis_timestamp =
    Client.(At (Time.of_notation_exn "2020-01-01T00:00:00Z"))
  in
  let activation_timestamp = "2020-01-01T00:00:10Z" in

  let* {
         sc_rollup_node;
         l1_contracts;
         sc_rollup_address;
         client;
         sequencer;
         proxy;
         _;
       } =
    setup_sequencer ~genesis_timestamp ~time_between_blocks:Nothing protocol
  in
  (* Sends the upgrade to L1, but not to the sequencer. *)
  let* () =
    upgrade
      ~sc_rollup_node
      ~sc_rollup_address
      ~admin:Constant.bootstrap2.public_key_hash
      ~admin_contract:l1_contracts.admin
      ~client
      ~upgrade_to:Constant.WASM.evm_kernel
      ~activation_timestamp
  in

  (* Per the activation timestamp, the state will remain synchronised until
     the kernel is upgraded. *)
  let* _ =
    repeat 2 (fun () ->
        let*@ _ =
          Rpc.produce_block ~timestamp:"2020-01-01T00:00:05Z" sequencer
        in
        unit)
  in
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  let* () =
    check_head_consistency
      ~left:sequencer
      ~right:proxy
      ~error_msg:"The head should be the same before the upgrade"
      ()
  in

  (* Produce a block after activation timestamp, both the rollup
     node and the sequencer will upgrade to debug kernel and
     therefore not produce the block. *)
  let* _ =
    repeat 2 (fun () ->
        let*@ _ =
          Rpc.produce_block ~timestamp:"2020-01-01T00:00:15Z" sequencer
        in
        unit)
  in
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  let* () =
    check_head_consistency
      ~left:sequencer
      ~right:proxy
      ~error_msg:"The head should be the same after the upgrade"
      ()
  in

  unit

let test_delayed_transfer_timeout =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "timeout"]
    ~title:"Delayed transaction timeout"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {
         client;
         node = _;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         observer = _;
       } =
    setup_sequencer
      ~delayed_inbox_timeout:3
      ~delayed_inbox_min_levels:1
      ~da_fee:arb_da_fee_for_delayed_inbox
      protocol
  in
  (* Kill the sequencer *)
  let* () = Evm_node.terminate sequencer in
  let endpoint = Evm_node.endpoint proxy in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0).address in
  let _ = Rpc.block_number proxy in
  let receiver = Eth_account.bootstrap_accounts.(1).address in
  let* sender_balance_prev = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_prev = Eth_cli.balance ~account:receiver ~endpoint in
  (* This is a transfer from Eth_account.bootstrap_accounts.(0) to
     Eth_account.bootstrap_accounts.(1). *)
  let raw_transfer =
    "f86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      raw_transfer
  in
  (* Bake a few blocks, should be enough for the tx to time out and be
     forced *)
  let* _ =
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let* sender_balance_next = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_next = Eth_cli.balance ~account:receiver ~endpoint in
  Check.((sender_balance_prev <> sender_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((receiver_balance_prev <> receiver_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((sender_balance_prev > sender_balance_next) Wei.typ)
    ~error_msg:"Expected a smaller balance" ;
  Check.((receiver_balance_next > receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected a bigger balance" ;
  unit

let test_delayed_transfer_timeout_fails_l1_levels =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "timeout"; "min_levels"]
    ~title:"Delayed transaction timeout considers l1 level"
    ~uses
  @@ fun protocol ->
  let* {
         client;
         node = _;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         observer = _;
       } =
    setup_sequencer
      ~delayed_inbox_timeout:3
      ~delayed_inbox_min_levels:20
      ~da_fee:arb_da_fee_for_delayed_inbox
      protocol
  in
  (* Kill the sequencer *)
  let* () = Evm_node.terminate sequencer in
  let endpoint = Evm_node.endpoint proxy in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0).address in
  let _ = Rpc.block_number proxy in
  let receiver = Eth_account.bootstrap_accounts.(1).address in
  let* sender_balance_prev = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_prev = Eth_cli.balance ~account:receiver ~endpoint in
  (* This is a transfer from Eth_account.bootstrap_accounts.(0) to
     Eth_account.bootstrap_accounts.(1). *)
  let raw_transfer =
    "f86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      raw_transfer
  in
  (* Bake a few blocks, should be enough for the tx to time out in terms
     of wall time, but not in terms of L1 levels.
     Note that this test is almost the same as the one where the tx
     times out, only difference being the value of [delayed_inbox_min_levels].
  *)
  let* _ =
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let* sender_balance_next = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_next = Eth_cli.balance ~account:receiver ~endpoint in
  Check.((sender_balance_prev = sender_balance_next) Wei.typ)
    ~error_msg:"Balance should be the same" ;
  Check.((receiver_balance_prev = receiver_balance_next) Wei.typ)
    ~error_msg:"Balance should be same" ;
  Check.((sender_balance_prev = sender_balance_next) Wei.typ)
    ~error_msg:"Expected equal balance" ;
  Check.((receiver_balance_next = receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected equal balance" ;
  (* Wait until it's forced *)
  let* _ =
    repeat 15 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let* sender_balance_next = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_next = Eth_cli.balance ~account:receiver ~endpoint in
  Check.((sender_balance_prev <> sender_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((receiver_balance_prev <> receiver_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((sender_balance_prev > sender_balance_next) Wei.typ)
    ~error_msg:"Expected a smaller balance" ;
  Check.((receiver_balance_next > receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected a bigger balance" ;
  unit

(** This tests the situation where force kernel upgrade happens too soon. *)
let test_force_kernel_upgrade_too_early =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "upgrade"; "force"]
    ~title:"Force kernel upgrade fail too early"
    ~uses:(fun protocol -> Constant.WASM.ghostnet_evm_kernel :: uses protocol)
  @@ fun protocol ->
  (* Add a delay between first block and activation timestamp. *)
  let genesis_timestamp =
    Client.(At (Time.of_notation_exn "2020-01-10T00:00:00Z"))
  in
  let* {
         sc_rollup_node;
         l1_contracts;
         sc_rollup_address;
         client;
         sequencer;
         proxy;
         _;
       } =
    setup_sequencer ~genesis_timestamp ~time_between_blocks:Nothing protocol
  in
  (* Wait for the sequencer to publish its genesis block. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in
  let* proxy =
    Evm_node.init
      ~mode:(Proxy {devmode = true})
      (Sc_rollup_node.endpoint sc_rollup_node)
  in

  (* Assert the kernel version is the same at start up. *)
  let*@ sequencer_kernelVersion = Rpc.tez_kernelVersion sequencer in
  let*@ proxy_kernelVersion = Rpc.tez_kernelVersion proxy in
  Check.((sequencer_kernelVersion = proxy_kernelVersion) string)
    ~error_msg:"Kernel versions should be the same at start up" ;

  (* Activation timestamp is 1 day after the genesis. Therefore, it cannot
     be forced now. *)
  let activation_timestamp = "2020-01-11T00:00:00Z" in
  (* Sends the upgrade to L1 and sequencer. *)
  let* () =
    upgrade
      ~sc_rollup_node
      ~sc_rollup_address
      ~admin:Constant.bootstrap2.public_key_hash
      ~admin_contract:l1_contracts.admin
      ~client
      ~upgrade_to:Constant.WASM.ghostnet_evm_kernel
      ~activation_timestamp
  in

  (* Now we try force the kernel upgrade via an external message. *)
  let* () = force_kernel_upgrade ~sc_rollup_address ~sc_rollup_node ~client in

  (* Assert the kernel version are still the same. *)
  let*@ sequencer_kernelVersion = Rpc.tez_kernelVersion sequencer in
  let*@ new_proxy_kernelVersion = Rpc.tez_kernelVersion proxy in
  Check.((sequencer_kernelVersion = new_proxy_kernelVersion) string)
    ~error_msg:"The force kernel ugprade should have failed" ;
  unit

(** This tests the situation where the kernel does not produce blocks but
    still can be forced to upgrade via an external message. *)
let test_force_kernel_upgrade =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "upgrade"; "force"]
    ~title:"Force kernel upgrade"
    ~uses:(fun protocol -> Constant.WASM.ghostnet_evm_kernel :: uses protocol)
  @@ fun protocol ->
  (* Add a delay between first block and activation timestamp. *)
  let genesis_timestamp =
    Client.(At (Time.of_notation_exn "2020-01-10T00:00:00Z"))
  in
  let* {
         sc_rollup_node;
         l1_contracts;
         sc_rollup_address;
         client;
         sequencer;
         proxy;
         _;
       } =
    setup_sequencer ~genesis_timestamp ~time_between_blocks:Nothing protocol
  in
  (* Wait for the sequencer to publish its genesis block. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in
  let* proxy =
    Evm_node.init
      ~mode:(Proxy {devmode = true})
      (Sc_rollup_node.endpoint sc_rollup_node)
  in

  (* Assert the kernel version is the same at start up. *)
  let*@ sequencer_kernelVersion = Rpc.tez_kernelVersion sequencer in
  let*@ proxy_kernelVersion = Rpc.tez_kernelVersion proxy in
  Check.((sequencer_kernelVersion = proxy_kernelVersion) string)
    ~error_msg:"Kernel versions should be the same at start up" ;

  (* Activation timestamp is 1 day before the genesis. Therefore, it can
     be forced immediatly. *)
  let activation_timestamp = "2020-01-09T00:00:00Z" in
  (* Sends the upgrade to L1 and sequencer. *)
  let* () =
    upgrade
      ~sc_rollup_node
      ~sc_rollup_address
      ~admin:Constant.bootstrap2.public_key_hash
      ~admin_contract:l1_contracts.admin
      ~client
      ~upgrade_to:Constant.WASM.ghostnet_evm_kernel
      ~activation_timestamp
  in

  (* We bake a few blocks. As the sequencer is not producing anything, the
     kernel will not upgrade. *)
  let* () =
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  (* Assert the kernel version is the same, it proves the upgrade did not
      happen. *)
  let*@ sequencer_kernelVersion = Rpc.tez_kernelVersion sequencer in
  let*@ proxy_kernelVersion = Rpc.tez_kernelVersion proxy in
  Check.((sequencer_kernelVersion = proxy_kernelVersion) string)
    ~error_msg:"Kernel versions should be the same even after the message" ;

  (* Now we force the kernel upgrade via an external message. They will
     become unsynchronised. *)
  let* () = force_kernel_upgrade ~sc_rollup_address ~sc_rollup_node ~client in

  (* Assert the kernel version are now different, it shows that only the rollup
     node upgraded. *)
  let*@ sequencer_kernelVersion = Rpc.tez_kernelVersion sequencer in
  let*@ new_proxy_kernelVersion = Rpc.tez_kernelVersion proxy in
  Check.((sequencer_kernelVersion <> new_proxy_kernelVersion) string)
    ~error_msg:"Kernel versions should be different after forced upgrade" ;
  Check.((sequencer_kernelVersion = proxy_kernelVersion) string)
    ~error_msg:"Sequencer should be on the previous version" ;
  unit

let test_external_transaction_to_delayed_inbox_fails =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "external"]
    ~title:"Sending an external transaction to the delayed inbox fails"
    ~uses
  @@ fun protocol ->
  (* Start the evm node *)
  let* {client; sequencer; proxy; sc_rollup_node; _} =
    (* We have a da_fee set to zero here. This is because the proxy will perform
       validation on the tx before adding it the transaction pool. This will fail
       due to 'gas limit too low' if the da fee is set.

       Since we want to test what happens when the tx is actually submitted, we
       bypass the da fee check here. *)
    setup_sequencer
      protocol
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      ~time_between_blocks:Nothing
      ~config:(`Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml"))
  in
  let* () = Evm_node.wait_for_blueprint_injected ~timeout:5. sequencer 0 in
  (* Bake a couple more levels for the blueprint to be final *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in
  let raw_tx, _ = read_tx_from_file () |> List.hd in
  let*@ tx_hash = Rpc.send_raw_transaction ~raw_tx proxy in
  (* Bake enough levels to make sure the transaction would be processed
     if added *)
  let* () =
    repeat 10 (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  (* Response should be none *)
  let*@ response = Rpc.get_transaction_receipt ~tx_hash proxy in
  assert (Option.is_none response) ;
  let*@ response = Rpc.get_transaction_receipt ~tx_hash sequencer in
  assert (Option.is_none response) ;
  unit

let test_delayed_inbox_flushing =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "delayed_inbox"; "timeout"]
    ~title:"Delayed inbox flushing"
    ~uses
  @@ fun protocol ->
  (* Setup with a short wall time timeout but a significant lower bound of
     L1 levels needed for timeout.
     The idea is to send 2 transactions to the delayed inbox, having one
     time out and check that the second is also forced.
     We set [delayed_inbox_min_levels] to a value that is large enough
     to give us time to send the second one while the first one is not
     timed out yet.
  *)
  let* {
         client;
         node = _;
         l1_contracts;
         sc_rollup_address;
         sc_rollup_node;
         sequencer;
         proxy;
         observer = _;
       } =
    setup_sequencer
      ~delayed_inbox_timeout:1
      ~delayed_inbox_min_levels:20
      ~da_fee:arb_da_fee_for_delayed_inbox
      protocol
  in
  (* Kill the sequencer *)
  let* () = Evm_node.terminate sequencer in
  let endpoint = Evm_node.endpoint proxy in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  let sender = Eth_account.bootstrap_accounts.(0).address in
  let _ = Rpc.block_number proxy in
  let receiver = Eth_account.bootstrap_accounts.(1).address in
  let* sender_balance_prev = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_prev = Eth_cli.balance ~account:receiver ~endpoint in
  (* Send the first transaction, this one is dummy (from [100-inputs-for-proxy])
     as we only use it for the timeout. *)
  let tx1 =
    "f863808252088252089400000000000000000000000000000000000000000a80820a95a0aedf43a765be7e57167a732fb460bec1c73f29bc8c2f7e753b652918ea19cd8da04062403d1ddcdf9d80dc69cab4509400a21604f0ec42f82289597f8476792648"
  in
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      tx1
  in
  (* Bake a few blocks but not enough for the first tx to be forced! *)
  let* _ =
    repeat 10 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  (* Send the second transaction, a transfer from
     Eth_account.bootstrap_accounts.(0) to Eth_account.bootstrap_accounts.(1).
  *)
  let tx2 =
    "f86d80843b9aca00825b0494b53dc01974176e5dff2298c5a94343c2585e3c54880de0b6b3a764000080820a96a07a3109107c6bd1d555ce70d6253056bc18996d4aff4d4ea43ff175353f49b2e3a05f9ec9764dc4a3c3ab444debe2c3384070de9014d44732162bb33ee04da187ef"
  in
  let* _hash =
    send_raw_transaction_to_delayed_inbox
      ~sc_rollup_node
      ~client
      ~l1_contracts
      ~sc_rollup_address
      tx2
  in
  (* Bake a few more blocks to make sure the first tx times out, but not
     the second one. However, the latter should also be included. *)
  let* _ =
    repeat 10 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let* sender_balance_next = Eth_cli.balance ~account:sender ~endpoint in
  let* receiver_balance_next = Eth_cli.balance ~account:receiver ~endpoint in
  Check.((sender_balance_prev <> sender_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((receiver_balance_prev <> receiver_balance_next) Wei.typ)
    ~error_msg:"Balance should be updated" ;
  Check.((sender_balance_prev > sender_balance_next) Wei.typ)
    ~error_msg:"Expected a smaller balance" ;
  Check.((receiver_balance_next > receiver_balance_prev) Wei.typ)
    ~error_msg:"Expected a bigger balance" ;
  unit

let test_no_automatic_block_production =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "block"]
    ~title:"No automatic block production"
    ~uses
  @@ fun protocol ->
  let* {sequencer; _} = setup_sequencer protocol ~time_between_blocks:Nothing in
  let*@ before_head = Rpc.get_block_by_number ~block:"latest" sequencer in
  let transfer =
    let* tx_hash =
      Eth_cli.transaction_send
        ~source_private_key:Eth_account.(bootstrap_accounts.(0).private_key)
        ~to_public_key:Eth_account.(bootstrap_accounts.(0).address)
        ~value:(Wei.of_eth_int 1)
        ~endpoint:(Evm_node.endpoint sequencer)
        ()
    in
    return (Some tx_hash)
  in
  let timeout =
    let* () = Lwt_unix.sleep 15. in
    return None
  in
  let* tx_hash = Lwt.pick [transfer; timeout] in

  let*@ after_head = Rpc.get_block_by_number ~block:"latest" sequencer in
  (* As the time between blocks is "none", the sequencer should not produce a block
     even if we send a transaction. *)
  Check.((before_head.number = after_head.number) int32)
    ~error_msg:"No block production expected" ;
  (* The transaction hash is not returned as no receipt is produced, and eth-cli
     awaits for the receipt. *)
  Check.is_true
    (Option.is_none tx_hash)
    ~error_msg:"No transaction hash expected" ;
  unit

let test_migration_from_ghostnet =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "upgrade"; "migration"; "ghostnet"]
    ~title:"Sequencer can upgrade from ghostnet"
    ~uses:(fun protocol -> Constant.WASM.ghostnet_evm_kernel :: uses protocol)
  @@ fun protocol ->
  (* Creates a sequencer using prod version and ghostnet kernel. *)
  let* {
         sequencer;
         client;
         sc_rollup_node;
         sc_rollup_address;
         l1_contracts;
         proxy;
         _;
       } =
    setup_sequencer
      protocol
      ~time_between_blocks:Nothing
      ~kernel:Constant.WASM.ghostnet_evm_kernel
      ~devmode:false
      ~max_blueprints_lag:0
  in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  let check_kernel_version ~evm_node ~equal expected =
    let*@ kernel_version = Rpc.tez_kernelVersion evm_node in
    if equal then
      Check.((kernel_version = expected) string)
        ~error_msg:"Expected kernelVersion to be %R, got %L"
    else
      Check.((kernel_version <> expected) string)
        ~error_msg:"Expected kernelVersion to be different than %R" ;
    return kernel_version
  in
  (* Check kernelVersion. *)
  let* _kernel_version =
    check_kernel_version
      ~evm_node:sequencer
      ~equal:true
      Constant.WASM.ghostnet_evm_commit
  in
  let* _kernel_version =
    check_kernel_version
      ~evm_node:proxy
      ~equal:true
      Constant.WASM.ghostnet_evm_commit
  in

  (* Produces a few blocks. *)
  let* _ =
    repeat 2 (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in
  let* () =
    repeat 4 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  (* Check the consistency. *)
  let* () = check_head_consistency ~left:proxy ~right:sequencer () in
  (* Sends upgrade to current version. *)
  let* () =
    upgrade
      ~sc_rollup_node
      ~sc_rollup_address
      ~admin:Constant.bootstrap2.public_key_hash
      ~admin_contract:l1_contracts.admin
      ~client
      ~upgrade_to:Constant.WASM.evm_kernel
      ~activation_timestamp:"0"
  in
  (* Bakes 2 blocks for the event follower to see the upgrade. *)
  let* _ =
    repeat 2 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  (* Produce a block to trigger the upgrade. *)
  let*@ _ = Rpc.produce_block sequencer in
  let* _ =
    repeat 4 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  (* Check that the prod sequencer has updated. *)
  let* new_kernel_version =
    check_kernel_version
      ~evm_node:sequencer
      ~equal:false
      Constant.WASM.ghostnet_evm_commit
  in
  (* Runs sequencer and proxy with --devmode. *)
  let* () = Evm_node.terminate proxy in
  let* () = Evm_node.terminate sequencer in
  (* Manually put `--devmode` to use the same command line. *)
  let* () = Evm_node.run ~extra_arguments:["--devmode"] proxy in
  let* () = Evm_node.run ~extra_arguments:["--devmode"] sequencer in
  (* Check that new sequencer and proxy are on a new version. *)
  let* _kernel_version =
    check_kernel_version ~evm_node:sequencer ~equal:true new_kernel_version
  in
  let* _kernel_version =
    check_kernel_version ~evm_node:proxy ~equal:true new_kernel_version
  in
  (* Check the consistency. *)
  let* () = check_head_consistency ~left:proxy ~right:sequencer () in
  (* Produces a few blocks. *)
  let* _ =
    repeat 2 (fun () ->
        let*@ _ = Rpc.produce_block sequencer in
        unit)
  in
  let* () =
    repeat 4 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  (* Final consistency check. *)
  check_head_consistency ~left:sequencer ~right:proxy ()

(** This tests the situation where the kernel has an upgrade and the
    sequencer upgrade by following the event of the kernel. *)
let test_sequencer_upgrade =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "sequencer_upgrade"; "auto"; "sync"; Tag.flaky]
    ~title:
      "Rollup-node sequencer upgrade is applied to the sequencer local state."
    ~uses
  @@ fun protocol ->
  let* {
         sc_rollup_node;
         l1_contracts;
         sc_rollup_address;
         client;
         sequencer;
         proxy;
         observer;
         _;
       } =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in
  (* produce an initial block *)
  let*@ _lvl = Rpc.produce_block sequencer in
  let* () = bake_until_sync ~proxy ~sequencer ~sc_rollup_node ~client () in
  let* () =
    check_head_consistency
      ~left:proxy
      ~right:sequencer
      ~error_msg:"The head should be the same before the upgrade"
      ()
  in
  let*@ previous_proxy_head = Rpc.get_block_by_number ~block:"latest" proxy in
  (* Sends the upgrade to L1. *)
  Log.info "Sending the sequencer upgrade to the L1 contract" ;
  let new_sequencer_key = Constant.bootstrap2.alias in
  let* _upgrade_info = Evm_node.wait_for_evm_event Sequencer_upgrade sequencer
  and* _upgrade_info_observer =
    Evm_node.wait_for_evm_event Sequencer_upgrade observer
  and* () =
    let* () =
      sequencer_upgrade
        ~sc_rollup_address
        ~sequencer_admin:Constant.bootstrap2.alias
        ~sequencer_governance_contract:l1_contracts.sequencer_governance
        ~pool_address:Eth_account.bootstrap_accounts.(0).address
        ~client
        ~upgrade_to:new_sequencer_key
        ~activation_timestamp:"0"
    in
    (* 2 block so the sequencer sees the event from the rollup
       node. *)
    repeat 2 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  let* () =
    check_head_consistency
      ~left:proxy
      ~right:sequencer
      ~error_msg:"The head should be the same after the upgrade"
      ()
  in
  let nb_block = 4l in
  (* apply the upgrade in the kernel  *)
  let* _ = next_rollup_node_level ~client ~sc_rollup_node in
  (*   produce_block fails because sequencer changed *)
  let*@? _err = Rpc.produce_block sequencer in
  let* () =
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  let*@ proxy_head = Rpc.get_block_by_number ~block:"latest" proxy in
  Check.((previous_proxy_head.hash = proxy_head.hash) string)
    ~error_msg:
      "The proxy should not have progessed because no block have been produced \
       by the current sequencer." ;
  (* Check that even the evm-node sequencer itself refuses the blocks as they do
     not respect the sequencer's signature. *)
  let* () =
    check_head_consistency
      ~left:proxy
      ~right:sequencer
      ~error_msg:
        "The head should be the same after the sequencer tried to produce \
         blocks, they are are disregarded."
      ()
  in
  Log.info
    "Stopping current sequencer and starting a new one with new sequencer key" ;
  let new_sequencer =
    let mode =
      match Evm_node.mode sequencer with
      | Sequencer config ->
          Evm_node.Sequencer
            {
              config with
              sequencer = new_sequencer_key;
              private_rpc_port = Some (Port.fresh ());
            }
      | _ -> Test.fail "impossible case, it's a sequencer"
    in
    Evm_node.create ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in

  let* _ = Evm_node.wait_for_shutdown_event sequencer
  and* () =
    let* () =
      Evm_node.init_from_rollup_node_data_dir
        ~devmode:true
        new_sequencer
        sc_rollup_node
    in
    let* () = Evm_node.run new_sequencer in
    let* () =
      repeat (Int32.to_int nb_block) (fun () ->
          let* _ = Rpc.produce_block new_sequencer in
          unit)
    in
    let* () =
      repeat 5 (fun () ->
          let* _ = next_rollup_node_level ~client ~sc_rollup_node in
          unit)
    in
    let previous_proxy_head = proxy_head in
    let* () =
      check_head_consistency
        ~left:proxy
        ~right:new_sequencer
        ~error_msg:
          "The head should be the same after blocks produced by the new \
           sequencer"
        ()
    in
    let*@ proxy_head = Rpc.get_block_by_number ~block:"latest" proxy in
    Check.(
      (Int32.add previous_proxy_head.number nb_block = proxy_head.number) int32)
      ~error_msg:
        "The block number should have incremented (previous: %L, current: %R)" ;
    unit
  in
  unit

(** this test the situation where a sequencer diverged from it
    source. To obtain that we create two sequencers, one is going to
    diverged from the other. *)
let test_sequencer_diverge =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "diverge"]
    ~title:"Runs two sequencers, one diverge and stop"
    ~uses
  @@ fun protocol ->
  let* {sc_rollup_node; client; sequencer; observer; _} =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in
  let* () =
    repeat 4 (fun () ->
        let*@ _l2_level = Rpc.produce_block sequencer in
        unit)
  in
  let* () =
    (* 3 to make sure it is seen by the rollup node, 2 to finalize it *)
    repeat 5 (fun () ->
        let* _l1_level = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let sequencer_bis =
    let mode =
      match Evm_node.mode sequencer with
      | Sequencer config ->
          Evm_node.Sequencer
            {config with private_rpc_port = Some (Port.fresh ())}
      | _ -> Test.fail "impossible case, it's a sequencer"
    in
    Evm_node.create ~mode (Sc_rollup_node.endpoint sc_rollup_node)
  in
  let observer_bis =
    Evm_node.create
      ~mode:(Evm_node.mode observer)
      (Evm_node.endpoint sequencer_bis)
  in
  let* () =
    Evm_node.init_from_rollup_node_data_dir
      ~devmode:true
      sequencer_bis
      sc_rollup_node
  in
  let diverged_and_shutdown sequencer observer =
    let* _ = Evm_node.wait_for_diverged sequencer
    and* _ = Evm_node.wait_for_shutdown_event sequencer
    and* _ = Evm_node.wait_for_diverged observer
    and* _ = Evm_node.wait_for_shutdown_event observer in
    unit
  in
  let* () = Evm_node.run sequencer_bis in
  let* () = Evm_node.run observer_bis in
  let* () =
    Lwt.pick
      [
        diverged_and_shutdown sequencer observer;
        diverged_and_shutdown sequencer_bis observer_bis;
      ]
  and* () =
    (* diff timestamp to differ *)
    let* _ = Rpc.produce_block ~timestamp:"0" sequencer
    and* _ = Rpc.produce_block ~timestamp:"1" sequencer_bis in
    repeat 5 (fun () ->
        let* _ = next_rollup_node_level ~client ~sc_rollup_node in
        unit)
  in
  unit

(** This test that the sequencer evm node can catchup event from the
    rollup node. *)
let test_sequencer_can_catch_up_on_event =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "event"]
    ~title:"Evm node can catchup event from the rollup node"
    ~uses
  @@ fun protocol ->
  let* {sc_rollup_node; client; sequencer; proxy; observer; _} =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in
  let* () =
    repeat 2 (fun () ->
        let* _ = Rpc.produce_block sequencer in
        unit)
  in
  let* () = bake_until_sync ~sequencer ~sc_rollup_node ~proxy ~client () in
  let* _ = Rpc.produce_block sequencer in
  let*@ last_produced_block = Rpc.block_number sequencer in
  let* () =
    Evm_node.wait_for_blueprint_injected
      sequencer
      ~timeout:5.
      (Int32.to_int last_produced_block)
  in
  let* () = Evm_node.terminate sequencer in
  let* () = Evm_node.terminate observer in
  let* () =
    (* produces some blocks so the rollup node applies latest produced block. *)
    repeat 4 (fun () ->
        let* _ = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let check json =
    let open JSON in
    match as_list (json |-> "event") with
    | [number; hash] ->
        let number = as_int number in
        let hash = as_string hash in
        if number = Int32.to_int last_produced_block then Some (number, hash)
        else None
    | _ ->
        Test.fail
          ~__LOC__
          "invalid json for the evm event kind blueprint applied"
  in
  let* _json = Evm_node.wait_for_evm_event ~check Blueprint_applied sequencer
  and* _json_observer =
    Evm_node.wait_for_evm_event ~check Blueprint_applied observer
  and* () =
    let* () = Evm_node.run sequencer in
    Evm_node.run observer
  in
  let* () = check_head_consistency ~left:proxy ~right:sequencer () in
  unit

let test_sequencer_dont_read_level_twice =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "event"; Tag.slow]
    ~title:"Evm node don't read the same level twice"
    ~uses
  @@ fun protocol ->
  let* {
         sc_rollup_node;
         client;
         sequencer;
         proxy;
         l1_contracts;
         sc_rollup_address;
         _;
       } =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in

  (* We deposit some Tez to the rollup *)
  let* () =
    send_deposit_to_delayed_inbox
      ~amount:Tez.(of_int 16)
      ~l1_contracts
      ~depositor:Constant.bootstrap5
      ~receiver:Eth_account.bootstrap_accounts.(1).address
      ~sc_rollup_node
      ~sc_rollup_address
      client
  in

  (* We bake two blocks, so thet the EVM node can process the deposit and
     create a blueprint with it. *)
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in
  let* _ = next_rollup_node_level ~sc_rollup_node ~client in

  (* We expect the deposit to be in this block. *)
  let* _ = Rpc.produce_block sequencer in

  let*@ block = Rpc.get_block_by_number ~block:Int.(to_string 1) sequencer in
  let nb_transactions =
    match block.transactions with
    | Empty -> 0
    | Hash l -> List.length l
    | Full l -> List.length l
  in
  Check.((nb_transactions = 1) int)
    ~error_msg:"Expected one transaction (the deposit), got %L" ;

  (* We kill the sequencer and restart it. As a result, its last known L1 level
     is still the L1 level of the deposit. *)
  let* _ = Evm_node.terminate sequencer in
  let* _ = Evm_node.run sequencer in

  (* We produce some empty blocks. *)
  let*@ _ = Rpc.produce_block sequencer in
  let*@ _ = Rpc.produce_block sequencer in

  (* If the logic of the sequencer is correct (i.e., it does not process the
     deposit twice), then it is possible for the rollup node to apply them. *)
  let* () = bake_until_sync ~sc_rollup_node ~client ~sequencer ~proxy () in

  unit

let test_stage_one_reboot =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "reboot"; Tag.slow]
    ~title:
      "Checks the stage one reboots when reading too much chunks in a single \
       L1 level"
    ~uses
  @@ fun protocol ->
  let* {sc_rollup_node; client; sc_rollup_address; _} =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in
  let* chunks =
    Lwt_list.map_s (fun i ->
        Evm_node.chunk_data
          ~rollup_address:sc_rollup_address
          ~sequencer_key:Constant.bootstrap1.alias
          ~client
          ~number:i
          [])
    @@ List.init 400 Fun.id
  in
  let chunks = List.flatten chunks in
  let send_chunks chunks src =
    let messages =
      `A (List.map (fun c -> `String c) chunks)
      |> JSON.annotate ~origin:"send_message"
      |> JSON.encode
    in
    Client.Sc_rollup.send_message
      ?wait:None
      ~msg:("hex:" ^ messages)
      ~src
      client
  in
  let rec split_chunks acc chunks =
    match chunks with
    | [] -> acc
    | _ ->
        let messages, rem = Tezos_stdlib.TzList.split_n 100 chunks in
        split_chunks (messages :: acc) rem
  in
  let splitted_messages = split_chunks [] chunks in
  let* () =
    Lwt_list.iteri_s
      (fun i messages -> send_chunks messages Account.Bootstrap.keys.(i).alias)
      splitted_messages
  in
  let* total_tick_number_before_expected_reboots =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_total_ticks ()
  in
  let* _ = next_rollup_node_level ~client ~sc_rollup_node in
  let* total_tick_number_with_expected_reboots =
    Sc_rollup_node.RPC.call sc_rollup_node
    @@ Sc_rollup_rpc.get_global_block_total_ticks ()
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
  (* If the inbox is not empty, the kernel enforces a reboot after reading it,
     to give the maximum ticks available for the first block production. *)
  let min_ticks_when_inbox_is_not_empty =
    min_ticks_per_l1_level + ticks_per_snapshot
  in
  Check.((ticks_after_expected_reboot > min_ticks_when_inbox_is_not_empty) int)
    ~error_msg:
      "The number of ticks spent during the period should be higher than %R, \
       but got %L, which implies there have been no reboot, contrary to what \
       was expected." ;
  unit

let test_blueprint_is_limited_in_size =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "blueprint"; "limit"]
    ~title:
      "Checks the sequencer doesn't produce blueprint bigger than the given \
       maximum number of chunks"
    ~uses
  @@ fun protocol ->
  let* {sc_rollup_node; client; sequencer; _} =
    setup_sequencer
      ~config:(`Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml"))
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      ~max_number_of_chunks:2
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      protocol
  in
  let txs = read_tx_from_file () |> List.map (fun (tx, _hash) -> tx) in
  let* requests, hashes =
    Helpers.batch_n_transactions ~evm_node:sequencer txs
  in
  (* Each transaction is about 114 bytes, hence 100 * 114 = 11400 bytes, which
     will fit in two blueprints of two chunks each. *)
  let* () = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  let* () = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  let first_hash = List.hd hashes in
  let* level_of_first_transaction =
    let*@ receipt = Rpc.get_transaction_receipt ~tx_hash:first_hash sequencer in
    match receipt with
    | None -> Test.fail "Delayed transaction hasn't be included"
    | Some receipt -> return receipt.blockNumber
  in
  let*@ block_with_first_transaction =
    Rpc.get_block_by_number
      ~block:(Int32.to_string level_of_first_transaction)
      sequencer
  in
  (* The block containing the first transaction of the batch cannot contain the
     100 transactions of the batch, as it doesn't fit in two chunks. *)
  let block_size_of_first_transaction =
    match block_with_first_transaction.Block.transactions with
    | Block.Empty -> Test.fail "Expected a non empty block"
    | Block.Full _ ->
        Test.fail "Block is supposed to contain only transaction hashes"
    | Block.Hash hashes ->
        Check.((List.length hashes < List.length requests) int)
          ~error_msg:"Expected less than %R transactions in the block, got %L" ;
        List.length hashes
  in

  let* () = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  (* It's not clear the first transaction of the batch is applied in the first
     blueprint or the second, as it depends how the tx_pool sorts the
     transactions (by caller address). We need to check that either the previous
     block or the next block contains transactions, which puts in evidence that
     the batch has been splitted into two consecutive blueprints.
  *)
  let check_block_size block_number =
    let*@ block =
      Rpc.get_block_by_number ~block:(Int32.to_string block_number) sequencer
    in
    match block.Block.transactions with
    | Block.Empty -> return 0
    | Block.Full _ ->
        Test.fail "Block is supposed to contain only transaction hashes"
    | Block.Hash hashes -> return (List.length hashes)
  in
  let* next_block_size =
    check_block_size (Int32.succ level_of_first_transaction)
  in
  let* previous_block_size =
    check_block_size (Int32.pred level_of_first_transaction)
  in
  if next_block_size = 0 && previous_block_size = 0 then
    Test.fail
      "The sequencer didn't apply the 100 transactions in two consecutive \
       blueprints" ;
  Check.(
    (block_size_of_first_transaction + previous_block_size + next_block_size
    = List.length hashes)
      int
      ~error_msg:
        "Not all the transactions have been injected, only %L, while %R was \
         expected.") ;
  unit

let test_blueprint_limit_with_delayed_inbox =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "blueprint"; "limit"; "delayed"]
    ~title:
      "Checks the sequencer doesn't produce blueprint bigger than the given \
       maximum number of chunks and count delayed transactions size in the \
       blueprint"
    ~uses
  @@ fun protocol ->
  let* {sc_rollup_node; client; sequencer; sc_rollup_address; l1_contracts; _} =
    setup_sequencer
      ~config:(`Path (kernel_inputs_path ^ "/100-inputs-for-proxy-config.yaml"))
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      ~max_number_of_chunks:2
      ~minimum_base_fee_per_gas:base_fee_for_hardcoded_tx
      ~devmode:true
      protocol
  in
  let txs = read_tx_from_file () |> List.map (fun (tx, _hash) -> tx) in
  (* The first 3 transactions will be sent to the delayed inbox *)
  let delayed_txs, direct_txs = Tezos_base.TzPervasives.TzList.split_n 3 txs in
  let send_to_delayed_inbox (sender, raw_tx) =
    send_raw_transaction_to_delayed_inbox
      ~wait_for_next_level:false
      ~sender
      ~sc_rollup_node
      ~sc_rollup_address
      ~client
      ~l1_contracts
      raw_tx
  in
  let* delayed_hashes =
    Lwt_list.map_s send_to_delayed_inbox
    @@ List.combine
         [Constant.bootstrap2; Constant.bootstrap3; Constant.bootstrap4]
         delayed_txs
  in
  (* Ensures the transactions are added to the rollup delayed inbox and picked
     by the sequencer *)
  let* () =
    repeat 4 (fun () ->
        let* _l1_level = next_rollup_node_level ~sc_rollup_node ~client in
        unit)
  in
  let* _requests, _hashes =
    Helpers.batch_n_transactions ~evm_node:sequencer direct_txs
  in
  (* Due to the overapproximation of 4096 bytes per delayed transactions, there
     should be only a single delayed transaction per blueprints with 2 chunks. *)
  let* _ = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  let* _ = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  let* _ = next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client in
  (* Checks the delayed transactions and at least the first transaction from the
     batch have been applied *)
  let* block_numbers =
    Lwt_list.map_s
      (fun tx_hash ->
        let*@ receipt = Rpc.get_transaction_receipt ~tx_hash sequencer in
        match receipt with
        | None -> Test.fail "Delayed transaction hasn't be included"
        | Some receipt -> return receipt.blockNumber)
      delayed_hashes
  in
  let check_block_contains_delayed_transaction_and_transactions
      (delayed_hash, block_number) =
    let*@ block =
      Rpc.get_block_by_number ~block:(Int32.to_string block_number) sequencer
    in
    match block.Block.transactions with
    | Block.Empty -> Test.fail "Block shouldn't be empty"
    | Block.Full _ ->
        Test.fail "Block is supposed to contain only transaction hashes"
    | Block.Hash hashes ->
        if not (List.mem ("0x" ^ delayed_hash) hashes && 2 < List.length hashes)
        then
          Test.fail
            "The delayed transaction %s hasn't been included in the expected \
             block along other transactions from the pool"
            delayed_hash ;
        unit
  in
  Lwt_list.iter_s check_block_contains_delayed_transaction_and_transactions
  @@ List.combine delayed_hashes block_numbers

let test_reset =
  Protocol.register_test
    ~__FILE__
    ~tags:["evm"; "sequencer"; "reset"]
    ~title:"try to reset sequencer and observer state using the command."
    ~uses
  @@ fun protocol ->
  let* {
         proxy;
         observer;
         sequencer;
         sc_rollup_node;
         client;
         sc_rollup_address;
         _;
       } =
    setup_sequencer
      ~sequencer:Constant.bootstrap1
      ~time_between_blocks:Nothing
      protocol
  in
  let reset_level = 5 in
  let after_reset_level = 5 in
  Log.info "Producing %d level then syncing" reset_level ;
  let* () =
    repeat reset_level (fun () ->
        next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client)
  in
  let* () = bake_until_sync ~sequencer ~sc_rollup_node ~proxy ~client () in
  Log.info
    "Stopping the rollup node, then produce %d more blocks "
    (reset_level + after_reset_level) ;
  let* () = Sc_rollup_node.terminate sc_rollup_node in
  let* () =
    repeat after_reset_level (fun () ->
        next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client)
  in
  let*@ sequencer_level = Rpc.block_number sequencer in
  Check.(
    (sequencer_level = Int32.of_int (reset_level + after_reset_level)) int32)
    ~error_msg:
      "The sequencer level %L should be at %R after producing %R blocks" ;
  Log.info "Stopping sequencer and observer" ;
  let* () = Evm_node.terminate observer
  and* () = Evm_node.terminate sequencer in

  Log.info "Reset sequencer and observer state." ;
  let* () = Evm_node.reset observer ~l2_level:reset_level
  and* () = Evm_node.reset sequencer ~l2_level:reset_level in

  Log.info "Rerun rollup node, sequencer and observer." ;
  let* () =
    Sc_rollup_node.run sc_rollup_node sc_rollup_address [Log_kernel_debug]
  in
  let* () = Evm_node.run sequencer in
  let* () = Evm_node.run observer in

  Log.info "Check sequencer and observer is at %d level" reset_level ;
  let*@ sequencer_level = Rpc.block_number sequencer in
  let*@ observer_level = Rpc.block_number observer in
  Check.((sequencer_level = Int32.of_int reset_level) int32)
    ~error_msg:
      "The sequencer is at level %L, but should be at the level %R after being \
       reset." ;
  Check.((sequencer_level = observer_level) int32)
    ~error_msg:
      "The sequencer (currently at level %L) and observer ( currently at level \
       %R) should be at the same level after both being reset." ;
  let* () =
    repeat after_reset_level (fun () ->
        next_evm_level ~evm_node:sequencer ~sc_rollup_node ~client)
  in
  let* () = bake_until_sync ~sequencer ~sc_rollup_node ~proxy ~client () in
  (* Check sequencer is at the expected level *)
  let*@ sequencer_level = Rpc.block_number sequencer in
  Check.(
    (sequencer_level = Int32.of_int (reset_level + after_reset_level)) int32)
    ~error_msg:
      "The sequencer level %L should be at %R after producing blocks after the \
       reset." ;
  unit

let protocols = Protocol.all

let () =
  test_remove_sequencer protocols ;
  test_persistent_state protocols ;
  test_publish_blueprints protocols ;
  test_sequencer_too_ahead protocols ;
  test_resilient_to_rollup_node_disconnect protocols ;
  test_can_fetch_smart_rollup_address protocols ;
  test_can_fetch_blueprint protocols ;
  test_send_transaction_to_delayed_inbox protocols ;
  test_send_deposit_to_delayed_inbox protocols ;
  test_rpc_produceBlock protocols ;
  test_delayed_transfer_is_included protocols ;
  test_delayed_deposit_is_included protocols ;
  test_largest_delayed_transfer_is_included protocols ;
  test_init_from_rollup_node_data_dir protocols ;
  test_init_from_rollup_node_with_delayed_inbox protocols ;
  test_observer_applies_blueprint protocols ;
  test_observer_applies_blueprint_when_restarted protocols ;
  test_observer_forwards_transaction protocols ;
  test_sequencer_is_reimbursed protocols ;
  test_upgrade_kernel_auto_sync protocols ;
  test_self_upgrade_kernel protocols ;
  test_force_kernel_upgrade protocols ;
  test_force_kernel_upgrade_too_early protocols ;
  test_external_transaction_to_delayed_inbox_fails protocols ;
  test_delayed_transfer_timeout protocols ;
  test_delayed_transfer_timeout_fails_l1_levels protocols ;
  test_delayed_inbox_flushing protocols ;
  test_no_automatic_block_production protocols ;
  test_migration_from_ghostnet protocols ;
  test_sequencer_upgrade protocols ;
  test_sequencer_diverge protocols ;
  test_sequencer_can_catch_up_on_event protocols ;
  test_sequencer_dont_read_level_twice protocols ;
  test_stage_one_reboot protocols ;
  test_blueprint_is_limited_in_size protocols ;
  test_blueprint_limit_with_delayed_inbox protocols ;
  test_reset protocols
