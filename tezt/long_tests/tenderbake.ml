(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
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

(* Testing
   -------
   Component: Baker / Consensus
   Invocation: dune exec tezt/long_tests/main.exe -- --file baker.ml
   Subject: Checking performance for Tenderbake bakers
*)

module Time = Tezos_base.Time.System

let protocol = Protocol.Alpha

let len = Array.length Account.Bootstrap.keys

let nodes_num = len

let levels = 5

let repeat = 5

let time_to_reach_measurement = sf "time-to-reach-%d" levels

let test_rounds_title =
  sf "check that we reach level %d on all %d nodes" levels nodes_num

type topology = Clique | Ring

let cluster_of_topology = function
  | Clique -> Cluster.clique
  | Ring -> Cluster.ring

let string_of_topology = function Clique -> "clique" | Ring -> "ring"

let test_long_dynamic_bake_title topology =
  "long dynamic bake: " ^ string_of_topology topology

let dynamic_bake_test_cycles =
  Sys.getenv_opt "TEZT_LONG_TEST_LONG_DYNAMIC_TEST_CYCLES"
  |> Option.map int_of_string |> Option.value ~default:60

let dynamic_bake_test_blocks_per_cycles =
  Sys.getenv_opt "TEZT_LONG_TEST_LONG_DYNAMIC_BLOCKS_PER_CYCLES"
  |> Option.map int_of_string |> Option.value ~default:2

(* add one for genesis block *)
let dynamic_bake_max_level =
  1 + (dynamic_bake_test_cycles * dynamic_bake_test_blocks_per_cycles)

let dynamic_bake_time_to_reach_max_level_measurement =
  sf "dynamic-bake-time-to-reach-%d" dynamic_bake_max_level

(* that is, decision expected in at most 3 rounds. only used for display *)
let dynamic_bake_expected_max_rounds = 3

let dynamic_bake_minimal_block_delay = 1

let dynamic_bake_delay_increment_per_round = 1

(* c.f. https://tezos.gitlab.io/active/consensus.html *)
let dynamic_bake_round_duration r =
  dynamic_bake_minimal_block_delay + (r * dynamic_bake_delay_increment_per_round)

let dynamic_bake_grafana_panels topology =
  let test = test_long_dynamic_bake_title topology in
  let open Grafana in
  [
    Row ("Test: " ^ test_long_dynamic_bake_title topology);
    simple_graph
      ~title:
        (sf
           "The time it takes the cluster to reach level %d"
           dynamic_bake_max_level)
      ~yaxis_format:" s"
      ~measurement:dynamic_bake_time_to_reach_max_level_measurement
      ~field:"duration"
      ~test
      ();
    graphs_per_tags
      ~title:"The time it takes node 0 to reach level N."
      ~yaxis_format:" s"
      ~measurement:"node-0-reaches-level"
      ~field:"duration"
      ~test
      ~tags:
        (List.map (fun level -> ("level", string_of_int level))
        @@ range 2 dynamic_bake_max_level)
      ();
    graphs_per_tags
      ~title:
        (sf
           "Round in which consensus was reached on level N (should be less \
            than %d all the way through)."
           dynamic_bake_expected_max_rounds)
      ~yaxis_format:" rounds"
      ~measurement:"node-0-reaches-level"
      ~field:"round"
      ~test
      ~tags:
        (List.map (fun level -> ("level", string_of_int level))
        @@ range 2 dynamic_bake_max_level)
      ();
  ]

let grafana_panels : Grafana.panel list =
  let open Grafana in
  [
    Row ("Test: " ^ test_rounds_title);
    simple_graph
      ~title:(sf "The time it takes the cluster to reach level %d" levels)
      ~measurement:time_to_reach_measurement
      ~test:test_rounds_title
      ~field:"duration"
      ();
    graphs_per_tags
      ~title:"The time it takes node 0 to reach level N."
      ~yaxis_format:" s"
      ~measurement:"node-0-reaches-level"
      ~field:"duration"
      ~test:test_rounds_title
      ~tags:
        (List.map (fun level -> ("level", string_of_int level))
        @@ range 2 levels)
      ();
    graphs_per_tags
      ~title:
        "Round in which consensus was reached on level N (should be 0 all the \
         way through)."
      ~yaxis_format:" rounds"
      ~measurement:"node-0-reaches-level"
      ~field:"round"
      ~test:test_rounds_title
      ~tags:
        (List.map (fun level -> ("level", string_of_int level))
        @@ range 2 levels)
      ();
  ]
  @ dynamic_bake_grafana_panels Clique
  @ dynamic_bake_grafana_panels Ring

(* Check that in a simple ring topology with as many nodes/bakers/clients as
   bootstrap accounts, each with a single delegate, all blocks occurs within
   round 1. *)
let test_rounds ~executors =
  let minimal_block_delay = 4 in
  let delay_increment_per_round = 1 in
  let timeout =
    (* All blocks must come from round 0 *)
    let max_time_per_round =
      minimal_block_delay + minimal_block_delay + delay_increment_per_round
    in
    (levels - 1) * max_time_per_round
  in

  Long_test.register
    ~__FILE__
    ~title:test_rounds_title
    ~tags:["tenderbake"; "basic"]
    ~executors
    ~timeout:(Long_test.Seconds (8 * timeout))
  @@ fun () ->
  Log.info
    "Setting up protocol parameters and %d nodes, clients & bakers"
    nodes_num ;

  if nodes_num < 1 then
    Test.fail "[nodes_num] must be strictly positive, was %d" nodes_num ;

  Long_test.measure_and_check_regression_lwt ~repeat time_to_reach_measurement
  @@ fun () ->
  let daemons = ref [] in
  (* One client to activate the protocol later on *)
  let* node_hd, activator_client, nodes_tl =
    let create i =
      Log.info "Creating node, client, baker triplet #%d" i ;
      let node = Node.create [Synchronisation_threshold 0] in
      let* client = Client.init ~endpoint:(Client.Node node) () in
      let delegates = [Account.Bootstrap.keys.(i mod len).alias] in
      let baker = Baker.create ~protocol node client ~delegates in
      let* () = Baker.run baker in
      daemons := (node, baker) :: !daemons ;
      Lwt.return (node, client, baker)
    in
    let* node_hd, activator_client, _ = create 0
    and* nodes_tl =
      Lwt_list.map_p
        (fun i ->
          let* node, _, _ = create i in
          return node)
        (range 1 (nodes_num - 1))
    in
    return (node_hd, activator_client, nodes_tl)
  in
  let nodes = node_hd :: nodes_tl in

  (* Topology does not really matter here, as long as there is a path from any
     node to another one, Let's use a ring. *)
  Log.info "Setting up nodes in ring topology" ;
  Cluster.ring nodes ;
  let* () = Cluster.start ~wait_connections:true nodes in

  Log.info "Generating test-specific parameter file" ;
  let* parameter_file =
    let stringify_int n = Some (sf "\"%d\"" n) in
    let base = Either.Right (protocol, None) in
    let original_parameters_file = Protocol.parameter_file protocol in
    let parameters = JSON.parse_file original_parameters_file in
    let consensus_committee_size =
      JSON.(get "consensus_committee_size" parameters |> as_int)
    in
    let consensus_threshold = (consensus_committee_size * 2 / 3) + 1 in

    Protocol.write_parameter_file
      ~base
      [
        (["minimal_block_delay"], stringify_int minimal_block_delay);
        (["delay_increment_per_round"], stringify_int delay_increment_per_round);
        (["consensus_threshold"], Some (string_of_int consensus_threshold));
      ]
  in

  let rpc_get_timestamp node block_level =
    let* header =
      RPC.call node
      @@ RPC.get_chain_block_header ~block:(string_of_int block_level) ()
    in
    let timestamp_s = JSON.(header |-> "timestamp" |> as_string) in
    return (timestamp_s |> Time.of_notation_exn |> Ptime.to_float_s)
  in

  let start = ref 0.0 in
  let start_block_timestamp = ref 0.0 in

  let node_level_promises =
    List.concat_map
      (fun level ->
        List.mapi
          (fun i node ->
            let* (_ : int) = Node.wait_for_level node level in
            let event_reached = Unix.gettimeofday () -. !start in
            if i = 0 then (
              let* block_delay =
                let* block_timestamp = rpc_get_timestamp node level in
                return (block_timestamp -. !start_block_timestamp)
              in
              let* round =
                RPC.call node
                @@ RPC.get_chain_block_helper_round
                     ~block:(string_of_int level)
                     ()
              in
              Log.info
                "Node %s reached level %d in %f seconds (round: %d, block \
                 delay: %f)"
                (Node.name node)
                level
                event_reached
                round
                block_delay ;
              let data_point =
                InfluxDB.data_point
                  ~other_fields:[("round", Float (float_of_int round))]
                  ~tags:[("level", string_of_int level)]
                  "node-0-reaches-level"
                  ("duration", Float event_reached)
              in
              Long_test.add_data_point data_point ;
              unit)
            else (
              Log.info
                "Node %s reached level %d in %f seconds"
                (Node.name node)
                level
                event_reached ;
              unit))
          nodes)
      (range 2 levels)
  in

  Log.info "Activating protocol" ;
  let* () =
    Client.activate_protocol_and_wait
      ~protocol
      ~timestamp:Client.Now
      ~parameter_file
      activator_client
  in
  start := Unix.gettimeofday () ;
  let* () =
    let* ts = rpc_get_timestamp node_hd 1 in
    start_block_timestamp := ts ;
    unit
  in
  (* Let's time the baker *)
  Log.info
    "Waiting for level %d to be reached (should happen in less than %d seconds)"
    levels
    timeout ;
  let* (_ : unit list) = Lwt.all node_level_promises in
  let time = Unix.gettimeofday () -. !start in

  let* () =
    Lwt_list.iter_p
      (fun (node, baker) ->
        let* () = Baker.terminate baker and* () = Node.terminate node in
        unit)
      !daemons
  in

  Lwt.return time

module Inf = struct
  type 'a t = Inf of (unit -> 'a * 'a t)

  let inf f = Inf f

  let shuffle : 'a array -> 'a t =
   fun arr ->
    let len = Array.length arr in
    let rec next prev =
      inf @@ fun () ->
      let nxt = (prev + Random.int (len - 1)) mod len in
      (arr.(nxt), next nxt)
    in
    inf @@ fun () ->
    let fst = Random.int len in
    (arr.(fst), next fst)

  let cycle : 'a list -> 'a t = function
    | [] -> raise (Invalid_argument "Inf.cycle: list cannot be empty")
    | y :: ys ->
        let rec aux = function
          | [] -> inf @@ fun () -> (y, aux ys)
          | x :: xs -> inf @@ fun () -> (x, aux xs)
        in
        aux (y :: ys)

  let next : 'a t -> 'a * 'a t = function Inf f -> f ()
end

(* This test runs [num_nodes_with_bakers + num_nodes_without_bakers]
   bakers, and [num_nodes_with_bakers] bakers. It runs
   [dynamic_bake_test_cycles] test cycles (not to be confused with
   protocol cycles) where each cycle lasts
   [dynamic_bake_test_blocks_per_cycles] blocks.  At each cycle, a
   random transaction is injected. We measure and check for
   regressions in the time it takes the cluster to reach the final
   level [dynamic_bake_max_level]. *)
let test_long_dynamic_bake topology ~executors =
  let num_nodes_with_bakers = 3 in
  let num_nodes_without_bakers = 2 in
  let _time_between_cycle = 2 in
  let _check_progress = 10 in
  let kill_baker = 4 in
  let timeout =
    dynamic_bake_max_level
    * dynamic_bake_round_duration dynamic_bake_expected_max_rounds
  in
  let _max_retry = 6 in

  Long_test.register
    ~__FILE__
    ~title:(test_long_dynamic_bake_title topology)
    ~tags:["tenderbake"; "dynamic"; string_of_topology topology]
    ~executors
    ~timeout:(Long_test.Seconds (8 * timeout))
  @@ fun () ->
  Log.info "Generating test-specific parameter file" ;
  let* parameter_file =
    let stringify_int n = Some (sf "\"%d\"" n) in
    let base = Either.Right (protocol, None) in
    let original_parameters_file = Protocol.parameter_file protocol in
    let parameters = JSON.parse_file original_parameters_file in
    (* TODO: in [test_tenderbake_long_dynamic_bake.py] and in [test_tenderbake.py] it is
       [consensus_threshold * 2/3 + 1]. Which is weird! Which should it be? In [original_parameters_file],
       [consensus_threshold] is [0] and [consensus_committee_size] is 256.

       In python it was thus [45*(2/3)+1 = 31].
       In tezt we have [256 * (2/3) + 1 = 170].
    *)
    let consensus_threshold =
      let _consensus_committee_size =
        JSON.(get "consensus_committee_size" parameters |> as_int)
      in
      (*       (consensus_committee_size * 2 / 3) + 1 *)
      31
    in

    Protocol.write_parameter_file
      ~base
      [
        (["minimal_block_delay"], stringify_int dynamic_bake_minimal_block_delay);
        ( ["delay_increment_per_round"],
          stringify_int dynamic_bake_delay_increment_per_round );
        (["consensus_threshold"], Some (string_of_int consensus_threshold));
      ]
  in

  Long_test.measure_and_check_regression_lwt
    ~repeat
    dynamic_bake_time_to_reach_max_level_measurement
  @@ fun () ->
  Log.info "Setup daemons" ;
  let node_daemons = ref [] in
  let baker_daemons = ref [] in

  (* One client to activate the protocol later on *)
  let* node_hd, activator_client, nodes_tl, clients_tl =
    let create ?(add_baker = true) i =
      let node = Node.create [Synchronisation_threshold 0] in
      Log.info
        "Creating node, client%s triplet #%d (%s)"
        (if add_baker then ", baker" else "")
        i
        (Node.name node) ;
      node_daemons := node :: !node_daemons ;
      let* client = Client.init ~endpoint:(Client.Node node) () in
      let delegates = [Account.Bootstrap.keys.(i mod len).alias] in
      let* () =
        if add_baker then (
          let baker = Baker.create ~protocol node client ~delegates in
          let* () = Baker.run baker in
          baker_daemons := baker :: !baker_daemons ;
          unit)
        else unit
      in
      Lwt.return (node, client)
    in
    let* node_with_baker_hd, activator_client = create 0 in
    let* nodes_with_bakers =
      Lwt_list.map_s create (range 1 (num_nodes_with_bakers - 1))
    in
    let* nodes_without_bakers =
      Lwt_list.map_s
        (create ~add_baker:false)
        (range
           num_nodes_with_bakers
           (num_nodes_with_bakers + num_nodes_without_bakers - 1))
    in
    return
      ( node_with_baker_hd,
        activator_client,
        List.map fst nodes_with_bakers @ List.map fst nodes_without_bakers,
        List.map snd nodes_with_bakers @ List.map snd nodes_without_bakers )
  in
  let nodes = node_hd :: nodes_tl in

  Log.info
    "Setting up node %s topology: %s"
    (string_of_topology topology)
    (String.concat ", " @@ List.map Node.name nodes) ;
  (cluster_of_topology topology) nodes ;

  Log.info "Starting nodes" ;
  let* () = Cluster.start ~wait_connections:true nodes in

  let rpc_get_timestamp node block_level =
    let* header =
      RPC.call node
      @@ RPC.get_chain_block_header ~block:(string_of_int block_level) ()
    in
    let timestamp_s = JSON.(header |-> "timestamp" |> as_string) in
    return (timestamp_s |> Time.of_notation_exn |> Ptime.to_float_s)
  in

  let start = ref 0.0 in
  let start_block_timestamp = ref 0.0 in

  let node_level_promises =
    List.concat_map
      (fun level ->
        List.mapi
          (fun i node ->
            let* (_ : int) = Node.wait_for_level node level in
            let event_reached = Unix.gettimeofday () -. !start in
            if i = 0 then (
              let* block_delay =
                let* block_timestamp = rpc_get_timestamp node level in
                return (block_timestamp -. !start_block_timestamp)
              in
              let* round =
                RPC.call node
                @@ RPC.get_chain_block_helper_round
                     ~block:(string_of_int level)
                     ()
              in
              Log.info
                "Node %s reached level %d in %f seconds (round: %d, block \
                 delay: %f)"
                (Node.name node)
                level
                event_reached
                round
                block_delay ;
              let data_point =
                InfluxDB.data_point
                  ~other_fields:[("round", Float (float_of_int round))]
                  ~tags:[("level", string_of_int level)]
                  "node-0-reaches-level"
                  ("duration", Float event_reached)
              in
              Long_test.add_data_point data_point ;
              unit)
            else (
              Log.info
                "Node %s reached level %d in %f seconds"
                (Node.name node)
                level
                event_reached ;
              unit))
          nodes)
      (range 2 dynamic_bake_max_level)
  in

  Log.info "Activating protocol" ;
  let* () =
    Client.activate_protocol_and_wait
      ~protocol
      ~timestamp:Client.Now
      ~parameter_file
      activator_client
  in

  Log.info "Generate network operations" ;
  let clients =
    Inf.shuffle (Array.of_list @@ (activator_client :: clients_tl))
  in
  let keys =
    Inf.shuffle
      (Array.map (fun Account.{alias; _} -> alias) Account.Bootstrap.keys)
  in
  let bakers = Inf.cycle !baker_daemons in

  let rec loop cycle keys bakers clients () =
    let level = Node.get_level node_hd in
    if level < dynamic_bake_max_level then (
      let client, clients = Inf.next clients in

      Log.info
        "Cycle %d: generate a random operation with client %s"
        cycle
        (Client.name client) ;
      let giver, keys = Inf.next keys in
      let receiver, keys = Inf.next keys in
      let amount = Tez.of_int (1 + Random.int 10) in
      let* () = Client.transfer ~amount ~giver ~receiver client in
      Log.info "Sent %s from %s to %s" (Tez.to_string amount) giver receiver ;

      let* bakers =
        if cycle mod kill_baker = 0 then (
          let baker, bakers = Inf.next bakers in
          Log.info "Cycle %d: kill baker %s" cycle (Baker.name baker) ;
          let* () = Baker.terminate baker in
          let* () = Baker.run baker in
          return bakers)
        else return bakers
      in

      let next_cycle_level = level + dynamic_bake_test_blocks_per_cycles in
      Log.info
        "Waiting for cycle %d/%d at level %d/%d"
        (cycle + 1)
        dynamic_bake_test_cycles
        next_cycle_level
        dynamic_bake_max_level ;
      let* (_ : int) = Node.wait_for_level node_hd next_cycle_level in
      loop (cycle + 1) keys bakers clients ())
    else unit
  in

  start := Unix.gettimeofday () ;
  let* () =
    let* ts = rpc_get_timestamp node_hd 1 in
    start_block_timestamp := ts ;
    unit
  in
  let* () = loop 0 keys bakers clients () in
  let* (_ : unit list) = Lwt.all node_level_promises in
  let time = Unix.gettimeofday () -. !start in
  Log.info "Test terminated in %f seconds, expected max time: %d" time timeout ;

  (* Clean up for repeat *)
  let* () = Lwt_list.iter_p Baker.terminate !baker_daemons in
  let* () = Lwt_list.iter_p Node.terminate !node_daemons in

  Lwt.return time

let register ~executors () =
  test_rounds ~executors ;
  test_long_dynamic_bake Clique ~executors ;
  test_long_dynamic_bake Ring ~executors
