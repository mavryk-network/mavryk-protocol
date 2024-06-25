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

(** [resolve_plugin protocols] tries to load [Dal_plugin.T] for
    [protocols.next_protocol]. We use [next_protocol] because we use the
    returned plugin to process the block at the next level, the block at the
    previous level being processed by the previous plugin (if any). *)
let resolve_plugin
    (protocols : Mavryk_shell_services.Chain_services.Blocks.protocols) =
  let open Lwt_syntax in
  let plugin_opt = Dal_plugin.get protocols.next_protocol in
  let* () =
    Option.iter_s
      (fun plugin ->
        let (module Plugin : Dal_plugin.T) = plugin in
        Event.(emit protocol_plugin_resolved Plugin.Proto.hash))
      plugin_opt
  in
  return plugin_opt

type error += Cryptobox_initialisation_failed of string

let () =
  register_error_kind
    `Permanent
    ~id:"dal.node.cryptobox.initialisation_failed"
    ~title:"Cryptobox initialisation failed"
    ~description:"Unable to initialise the cryptobox parameters"
    ~pp:(fun ppf msg ->
      Format.fprintf
        ppf
        "Unable to initialise the cryptobox parameters. Reason: %s"
        msg)
    Data_encoding.(obj1 (req "error" string))
    (function Cryptobox_initialisation_failed str -> Some str | _ -> None)
    (fun str -> Cryptobox_initialisation_failed str)

let fetch_dal_config cctxt =
  let open Lwt_syntax in
  let* r = Config_services.dal_config cctxt in
  match r with
  | Error e -> return_error e
  | Ok dal_config -> return_ok dal_config

let init_cryptobox config dal_config
    (proto_parameters : Dal_plugin.proto_parameters) =
  let open Lwt_result_syntax in
  (* FIXME https://gitlab.com/tezos/tezos/-/issues/6906

     We should load the verifier SRS by default.
  *)
  let prover_srs =
    match config.Configuration_file.profiles with
    | Types.Bootstrap -> false
    | Types.Random_observer -> true
    | Types.Operator l ->
        List.exists
          (function
            | Types.Attester _ -> false
            | Producer _ -> true
            | Observer _ -> true)
          l
  in
  let* () =
    if prover_srs then
      let find_srs_files () = Mavryk_base.Dal_srs.find_trusted_setup_files () in
      Cryptobox.Config.init_prover_dal ~find_srs_files dal_config
    else
      let*? () = Cryptobox.Config.init_verifier_dal dal_config in
      return_unit
  in
  match Cryptobox.make proto_parameters.cryptobox_parameters with
  | Ok cryptobox ->
      if prover_srs then
        match Cryptobox.precompute_shards_proofs cryptobox with
        | Ok precomputation -> return (cryptobox, Some precomputation)
        | Error (`Invalid_degree_strictly_less_than_expected {given; expected})
          ->
            fail
              [
                Cryptobox_initialisation_failed
                  (Printf.sprintf
                     "Cryptobox.precompute_shards_proofs: SRS size (= %d) \
                      smaller than expected (= %d)"
                     given
                     expected);
              ]
      else return (cryptobox, None)
  | Error (`Fail msg) -> fail [Cryptobox_initialisation_failed msg]

module Handler = struct
  (** [make_stream_daemon handler streamed_call] calls [handler] on each newly
      received value from [streamed_call].

      It returns a couple [(p, stopper)] where [p] is a promise resolving when the
      stream closes and [stopper] a function closing the stream.
  *)
  let make_stream_daemon handle streamed_call =
    let open Lwt_result_syntax in
    let* stream, stopper = streamed_call in
    let rec go () =
      let*! tok = Lwt_stream.get stream in
      match tok with
      | None -> return_unit
      | Some element ->
          let*! r = handle stopper element in
          let*! () =
            match r with
            | Ok () -> Lwt.return_unit
            | Error trace ->
                let*! () = Event.(emit daemon_error) trace in
                Lwt.return_unit
          in
          go ()
    in
    return (go (), stopper)

  (* [gossipsub_app_message_payload_validation cryptobox message message_id]
     allows checking whether the given [message] identified by [message_id] is
     valid with the current [cryptobox] parameters. The validity check is done
     by verifying that the shard in the message effectively belongs to the
     commitment given by [message_id]. *)
  let gossipsub_app_message_payload_validation cryptobox message_id message =
    let Types.Message.{share; shard_proof} = message in
    let Types.Message_id.{commitment; shard_index; _} = message_id in
    let shard = Cryptobox.{share; index = shard_index} in
    let res =
      Dal_metrics.sample_time
        ~sampling_frequency:Constants.shards_verification_sampling_frequency
        ~metric_updater:Dal_metrics.update_shards_verification_time
        ~to_sample:(fun () ->
          Cryptobox.verify_shard cryptobox commitment shard shard_proof)
    in
    match res with
    | Ok () -> `Valid
    | Error err ->
        let err =
          match err with
          | `Invalid_degree_strictly_less_than_expected {given; expected} ->
              Format.sprintf
                "Invalid_degree_strictly_less_than_expected. Given: %d, \
                 expected: %d"
                given
                expected
          | `Invalid_shard -> "Invalid_shard"
          | `Shard_index_out_of_range s ->
              Format.sprintf "Shard_index_out_of_range(%s)" s
          | `Shard_length_mismatch -> "Shard_length_mismatch"
        in
        Event.(
          emit__dont_wait__use_with_care
            message_validation_error
            (message_id, err)) ;
        `Invalid
    | exception exn ->
        (* Don't crash if crypto raised an exception. *)
        let err = Printexc.to_string exn in
        Event.(
          emit__dont_wait__use_with_care
            message_validation_error
            (message_id, err)) ;
        `Invalid

  (* FIXME: https://gitlab.com/tezos/tezos/-/issues/6439

     We should check:

     - That the commitment (slot index for the given level if the commitment
       field is dropped from message id) is waiting for attestation;

     - That the included shard index is indeed assigned to the included pkh;

     - That the bounds on the slot/shard indexes are respected.
  *)
  let gossipsub_message_id_validation _ctxt _cryptobox _message_id = `Valid

  (* [gossipsub_app_messages_validation ctxt cryptobox head_level
     attestation_lag ?message ~message_id ()] checks for the validity of the
     given message (if any) and message id.

     First, the message id's validity is checked if the application cares about
     it and is not outdated (Otherwise `Unknown or `Outdated is returned,
     respectively). This is done thanks to
     {!gossipsub_message_id_validation}. Then, if a message is given,
     {!gossipsub_app_message_payload_validation} is used to check its
     validity. *)
  let gossipsub_app_messages_validation ctxt cryptobox head_level
      attestation_lag ?message ~message_id () =
    if
      Node_context.get_profile_ctxt ctxt |> Profile_manager.is_bootstrap_profile
    then
      (* 1. As bootstrap nodes advertise their profiles to attester and producer
         nodes, they shouldn't receive messages or messages ids. If this
         happens, received data are considered as spam (invalid), and the remote
         peer might be punished, depending on the Gossipsub implementation. *)
      `Invalid
    else
      (* Have some slack for outdated messages. *)
      let slack = 4 in
      if
        Int32.(
          sub head_level message_id.Types.Message_id.level
          > of_int (attestation_lag + slack))
      then
        (* 2. Nodes don't care about messages whose ids are too old.  Gossipsub
           should only be used for the dissemination of fresh data. Old data could
           be retrieved using another method. *)
        `Outdated
      else
        match gossipsub_message_id_validation ctxt cryptobox message_id with
        | `Valid ->
            (* 3. Only check for message validity if the message_id is valid. *)
            Option.fold
              message
              ~none:`Valid
              ~some:
                (gossipsub_app_message_payload_validation cryptobox message_id)
        | other ->
            (* 4. In the case the message id is not Valid.

               FIXME: https://gitlab.com/tezos/tezos/-/issues/6460

               This probably include cases where the message is in the future, in
               which case we might return `Unknown for the moment. But then, when is
               the message revalidated? *)
            other

  (* Set the profile context once we have the protocol plugin. This is supposed
     to be called only once. *)
  let set_profile_context ctxt config proto_parameters =
    let open Lwt_result_syntax in
    let*! pctxt_opt = Node_context.load_profile_ctxt ctxt in
    let pctxt_opt =
      match pctxt_opt with
      | None ->
          Profile_manager.add_profiles
            Profile_manager.empty
            proto_parameters
            (Node_context.get_gs_worker ctxt)
            config.Configuration_file.profiles
      | Some pctxt ->
          let profiles = Profile_manager.get_profiles pctxt in
          (* The profiles from the loaded context are prioritized over the
             profiles provided in the config file. *)
          let merged_profiles =
            Types.merge_profiles
              ~lower_prio:config.Configuration_file.profiles
              ~higher_prio:profiles
          in
          Profile_manager.add_profiles
            Profile_manager.empty
            proto_parameters
            (Node_context.get_gs_worker ctxt)
            merged_profiles
    in
    match pctxt_opt with
    | None -> fail Errors.[Profile_incompatibility]
    | Some pctxt ->
        let*! () = Node_context.set_profile_ctxt ctxt pctxt in
        return_unit

  let resolve_plugin_and_set_ready config dal_config ctxt cctxt =
    (* Monitor heads and try resolve the DAL protocol plugin corresponding to
       the protocol of the targeted node. *)
    let open Lwt_result_syntax in
    let handler stopper (block_hash, block_header) =
      let block = `Hash (block_hash, 0) in
      let* protocols =
        Mavryk_shell_services.Chain_services.Blocks.protocols cctxt ~block ()
      in
      let*! plugin_opt = resolve_plugin protocols in
      match plugin_opt with
      | Some plugin ->
          let (module Dal_plugin : Dal_plugin.T) = plugin in
          let* proto_parameters = Dal_plugin.get_constants `Main block cctxt in
          (* FIXME: https://gitlab.com/tezos/tezos/-/issues/5743

             Instead of recompute those parameters, they could be stored
             (for a given cryptobox). *)
          let* cryptobox, shards_proofs_precomputation =
            init_cryptobox config dal_config proto_parameters
          in
          Store.Value_size_hooks.set_share_size
            (Cryptobox.Internal_for_tests.encoded_share_size cryptobox) ;
          let* () = set_profile_context ctxt config proto_parameters in
          (* We support at most 64 back-pointers, each of which takes 32 bytes.
             The cells content itself takes less than 64 bytes. *)
          let padded_encoded_cell_size = 64 * (32 + 1) in
          (* A pointer hash is 32 bytes length, but because of the double
             encoding in Dal_proto_types and then in skip_list_cells_store, we
             have an extra 4 bytes for encoding the size. *)
          let encoded_hash_size = 32 + 4 in
          let* skip_list_cells_store =
            Skip_list_cells_store.init
              ~node_store_dir:(Configuration_file.store_path config)
              ~skip_list_store_dir:"skip_list"
              ~padded_encoded_cell_size
              ~encoded_hash_size
              ~number_of_slots:
                proto_parameters.cryptobox_parameters.number_of_shards
          in
          let*? () =
            Node_context.set_ready
              ctxt
              plugin
              skip_list_cells_store
              cryptobox
              shards_proofs_precomputation
              proto_parameters
              block_header.Block_header.shell.proto_level
          in
          let*! () = Event.(emit node_is_ready ()) in
          stopper () ;
          return_unit
      | None ->
          (* FIXME: https://gitlab.com/tezos/tezos/-/issues/3605
             Handle situtation where plugin is not found *)
          return_unit
    in
    let handler stopper el =
      match Node_context.get_status ctxt with
      | Starting -> handler stopper el
      | Ready _ -> return_unit
    in
    let*! () = Event.(emit layer1_node_tracking_started_for_plugin ()) in
    make_stream_daemon
      handler
      (Mavryk_shell_services.Monitor_services.heads cctxt `Main)

  let may_update_plugin cctxt ctxt ~block ~current_proto ~block_proto =
    let open Lwt_result_syntax in
    if current_proto <> block_proto then
      let* protocols =
        Mavryk_shell_services.Chain_services.Blocks.protocols cctxt ~block ()
      in
      let*! plugin_opt = resolve_plugin protocols in
      match plugin_opt with
      | Some plugin ->
          Node_context.update_plugin_in_ready ctxt plugin block_proto ;
          return_unit
      | None ->
          let*! () = Event.(emit no_protocol_plugin ()) in
          return_unit
    else return_unit

  (* This function removes the shards corresponding to the commitments at level
     exactly [Node_context.next_shards_level_to_gc ~head_level]. In the future
     we may want to remove the shards from all preceeding levels, not only this
     one. Also, removing could be done more efficiently than iterating on all
     the slots. *)
  let remove_old_level_shards proto_parameters ctxt head_level =
    let open Lwt_result_syntax in
    let oldest_level =
      Node_context.next_shards_level_to_gc ctxt ~current_level:head_level
    in
    let number_of_slots = Dal_plugin.(proto_parameters.number_of_slots) in
    let store = Node_context.get_store ctxt in
    let*! commitments =
      List.filter_map_s
        (fun slot_index ->
          let open Lwt_syntax in
          let* result =
            Slot_manager.get_commitment_by_published_level_and_index
              ~level:oldest_level
              ~slot_index
              store
          in
          match result with
          | Error `Not_found -> return_none
          | Error (`Decoding_failed _) ->
              let*! () =
                Event.(emit decoding_data_failed Types.Store.Commitment)
              in
              return_none
          | Ok commitment -> return_some commitment)
        (WithExceptions.List.init ~loc:__LOC__ number_of_slots Fun.id)
    in
    (* TODO: https://gitlab.com/tezos/tezos/-/issues/7124
       In case of republication of the same commitment, the shards are removed
       too early *)
    List.iter_es
      (fun commitment ->
        let*! () = Event.(emit removed_slot_shards commitment) in
        Store.Shards.remove store.shard_store commitment)
      commitments

  (* Monitor heads and store *finalized* published slot headers indexed by block
     hash. A slot header is considered finalized when it is in a block with at
     least two other blocks on top of it, as guaranteed by Tenderbake. Note that
     this means that shard propagation is delayed by two levels with respect to
     the publication level of the corresponding slot header. *)
  let new_head ctxt cctxt =
    let open Lwt_result_syntax in
    let handler _stopper (head_hash, (header : Mavryk_base.Block_header.t)) =
      match Node_context.get_status ctxt with
      | Starting -> return_unit
      | Ready ready_ctxt -> (
          let Node_context.
                {
                  plugin = (module Plugin);
                  proto_parameters;
                  cryptobox;
                  shards_proofs_precomputation = _;
                  plugin_proto;
                  last_processed_level;
                  skip_list_cells_store;
                  ongoing_amplifications = _;
                } =
            ready_ctxt
          in
          Gossipsub.Worker.Validate_message_hook.set
            (gossipsub_app_messages_validation
               ctxt
               cryptobox
               head_level
               proto_parameters.attestation_lag) ;
          let* () = remove_old_level_shards proto_parameters ctxt head_level in
          let process_block block_level =
            let block = `Level block_level in
            let* block_info =
              Plugin.block_info cctxt ~block ~metadata:`Always
            in
            let shell_header = Plugin.block_shell_header block_info in
            (* TODO: https://gitlab.com/tezos/tezos/-/issues/6036
               Note that the first processed block is special: in contrast to
               the general case, as implemented by this function, the plugin was
               set before processing the block, by
               [resolve_plugin_and_set_ready], not after processing the
               block. *)
            let* () =
              may_update_plugin
                cctxt
                ctxt
                ~block
                ~current_proto:plugin_proto
                ~block_proto:shell_header.proto_level
            in
            let*? block_round = Plugin.get_round shell_header.fitness in
            let* slot_headers = Plugin.get_published_slot_headers block_info in
            let* cells_of_level =
              Plugin.Skip_list.cells_of_level block_info cctxt
            in
            let cells_of_level =
              List.map
                (fun (hash, cell) ->
                  ( Dal_proto_types.Skip_list_hash.of_proto
                      Plugin.Skip_list.hash_encoding
                      hash,
                    Dal_proto_types.Skip_list_cell.of_proto
                      Plugin.Skip_list.cell_encoding
                      cell ))
                cells_of_level
            in
            let* () =
              Skip_list_cells_store.insert
                skip_list_cells_store
                ~attested_level:head_level
                cells_of_level
            in
            let* () =
              Slot_manager.store_slot_headers
                ~number_of_slots:proto_parameters.number_of_slots
                ~block_level
                slot_headers
                (Node_context.get_store ctxt)
            in
            let* () =
              (* If a slot header was posted to the L1 and we have the corresponding
                     data, post it to gossipsub.

                 FIXME: https://gitlab.com/tezos/tezos/-/issues/5973
                 Should we restrict published slot data to the slots for which
                 we have the producer role?
              *)
              List.iter_es
                (fun (slot_header, status) ->
                  match status with
                  | Dal_plugin.Succeeded ->
                      let Dal_plugin.{slot_index; commitment; published_level} =
                        slot_header
                      in
                      Slot_manager.publish_slot_data
                        ~level_committee:(Node_context.fetch_committee ctxt)
                        (Node_context.get_store ctxt)
                        (Node_context.get_gs_worker ctxt)
                        cryptobox
                        proto_parameters
                        commitment
                        published_level
                        slot_index
                  | Dal_plugin.Failed -> return_unit)
                slot_headers
            in
            let*? attested_slots =
              Plugin.attested_slot_headers
                block_info
                ~number_of_slots:proto_parameters.number_of_slots
            in
            let*! () =
              Slot_manager.update_selected_slot_headers_statuses
                ~block_level
                ~attestation_lag:proto_parameters.attestation_lag
                ~number_of_slots:proto_parameters.number_of_slots
                attested_slots
                (Node_context.get_store ctxt)
            in
            let* committee =
              Node_context.fetch_committee ctxt ~level:block_level
            in
            let () =
              Profile_manager.on_new_head
                (Node_context.get_profile_ctxt ctxt)
                proto_parameters
                (Node_context.get_gs_worker ctxt)
                committee
            in
            (* This should be the last modification of this node's (ready) context. *)
            let*? () =
              Node_context.update_last_processed_level ctxt ~level:block_level
            in
            Dal_metrics.layer1_block_finalized ~block_level ;
            Dal_metrics.layer1_block_finalized_round ~block_round ;
            let*! () =
              Event.(emit layer1_node_final_block (block_level, block_round))
            in
            return_unit
          in
          match last_processed_level with
          (* TODO: https://gitlab.com/tezos/tezos/-/issues/6849
             Depending on the profile, also process blocks in the past, that is,
             when [last_processed_level < head_level - 3]. *)
          | Some last_processed_level
            when Int32.(sub head_level last_processed_level = 3l) ->
              (* Then the block at level [last_processed_level + 1] is final
                 (not only its payload), therefore its DAL attestations are
                 final. *)
              process_block (Int32.succ last_processed_level)
          | None ->
              (* This is the first time we process a block. *)
              if head_level > 3l then process_block (Int32.sub head_level 2l)
              else
                (* We do not process the block at level 1, as it will not contain DAL
                   information, and it has no round. *)
                return_unit
          | Some _ ->
              (* This case is unreachable, assuming [Monitor_services.heads] does not
                 skip levels. *)
              return_unit)
    in
    let*! () = Event.(emit layer1_node_tracking_started ()) in
    (* FIXME: https://gitlab.com/tezos/tezos/-/issues/3517
        If the layer1 node reboots, the rpc stream breaks.*)
    make_stream_daemon
      handler
      (Mavryk_shell_services.Monitor_services.heads cctxt `Main)
end

let daemonize handlers =
  (* FIXME: https://gitlab.com/tezos/tezos/-/issues/3605
     Improve concurrent tasks by using workers *)
  let open Lwt_result_syntax in
  let* handlers = List.map_es (fun x -> x) handlers in
  let (_ : Lwt_exit.clean_up_callback_id) =
    (* close the stream when an exit signal is received *)
    Lwt_exit.register_clean_up_callback ~loc:__LOC__ (fun _exit_status ->
        List.iter (fun (_, stopper) -> stopper ()) handlers ;
        Lwt.return_unit)
  in
  (let* _ = all (List.map fst handlers) in
   return_unit)
  |> lwt_map_error (List.fold_left (fun acc errs -> errs @ acc) [])

let connect_gossipsub_with_p2p gs_worker transport_layer node_store node_ctxt =
  let open Gossipsub in
  let shards_handler ({shard_store; _} : Store.node_store) =
    let save_and_notify = Store.Shards.save_and_notify shard_store in
    fun Types.Message.{share; _}
        Types.Message_id.{commitment; shard_index; level; slot_index; _} ->
      let open Lwt_result_syntax in
      let* () =
        Seq.return {Cryptobox.share; index = shard_index}
        |> save_and_notify commitment |> Errors.to_tzresult
      in
      match
        Profile_manager.get_profiles @@ Node_context.get_profile_ctxt node_ctxt
      with
      | Operator profile_list
        when List.exists
               (function
                 | Types.Observer {slot_index = index} -> index = slot_index
                 | _ -> false)
               profile_list ->
          Amplificator.try_amplification
            shard_store
            node_store
            commitment
            ~published_level:level
            ~slot_index
            gs_worker
            node_ctxt
      | _ -> return_unit
  in
  Lwt.dont_wait
    (fun () ->
      Transport_layer_hooks.activate
        gs_worker
        transport_layer
        ~app_messages_callback:(shards_handler node_store))
    (fun exn ->
      "[dal_node] error in Daemon.connect_gossipsub_with_p2p: "
      ^ Printexc.to_string exn
      |> Stdlib.failwith)

let resolve peers =
  List.concat_map_es
    (Mavryk_base_unix.P2p_resolve.resolve_addr
       ~default_addr:"::"
       ~default_port:(Configuration_file.default.listen_addr |> snd))
    peers

let wait_for_l1_bootstrapped (cctxt : Rpc_context.t) =
  let open Lwt_result_syntax in
  let*! () = Event.(emit waiting_l1_node_bootstrapped) () in
  let* stream, _stop = Monitor_services.bootstrapped cctxt in
  let*! () =
    Lwt_stream.iter_s (fun (_hash, _timestamp) -> Lwt.return_unit) stream
  in
  let*! () = Event.(emit l1_node_bootstrapped) () in
  return_unit

(* FIXME: https://gitlab.com/tezos/tezos/-/issues/3605
   Improve general architecture, handle L1 disconnection etc
*)
let run ~data_dir configuration_override =
  let open Lwt_result_syntax in
  let log_cfg = Mavryk_base_unix.Logs_simple_config.default_cfg in
  let internal_events =
    Mavryk_base_unix.Internal_event_unix.make_with_defaults
      ~enable_default_daily_logs_at:Filename.Infix.(data_dir // "daily_logs")
      ~log_cfg
      ()
  in
  let*! () =
    Mavryk_base_unix.Internal_event_unix.init ~config:internal_events ()
  in
  let*! () = Event.(emit starting_node) () in
  let* ({
          network_name;
          rpc_addr;
          peers;
          endpoint;
          profiles;
          listen_addr;
          public_addr;
          _;
        } as config) =
    let*! result = Configuration_file.load ~data_dir in
    match result with
    | Ok configuration -> return (configuration_override configuration)
    | Error _ ->
        let*! () = Event.(emit data_dir_not_found data_dir) in
        (* Store the default configuration if no configuration were found. *)
        let configuration = configuration_override Configuration_file.default in
        let* () = Configuration_file.save configuration in
        return configuration
  in
  let*! () = Event.(emit configuration_loaded) () in
  (* Create and start a GS worker *)
  let gs_worker =
    let rng =
      let seed =
        Random.self_init () ;
        Random.bits ()
      in
      Random.State.make [|seed|]
    in
    let open Worker_parameters in
    let limits =
      match profiles with
      | Types.Bootstrap ->
          (* Bootstrap nodes should always have a mesh size of zero.
             so all grafts are responded with prunes with PX. See:
             https://github.com/libp2p/specs/blob/f5c5829ef9753ef8b8a15d36725c59f0e9af897e/pubsub/gossipsub/gossipsub-v1.1.md#recommendations-for-network-operators

             Additionally, we set [max_sent_iwant_per_heartbeat = 0]
             so bootstrap nodes do not download any shards via IHave/IWant
             transfers. *)
          {
            limits with
            max_sent_iwant_per_heartbeat = 0;
            degree_low = 0;
            degree_high = 0;
            degree_out = 0;
            degree_optimal = 0;
            degree_score = 0;
          }
      | Operator _ -> limits
    in
    let gs_worker =
      Gossipsub.Worker.(
        make ~events_logging:Logging.event rng limits peer_filter_parameters)
    in
    Gossipsub.Worker.start [] gs_worker ;
    gs_worker
  in
  (* Create a transport (P2P) layer instance. *)
  let* transport_layer =
    let open Transport_layer_parameters in
    let* p2p_config = p2p_config config in
    Gossipsub.Transport_layer.create
      ~public_addr
      ~is_bootstrap_peer:(profiles = Types.Bootstrap)
      p2p_config
      p2p_limits
      ~network_name
  in
  let* store = Store.init config in
  let cctxt = Rpc_context.make endpoint in
  let*! metrics_server = Metrics.launch config.metrics_addr in
  let ctxt =
    Node_context.init
      config
      store
      gs_worker
      transport_layer
      cctxt
      metrics_server
  in
  let* rpc_server = RPC_server.(start config ctxt) in
  connect_gossipsub_with_p2p gs_worker transport_layer store ctxt ;
  (* activate the p2p instance. *)
  let*! () =
    Gossipsub.Transport_layer.activate ~additional_points:points transport_layer
  in
  let*! () = Event.(emit p2p_server_is_ready listen_addr) in
  let _ = RPC_server.install_finalizer rpc_server in
  let*! () = Event.(emit rpc_server_is_ready rpc_addr) in
  (* Start collecting stats related to the Gossipsub worker. *)
  Dal_metrics.collect_gossipsub_metrics gs_worker ;
  (* First wait for the L1 node to be bootstrapped. *)
  let* () = wait_for_l1_bootstrapped cctxt in
  (* Start daemon to resolve current protocol plugin *)
  let* () =
    daemonize
      [Handler.resolve_plugin_and_set_ready config dal_config ctxt cctxt]
  in
  (* Start never-ending monitoring daemons *)
  let* () = daemonize [Handler.new_head ctxt cctxt] in
  return_unit
