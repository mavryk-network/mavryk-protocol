(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
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

let originate_new_rollup ?(alias = "rollup")
    ?(boot_sector = Constant.wasm_echo_kernel_boot_sector)
    ?(parameters_ty = "bytes") ~src client =
  let* rollup =
    Client.Sc_rollup.originate
      ~force:true
      client
      ~wait:"2"
      ~alias
      ~src
      ~kind:"wasm_2_0_0"
      ~parameters_ty
      ~boot_sector
      ~burn_cap:(Tez.of_int 2)
  in
  Log.info "Rollup %s originated" rollup ;
  return rollup

let setup_l2_node ?(mode = Sc_rollup_node.Operator) ?runner ?name ?loser_mode
    ~operator (testnet : Testnet.t) client node rollup =
  let preimages_dir =
    match testnet.rollup with
    | Some {preimages_dir; _} -> preimages_dir
    | None -> None
  in
  let rollup_node =
    Sc_rollup_node.create
      ?runner
      ?name
      ~base_dir:(Client.base_dir client)
      ~default_operator:operator
      mode
      node
  in
  let* () =
    match preimages_dir with
    | None -> unit
    | Some dir ->
        let* _ =
          Lwt_unix.system
            ("cp -r " ^ dir ^ " "
            ^ (Sc_rollup_node.data_dir rollup_node // "wasm_2_0_0"))
        in
        unit
  in
  let* _ = Sc_rollup_node.config_init ?loser_mode rollup_node rollup in
  Log.info "Starting a smart rollup node to track %s" rollup ;
  let* () = Sc_rollup_node.run rollup_node rollup ["--log-kernel-debug"] in
  let* () = Sc_rollup_node.wait_for_ready rollup_node in
  Log.info "Smart rollup node started." ;
  return rollup_node

let setup_l2_node_with_client ?mode ?runner ?name ?loser_mode ~operator testnet
    client node rollup =
  let* rollup_node =
    setup_l2_node
      ?mode
      ?runner
      ?name
      ?loser_mode
      ~operator
      testnet
      client
      node
      rollup
  in
  let rollup_client =
    Sc_rollup_client.create ~protocol:Protocol.Alpha rollup_node
  in
  return (rollup_node, rollup_client)

let game_in_progress ~staker rollup_address client =
  let* game =
    Client.RPC.call client
    @@ RPC.get_chain_block_context_smart_rollups_smart_rollup_staker_games
         ~staker
         rollup_address
         ()
  in
  return (not ([] = JSON.as_list game))

let rec wait_for_game ~staker rollup_address client node =
  let* in_progress = game_in_progress ~staker rollup_address client in
  if not in_progress then (
    let* current_level = Node.get_level node in
    Log.info "Still no game at level %d" current_level ;
    let* _ = Node.wait_for_level node (current_level + 1) in
    wait_for_game ~staker rollup_address client node)
  else unit

let rec wait_for_end_of_game ~staker rollup_address client node =
  let* in_progress = game_in_progress ~staker rollup_address client in
  if in_progress then (
    let* current_level = Node.get_level node in
    Log.info "Game still in progress at level %d" current_level ;
    let* _ = Node.wait_for_level node (current_level + 1) in
    wait_for_end_of_game ~staker rollup_address client node)
  else unit

let rejection_with_proof ~(testnet : unit -> Testnet.t) () =
  (* We expect each player to have at least 11,000 xtz. This is enough
     to originate a rollup (1.68 xtz for one of the player), commit
     (10,000 xtz for both player), and play the game (each
     [Smart_rollup_refute] operation should be relatively cheap). *)
  let testnet = testnet () in
  let min_balance_operating = Tez.(of_mutez_int 11_000_000_000) in
  let* client, node = Helpers.setup_octez_node ~testnet () in
  let* honest_operator = Client.gen_and_show_keys client in
  let* dishonest_operator = Client.gen_and_show_keys client in
  let* () =
    Lwt.join
      [
        Helpers.wait_for_funded_key
          node
          client
          min_balance_operating
          honest_operator;
        Helpers.wait_for_funded_key
          node
          client
          min_balance_operating
          dishonest_operator;
      ]
  in
  let* rollup_address =
    originate_new_rollup ~src:honest_operator.alias client
  in
  let* level = Node.get_level node in
  let fault_level = level + 5 in
  Log.info
    "Dishonest operator expected to inject an error at level %d"
    fault_level ;
  let* _rollup_nodes =
    Lwt.all
      [
        setup_l2_node
          ~name:"honest-node"
          ~operator:honest_operator.alias
          testnet
          client
          node
          rollup_address;
        setup_l2_node
          ~name:"dishonest-node"
          ~loser_mode:Format.(sprintf "%d 0 0" fault_level)
          ~operator:dishonest_operator.alias
          testnet
          client
          node
          rollup_address;
      ]
  in
  let* () =
    wait_for_game
      ~staker:honest_operator.public_key_hash
      rollup_address
      client
      node
  in
  let* () =
    wait_for_end_of_game
      ~staker:honest_operator.public_key_hash
      rollup_address
      client
      node
  in
  (* TODO: https://gitlab.com/tezos/tezos/-/issues/4929
     Should the scenario checks if the game ended with the expected
     result? *)
  unit

let send_message_client ?hooks ?(src = Constant.bootstrap2.alias) client msg =
  Client.Sc_rollup.send_message ?hooks ~src ~msg client

let to_text_messages_arg msgs =
  let json = Ezjsonm.list Ezjsonm.string msgs in
  "text:" ^ Ezjsonm.to_string ~minify:true json

let to_hex_messages_arg msgs =
  let json = Ezjsonm.list Ezjsonm.string msgs in
  "hex:" ^ Ezjsonm.to_string ~minify:true json

let send_text_messages ?(format = `Raw) ?hooks ?src client msgs =
  match format with
  | `Raw -> send_message_client ?hooks ?src client (to_text_messages_arg msgs)
  | `Hex -> send_message_client ?hooks ?src client (to_hex_messages_arg msgs)

(** Wait for the [sc_rollup_node_publish_execute_whitelist_update]
    event from the rollup node. *)
let wait_for_publish_execute_whitelist_update node =
  Sc_rollup_node.wait_for
    node
    "sc_rollup_node_publish_execute_whitelist_update.v0"
  @@ fun json ->
  let hash = JSON.(json |-> "hash" |> as_string) in
  let outbox_level = JSON.(json |-> "outbox_level" |> as_int) in
  let index = JSON.(json |-> "message_index" |> as_int) in
  Some (hash, outbox_level, index)

let get_or_gen_keys ~alias client =
  let process = Client.spawn_show_address ~alias client in
  let* status = Process.wait process in
  if status = Unix.WEXITED 0 then
    let* client_output = Process.check_and_read_stdout process in
    return @@ Account.parse_client_output ~alias ~client_output
  else Client.gen_and_show_keys ~alias client

let simple_use_case_rollup ~(testnet : unit -> Testnet.t) () =
  let testnet = testnet () in
  let min_balance_operating = Tez.(of_mutez_int 11_000_000_000) in
  let min_balance_batching = Tez.(of_mutez_int 1_000_000) in
  let* client, node = Helpers.setup_octez_node ~testnet () in
  let* msg_sender = get_or_gen_keys ~alias:"msg_sender" client in
  let* operator1 = get_or_gen_keys ~alias:"operator1" client in
  let* operator2 = get_or_gen_keys ~alias:"operator2" client in
  let* batcher1 = get_or_gen_keys ~alias:"batcher1" client in
  let* batcher2 = get_or_gen_keys ~alias:"batcher2" client in
  let* accuser = get_or_gen_keys ~alias:"accuser" client in
  let* observer = get_or_gen_keys ~alias:"observer" client in
  let* () =
    Lwt.join
      [
        Helpers.wait_for_funded_key node client min_balance_operating operator1;
        Helpers.wait_for_funded_key node client min_balance_operating operator2;
        Helpers.wait_for_funded_key node client min_balance_operating accuser;
        Helpers.wait_for_funded_key node client min_balance_batching batcher1;
        Helpers.wait_for_funded_key node client min_balance_batching batcher2;
        Helpers.wait_for_funded_key node client min_balance_batching msg_sender;
      ]
  in
  let rollup_alias = "my_rollup" in
  let boot_sector =
    match testnet.rollup with
    | Some {kernel_path = Some kernel_path; _} ->
        let kernel = read_file kernel_path in
        Some (Hex.show @@ Hex.of_string kernel)
    | _ -> None
  in
  let* rollup_address =
    let*! address = Client.Sc_rollup.list_known_smart_rollups client in
    match List.assoc_opt rollup_alias address with
    | Some addr -> return addr
    | None ->
        originate_new_rollup
          ?boot_sector
          ~alias:rollup_alias
          ~src:operator2.alias
          client
  in
  let* level = Node.get_level node in
  let* operator_node1 =
    setup_l2_node
      ~name:"rollup-operator1"
      ~mode:Sc_rollup_node.Operator
      ~operator:operator1.alias
      testnet
      client
      node
      rollup_alias
  in
  let* operator_node2 =
    setup_l2_node
      ~name:"rollup-operator2"
      ~mode:Sc_rollup_node.Operator
      ~operator:operator2.alias
      testnet
      client
      node
      rollup_alias
  in
  let* batcher_node1, batcher_client1 =
    setup_l2_node_with_client
      ~name:"rollup-batcher1"
      ~mode:Sc_rollup_node.Batcher
      ~operator:batcher1.alias
      testnet
      client
      node
      rollup_alias
  in
  let* batcher_node2, batcher_client2 =
    setup_l2_node_with_client
      ~name:"rollup-batcher2"
      ~mode:Sc_rollup_node.Batcher
      ~operator:batcher2.alias
      testnet
      client
      node
      rollup_alias
  in
  let* observer_node =
    setup_l2_node
      ~name:"rollup-observer"
      ~mode:Sc_rollup_node.Observer
      ~operator:observer.alias
      testnet
      client
      node
      rollup_alias
  in
  let* accuser_node =
    setup_l2_node
      ~name:"rollup-accuser"
      ~mode:Sc_rollup_node.Accuser
      ~operator:accuser.alias
      testnet
      client
      node
      rollup_alias
  in
  let wait_sync node =
    let* _level = Sc_rollup_node.wait_sync ~timeout:30. node in
    unit
  in
  let sync_all () =
    Lwt.join
      [
        wait_sync operator_node1;
        wait_sync operator_node2;
        wait_sync batcher_node1;
        wait_sync batcher_node2;
        wait_sync observer_node;
        wait_sync accuser_node;
      ]
  in
  let* () = sync_all () in
  let* level = Node.wait_for_level node (level + 4) in
  let send_cmd send_where msgs =
    match send_where with
    | `Batcher1 ->
        let*! _hashes =
          Sc_rollup_client.inject ~format:`Hex batcher_client1 msgs
        in
        unit
    | `Batcher2 ->
        let*! _hashes =
          Sc_rollup_client.inject ~format:`Hex batcher_client2 msgs
        in
        unit
    | `Node ->
        let* () =
          send_text_messages ~format:`Hex ~src:msg_sender.alias client msgs
        in
        unit
  in
  let* _level =
    (* number of blocks per week with 7 sec block time ~= 86_400 *)
    fold 86_400 (level, `Batcher1) @@ fun nonce (level, send_where) ->
    let* level = Node.wait_for_level node (level + 1) in
    let* () = sync_all () in
    let process =
      Process.spawn
        "node"
        [
          "src/kernel_evm/benchmarks/transaction_generator.js";
          "gen_transactions";
          "accounts.json";
          rollup_address;
          string_of_int nonce;
        ]
    in
    let* stdout = Process.check_and_read_stdout process in
    let transactions =
      JSON.(
        parse
          ~origin:"gen_transactions"
          (String.trim stdout
          |> String.map (function '\n' -> ' ' | '\'' -> '"' | c -> c))
        |> as_list |> List.map as_string)
    in
    let* () = send_cmd send_where transactions in
    let next_send_where =
      match send_where with
      | `Batcher1 -> `Batcher2
      | `Batcher2 -> `Node
      | `Node -> `Batcher1
    in
    return (level, next_send_where)
  in
  unit

let register ~testnet =
  Test.register
    ~__FILE__
    ~title:"Rejection with proof"
    ~tags:["rejection"]
    (rejection_with_proof ~testnet) ;
  Test.register
    ~__FILE__
    ~title:"Simple rollup use case"
    ~tags:["rollup"; "accuser"; "node"; "batcher"]
    (simple_use_case_rollup ~testnet)
