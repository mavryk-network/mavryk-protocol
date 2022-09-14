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

let repeat =
  Sys.getenv_opt "TEZT_LONG_TENDERBAKE_REPEAT"
  |> Option.map int_of_string |> Option.value ~default:5

let num_bootstrap_accounts = Array.length Account.Bootstrap.keys

let nodes_num = num_bootstrap_accounts

type topology = Clique | Ring

let cluster_of_topology = function
  | Clique -> Cluster.clique
  | Ring -> Cluster.ring

let string_of_topology = function Clique -> "clique" | Ring -> "ring"

let rpc_get_timestamp node block_level =
  let* header =
    RPC.call node
    @@ RPC.get_chain_block_header ~block:(string_of_int block_level) ()
  in
  let timestamp_s = JSON.(header |-> "timestamp" |> as_string) in
  return (timestamp_s |> Time.of_notation_exn |> Ptime.to_float_s)

let write_parameter_file ?consensus_threshold protocol ~minimal_block_delay
    ~delay_increment_per_round =
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
    let default =
      let consensus_committee_size =
        JSON.(get "consensus_committee_size" parameters |> as_int)
      in
      (consensus_committee_size * 2 / 3) + 1
    in
    Option.value ~default consensus_threshold
  in
  let overrides =
    [
      (["minimal_block_delay"], stringify_int minimal_block_delay);
      (["delay_increment_per_round"], stringify_int delay_increment_per_round);
      (["consensus_threshold"], Some (string_of_int consensus_threshold));
    ]
  in
  Log.info
    "Generating test-specific parameter file for %s: [%s]"
    (Protocol.tag protocol)
    (String.concat ", "
    @@ List.map
         (fun (path, value) ->
           sf "%s=%s" (String.concat "." path) (Option.value ~default:"_" value))
         overrides) ;
  Protocol.write_parameter_file ~base overrides

module Rounds = struct
  let levels = 5

  let time_to_reach_measurement = sf "time-to-reach-%d" levels

  let test = sf "check that we reach level %d on all %d nodes" levels nodes_num

  let grafana_panels : Grafana.panel list =
    let open Grafana in
    [
      Row ("Test: " ^ test);
      simple_graph
        ~title:(sf "The time it takes the cluster to reach level %d" levels)
        ~measurement:time_to_reach_measurement
        ~test
        ~field:"duration"
        ();
      graphs_per_tags
        ~title:"The time it takes node 0 to reach level N."
        ~yaxis_format:" s"
        ~measurement:"node-0-reaches-level"
        ~field:"duration"
        ~test
        ~tags:
          (List.map (fun level -> ("level", string_of_int level))
          @@ range 2 levels)
        ();
      graphs_per_tags
        ~title:
          "Round in which consensus was reached on level N (should be 0 all \
           the way through)."
        ~yaxis_format:" rounds"
        ~measurement:"node-0-reaches-level"
        ~field:"round"
        ~test
        ~tags:
          (List.map (fun level -> ("level", string_of_int level))
          @@ range 2 levels)
        ();
    ]

  (* Check that in a simple ring topology with as many nodes/bakers/clients as
     bootstrap accounts, each with a single delegate, all blocks occurs within
     round 1. *)
  let register ~executors =
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
      ~title:test
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
        let delegates =
          [Account.Bootstrap.keys.(i mod num_bootstrap_accounts).alias]
        in
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

    let* parameter_file =
      write_parameter_file
        protocol
        ~minimal_block_delay
        ~delay_increment_per_round
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
      "Waiting for level %d to be reached (should happen in less than %d \
       seconds)"
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
end

module Inf = struct
  type 'a t = Inf of (unit -> 'a * 'a t)

  let inf f = Inf f

  let shuffle : 'a array -> 'a t =
   fun arr ->
    let num_bootstrap_accounts = Array.length arr in
    let rec next prev =
      inf @@ fun () ->
      let nxt =
        (prev + Random.int (num_bootstrap_accounts - 1))
        mod num_bootstrap_accounts
      in
      (arr.(nxt), next nxt)
    in
    inf @@ fun () ->
    let fst = Random.int num_bootstrap_accounts in
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

module Long_dynamic_bake = struct
  let test topology = "long dynamic bake: " ^ string_of_topology topology

  let test_cycles =
    Sys.getenv_opt "TEZT_LONG_TEST_LONG_DYNAMIC_TEST_CYCLES"
    |> Option.map int_of_string |> Option.value ~default:60

  let blocks_per_test_cycle =
    Sys.getenv_opt "TEZT_LONG_TEST_LONG_DYNAMIC_BLOCKS_PER_CYCLES"
    |> Option.map int_of_string |> Option.value ~default:2

  (* add one for genesis block *)
  let max_level = 1 + (test_cycles * blocks_per_test_cycle)

  let time_to_reach_max_level_measurement =
    sf "dynamic-bake-time-to-reach-%d" max_level

  (* that is, decision expected in at most 3 rounds. only used for display *)
  let expected_max_rounds = 3

  let minimal_block_delay = 1

  let delay_increment_per_round = 1

  (* c.f. https://tezos.gitlab.io/active/consensus.html *)
  let round_duration r = minimal_block_delay + (r * delay_increment_per_round)

  let grafana_panels topology =
    let test = test topology in
    let open Grafana in
    [
      Row ("Test: " ^ test);
      simple_graph
        ~title:(sf "The time it takes the cluster to reach level %d" max_level)
        ~yaxis_format:" s"
        ~measurement:time_to_reach_max_level_measurement
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
          @@ range 2 max_level)
        ();
      graphs_per_tags
        ~title:
          (sf
             "Round in which consensus was reached on level N (should be less \
              than %d all the way through)."
             expected_max_rounds)
        ~yaxis_format:" rounds"
        ~measurement:"node-0-reaches-level"
        ~field:"round"
        ~test
        ~tags:
          (List.map (fun level -> ("level", string_of_int level))
          @@ range 2 max_level)
        ();
    ]

  (* This test runs [num_nodes_with_bakers + num_nodes_without_bakers]
     bakers, and [num_nodes_with_bakers] bakers. It runs
     [test_cycles] test cycles (not to be confused with
     protocol cycles) where each cycle lasts
     [blocks_per_test_cycle] blocks.  At each cycle, a
     random transaction is injected. We measure and check for
     regressions in the time it takes the cluster to reach the final
     level [max_level]. *)
  let register topology ~executors =
    let num_nodes_with_bakers = 3 in
    let num_nodes_without_bakers = 2 in
    let kill_baker = 4 in
    let timeout = max_level * round_duration expected_max_rounds in

    Long_test.register
      ~__FILE__
      ~title:(test topology)
      ~tags:["tenderbake"; "dynamic"; string_of_topology topology]
      ~executors
      ~timeout:(Long_test.Seconds (8 * timeout))
    @@ fun () ->
    let* parameter_file =
      write_parameter_file
        protocol
        ~consensus_threshold:31
        ~minimal_block_delay
        ~delay_increment_per_round
    in

    Long_test.measure_and_check_regression_lwt
      ~repeat
      time_to_reach_max_level_measurement
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
        let delegates =
          [Account.Bootstrap.keys.(i mod num_bootstrap_accounts).alias]
        in
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
        (range 2 max_level)
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
      if level < max_level then (
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

        let next_cycle_level = level + blocks_per_test_cycle in
        Log.info
          "Waiting for cycle %d/%d at level %d/%d"
          (cycle + 1)
          test_cycles
          next_cycle_level
          max_level ;
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
end

module Bakers_restart = struct
  let test = "bakers restart"

  (* Go around twice to kill each baker once *)
  let num_test_cycles = 2 * num_bootstrap_accounts

  let cycle_dur = 10

  let minimal_block_delay = 4

  let timeout = cycle_dur * num_test_cycles

  let expected_min_level = 2 + (num_test_cycles / 2)

  let levels_reached_measurement = "levels-reached"

  let delay_increment_per_round = 1

  let grafana_panels : Grafana.panel list =
    let open Grafana in
    [
      Row ("Test: " ^ test);
      simple_graph
        ~title:
          (sf
             "Level reached in %d cycles (expected at least: %d)"
             num_test_cycles
             expected_min_level)
        ~yaxis_format:" levels"
        ~measurement:levels_reached_measurement
        ~test
        ~field:"duration"
        ();
    ]

  let register ~executors =
    let num_nodes = num_bootstrap_accounts in
    (* [cycle_dur] should be correlated with [minimal_block_delay] and *)
    (* [delay_increment_per_round] below. it should be long enough for
       the bakers to take a decision in each round. *)
    let topology = Clique in

    (* A vague overapproximation *)
    let timeout = (minimal_block_delay + cycle_dur) * num_test_cycles in

    Long_test.register
      ~__FILE__
      ~title:test
      ~tags:["tenderbake"; "dynamic"; "restart"]
      ~executors
      ~timeout:(Long_test.Seconds (8 * timeout))
    @@ fun () ->
    let* parameter_file =
      write_parameter_file
        protocol
        ~minimal_block_delay
        ~delay_increment_per_round
    in

    Long_test.measure_and_check_regression_lwt
      ~repeat
      levels_reached_measurement
    @@ fun () ->
    Log.info "Setup daemons" ;
    let node_daemons = ref [] in
    let baker_daemons = ref [] in

    (* One client to activate the protocol later on *)
    let* node_hd, activator_client, nodes_tl, _clients_tl =
      let create ?(add_baker = true) i =
        let node = Node.create [Synchronisation_threshold 0] in
        Log.info
          "Creating node, client%s triplet #%d (%s)"
          (if add_baker then ", baker" else "")
          i
          (Node.name node) ;
        node_daemons := node :: !node_daemons ;
        let* client = Client.init ~endpoint:(Client.Node node) () in
        let delegates =
          [Account.Bootstrap.keys.(i mod num_bootstrap_accounts).alias]
        in
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
        Lwt_list.map_s create (range 1 (num_nodes - 1))
      in
      return
        ( node_with_baker_hd,
          activator_client,
          List.map fst nodes_with_bakers,
          List.map snd nodes_with_bakers )
    in
    let nodes = node_hd :: nodes_tl in

    Log.info
      "Setting up node %s topology: %s"
      (string_of_topology topology)
      (String.concat ", " @@ List.map Node.name nodes) ;
    (cluster_of_topology topology) nodes ;

    Log.info "Starting nodes" ;
    let* () = Cluster.start ~wait_connections:true nodes in

    Log.info "Activating protocol" ;
    let* () =
      Client.activate_protocol_and_wait
        ~protocol
        ~timestamp:Client.Now
        ~parameter_file
        activator_client
    in

    let bakers = Inf.cycle !baker_daemons in

    let rec loop cycle (dead_baker, bakers) =
      if cycle < num_test_cycles then
        if
          (* in the even cycles we run all the bakers. in the odd cycles
             one is dead. we iterate cyclically through the bakers to
             choose the dead one *)
          cycle mod 2 = 0
        then (
          Log.info "Cycle %d: kill %s" cycle (Baker.name dead_baker) ;
          let* () = Baker.terminate dead_baker in
          let* () = Lwt_unix.sleep (float_of_int minimal_block_delay) in
          loop (cycle + 1) (dead_baker, bakers))
        else
          let* () =
            if cycle > 1 then (
              Log.info "Cycle %d: revive %s" cycle (Baker.name dead_baker) ;
              let* () = Baker.run dead_baker in
              unit)
            else (
              Log.info "Cycle %d: do nothing" cycle ;
              unit)
          in
          let* () = Lwt_unix.sleep (float_of_int cycle_dur) in
          loop (cycle + 1) (Inf.next bakers)
      else unit
    in

    let* () = loop 0 (Inf.next bakers) in
    let levels = List.map Node.get_level nodes in
    let min_level = List.fold_left Int.min Int.max_int levels in
    Log.info
      "Minimium level in cluster %d, expected at least: %d. Levels per node: \
       [%s]"
      min_level
      expected_min_level
      (String.concat ", " (List.map string_of_int levels)) ;

    (* Clean up for repeat *)
    let* () = Lwt_list.iter_p Baker.terminate !baker_daemons in
    let* () = Lwt_list.iter_p Node.terminate !node_daemons in

    Lwt.return (float_of_int min_level)
end

module Bakers_incremental_start = struct
  let test = "incrementally start bakers"

  let minimal_block_delay = 4

  let delay_increment_per_round = 1

  let test_duration = 5 * minimal_block_delay

  let expected_min_level = 1 + (test_duration / minimal_block_delay)

  let levels_reached_measurement = "levels-reached"

  let grafana_panels : Grafana.panel list =
    let open Grafana in
    [
      Row ("Test: " ^ test);
      simple_graph
        ~title:
          (sf
             "Level reached in %d seconds (expected at least: %d)"
             test_duration
             expected_min_level)
        ~yaxis_format:" levels"
        ~measurement:levels_reached_measurement
        ~test
        ~field:"duration"
        ();
    ]

  let register ~executors =
    let num_nodes = num_bootstrap_accounts in
    let num_early_start_nodes = 2 in
    let topology = Clique in
    (* A vague overapproximation *)
    let timeout =
      (num_early_start_nodes * minimal_block_delay) + test_duration
    in

    Long_test.register
      ~__FILE__
      ~title:test
      ~tags:["tenderbake"; "dynamic"; "incremental"]
      ~executors
      ~timeout:(Long_test.Seconds (8 * timeout))
    @@ fun () ->
    let* parameter_file =
      write_parameter_file
        protocol
        ~minimal_block_delay
        ~delay_increment_per_round
    in

    Long_test.measure_and_check_regression_lwt
      ~repeat
      levels_reached_measurement
    @@ fun () ->
    Log.info "Setup daemons" ;
    let node_daemons = ref [] in
    let baker_daemons = ref [] in

    let create ?(add_baker = true) i =
      let node = Node.create [Synchronisation_threshold 0] in
      Log.info
        "Creating node, client%s triplet #%d (%s)"
        (if add_baker then ", baker" else "")
        i
        (Node.name node) ;
      node_daemons := node :: !node_daemons ;
      let* client = Client.init ~endpoint:(Client.Node node) () in
      let delegates =
        [Account.Bootstrap.keys.(i mod num_bootstrap_accounts).alias]
      in
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
    (* One client to activate the protocol later on *)
    let* ( node_hd,
           activator_client,
           nodes_with_bakers,
           nodes_without_bakers,
           clients_without_bakers ) =
      let* node_with_baker_hd, activator_client = create 0 in
      let* nodes_with_bakers =
        Lwt_list.map_s create (range 1 (num_early_start_nodes - 1))
      in
      let* nodes_without_bakers =
        Lwt_list.map_s
          (create ~add_baker:false)
          (range num_early_start_nodes (num_nodes - 1))
      in
      return
        ( node_with_baker_hd,
          activator_client,
          List.map fst nodes_with_bakers,
          List.map fst nodes_without_bakers,
          List.map snd nodes_without_bakers )
    in
    let nodes = node_hd :: (nodes_with_bakers @ nodes_without_bakers) in

    Log.info
      "Setting up node %s topology: %s"
      (string_of_topology topology)
      (String.concat ", " @@ List.map Node.name nodes) ;
    (cluster_of_topology topology) nodes ;

    Log.info "Starting nodes" ;
    let* () = Cluster.start ~wait_connections:true ~public:true nodes in

    Log.info "Activating protocol" ;
    let* () =
      Client.activate_protocol_and_wait
        ~protocol
        ~timestamp:Client.Now
        ~parameter_file
        activator_client
    in

    Log.info "Start remaining bakers" ;
    let* () =
      Lwt_list.iteri_s
        (fun i (node, client) ->
          let node_index = num_early_start_nodes + i in
          let delegates =
            [
              Account.Bootstrap.keys.(node_index mod num_bootstrap_accounts)
                .alias;
            ]
          in
          let baker = Baker.create ~protocol node client ~delegates in
          let* () = Baker.run baker in
          baker_daemons := baker :: !baker_daemons ;
          Lwt_unix.sleep (float_of_int minimal_block_delay))
        (List.combine nodes_without_bakers clients_without_bakers)
    in

    Log.info "Wait for test duration: %d seconds" test_duration ;
    let* () = Lwt_unix.sleep (float_of_int test_duration) in

    let levels = List.map Node.get_level nodes in
    let min_level = List.fold_left Int.min Int.max_int levels in
    Log.info
      "Minimium level in cluster %d, expected at least: %d. Levels per node: \
       [%s]"
      min_level
      expected_min_level
      (String.concat ", " (List.map string_of_int levels)) ;

    (* Clean up for repeat *)
    let* () = Lwt_list.iter_p Baker.terminate !baker_daemons in
    let* () = Lwt_list.iter_p Node.terminate !node_daemons in

    Lwt.return (float_of_int min_level)
end

let grafana_panels : Grafana.panel list =
  Rounds.grafana_panels
  @ Long_dynamic_bake.grafana_panels Clique
  @ Long_dynamic_bake.grafana_panels Ring
  @ Bakers_restart.grafana_panels @ Bakers_incremental_start.grafana_panels

let register ~executors () =
  Rounds.register ~executors ;
  Long_dynamic_bake.register Clique ~executors ;
  Long_dynamic_bake.register Ring ~executors ;
  Bakers_restart.register ~executors ;
  Bakers_incremental_start.register ~executors
