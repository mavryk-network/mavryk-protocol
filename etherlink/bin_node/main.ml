(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(* Copyright (c) 2023-2024 Functori <contact@functori.com>                   *)
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

open Configuration

module Event = struct
  let section = ["evm_node"]

  let event_starting =
    Internal_event.Simple.declare_1
      ~section
      ~name:"start"
      ~msg:"starting the EVM node ({mode})"
      ~level:Notice
      ("mode", Data_encoding.string)
end

module Params = struct
  let string = Tezos_clic.parameter (fun _ s -> Lwt.return_ok s)

  let int = Tezos_clic.parameter (fun _ s -> Lwt.return_ok (int_of_string s))

  let endpoint =
    Tezos_clic.parameter (fun _ uri -> Lwt.return_ok (Uri.of_string uri))

  let rollup_node_endpoint = endpoint

  let evm_node_endpoint = endpoint

  let sequencer_key =
    Tezos_clic.param
      ~name:"sequencer-key"
      ~desc:"key to sign the blueprints."
      string

  let string_list =
    Tezos_clic.parameter (fun _ s ->
        let list = String.split ',' s in
        Lwt.return_ok list)

  let time_between_blocks =
    Tezos_clic.parameter (fun _ s ->
        let time_between_blocks =
          if s = "none" then Nothing
          else Time_between_blocks (Float.of_string s)
        in
        Lwt.return_ok time_between_blocks)

  let timestamp =
    let open Lwt_result_syntax in
    Tezos_clic.parameter (fun _ timestamp ->
        let timestamp = String.trim timestamp in
        match Time.Protocol.of_notation timestamp with
        | Some t -> return t
        | None -> (
            match
              Int64.of_string_opt timestamp
              |> Option.map Time.Protocol.of_seconds
            with
            | Some t -> return t
            | None ->
                failwith
                  "Timestamp must be either in RFC3399 format  (e.g., \
                   [\"1970-01-01T00:00:00Z\"]) or in number of seconds since \
                   the {!Time.Protocol.epoch}."))

  let l2_address =
    Tezos_clic.parameter (fun _ s ->
        let hex_addr =
          Option.value ~default:s @@ String.remove_prefix ~prefix:"0x" s
        in
        Lwt.return_ok
        @@ Evm_node_lib_dev_encoding.Ethereum_types.(Address (Hex hex_addr)))
end

let wallet_dir_arg =
  Tezos_clic.default_arg
    ~long:"wallet-dir"
    ~short:'d'
    ~placeholder:"path"
    ~default:Client_config.default_base_dir
    ~doc:
      (Format.asprintf
         "@[<v>@[<2>client data directory (absent: %s env)@,\
          The directory where the Tezos client stores all its wallet data.@,\
          If absent, its value is the value of the %s@,\
          environment variable. If %s is itself not specified,@,\
          defaults to %s@]@]@."
         Client_config.base_dir_env_name
         Client_config.base_dir_env_name
         Client_config.base_dir_env_name
         Client_config.default_base_dir)
    Params.string

let rpc_addr_arg =
  Tezos_clic.arg
    ~long:"rpc-addr"
    ~placeholder:"ADDR"
    ~doc:"The EVM node server rpc address."
    Params.string

let rpc_port_arg =
  Tezos_clic.arg
    ~long:"rpc-port"
    ~placeholder:"PORT"
    ~doc:"The EVM node server rpc port."
    Params.int

let private_rpc_port_arg =
  Tezos_clic.arg
    ~long:"private-rpc-port"
    ~placeholder:"PORT"
    ~doc:"The EVM node private server rpc port."
    Params.int

let maximum_blueprints_lag_arg =
  Tezos_clic.default_arg
    ~long:"maximum-blueprints-lag"
    ~placeholder:"LAG"
    ~default:"500"
    ~doc:
      "The maximum advance (in blueprints) the Sequencer accepts to have \
       before trying to send its backlog again."
    Params.int

let maximum_blueprints_ahead_arg =
  Tezos_clic.default_arg
    ~long:"maximum-blueprints-ahead"
    ~placeholder:"AHEAD"
    ~default:"100"
    ~doc:"The maximum advance (in blueprints) the Sequencer accepts"
    Params.int

let maximum_blueprints_catchup_arg =
  Tezos_clic.default_arg
    ~long:"maximum-blueprints-catch-up"
    ~placeholder:"CATCH_UP"
    ~default:"1_000"
    ~doc:"The maximum number of blueprints the Sequencer resends at once."
    Params.int

let catchup_cooldown_arg =
  Tezos_clic.default_arg
    ~long:"catch-up-cooldown"
    ~placeholder:"COOLDOWN"
    ~default:"10"
    ~doc:
      "The maximum number of Layer 1 blocks the Sequencer waits after \
       resending its blueprints before trying to catch-up again."
    Params.int

let cors_allowed_headers_arg =
  Tezos_clic.arg
    ~long:"cors-headers"
    ~placeholder:"ALLOWED_HEADERS"
    ~doc:"List of accepted cors headers."
    Params.string_list

let cors_allowed_origins_arg =
  Tezos_clic.arg
    ~long:"cors-origins"
    ~placeholder:"ALLOWED_ORIGINS"
    ~doc:"List of accepted cors origins."
    Params.string_list

let devmode_arg =
  Tezos_clic.switch ~long:"devmode" ~doc:"The EVM node in development mode." ()

let keep_everything_arg =
  Tezos_clic.switch
    ~short:'k'
    ~long:"keep-everything"
    ~doc:"Do not filter out files outside of the `/evm` directory"
    ()

let verbose_arg =
  Tezos_clic.switch
    ~short:'v'
    ~long:"verbose"
    ~doc:"Sets logging level to debug. Beware, it is highly verbose."
    ()

let data_dir_arg =
  let default = Configuration.default_data_dir in
  Tezos_clic.default_arg
    ~long:"data-dir"
    ~placeholder:"data-dir"
    ~doc:"The path to the EVM node data directory"
    ~default
    Params.string

let rollup_address_arg =
  let open Lwt_result_syntax in
  let open Tezos_clic in
  parameter (fun _ hash ->
      let hash_opt =
        Tezos_crypto.Hashed.Smart_rollup_address.of_b58check_opt hash
      in
      match hash_opt with
      | Some hash -> return hash
      | None ->
          failwith
            "Parameter '%s' is an invalid smart rollup address encoded in a \
             base58 string."
            hash)
  |> default_arg
       ~long:"rollup-address"
       ~doc:
         "The smart rollup address in Base58 encoding used to produce the \
          chunked messages"
       ~default:Tezos_crypto.Hashed.Smart_rollup_address.(to_b58check zero)
       ~placeholder:"sr1..."

let kernel_arg =
  Tezos_clic.arg
    ~long:"initial-kernel"
    ~placeholder:"evm_installer.wasm"
    ~doc:
      "Path to the EVM kernel used to launch the PVM, it will be loaded from \
       storage afterward"
    Params.string

let preimages_arg =
  Tezos_clic.arg
    ~long:"preimages-dir"
    ~doc:"Path to the preimages directory"
    ~placeholder:"_evm_installer_preimages"
    Params.string

let uri_parameter =
  Tezos_clic.parameter (fun () s -> Lwt.return_ok (Uri.of_string s))

let preimages_endpoint_arg =
  Tezos_clic.arg
    ~long:"preimages-endpoint"
    ~placeholder:"url"
    ~doc:
      "The address of a service which provides pre-images for the rollup. \
       Missing pre-images will be downloaded remotely if they are not already \
       present on disk."
    uri_parameter

let rollup_node_endpoint_param =
  Tezos_clic.param
    ~name:"rollup-node-endpoint"
    ~desc:
      "The address of a service which provides pre-images for the rollup. \
       Missing pre-images will be downloaded remotely if they are not already \
       present on disk."
    uri_parameter

let time_between_blocks_arg =
  Tezos_clic.arg
    ~long:"time-between-blocks"
    ~doc:"Interval at which the sequencer creates an empty block by default."
    ~placeholder:"10."
    Params.time_between_blocks

let max_number_of_chunks_arg =
  Tezos_clic.arg
    ~long:"max-number-of-chunks"
    ~doc:"Maximum number of chunks per blueprint."
    ~placeholder:"10."
    Params.int

let keep_alive_arg =
  Tezos_clic.switch
    ~doc:
      "Keep the EVM node process alive even if the connection is lost with the \
       rollup node."
    ~short:'K'
    ~long:"keep-alive"
    ()

let blueprint_mode_arg =
  Tezos_clic.switch
    ~long:"as-blueprint"
    ~doc:"Chunk the data into a blueprint usable in sequencer mode"
    ()

let timestamp_arg =
  Params.timestamp
  |> Tezos_clic.default_arg
       ~long:"timestamp"
       ~doc:""
       ~placeholder:"1970-01-01T00:00:00Z"
       ~default:"0"

let genesis_timestamp_arg =
  Params.timestamp
  |> Tezos_clic.arg
       ~long:"genesis-timestamp"
       ~doc:
         "Timestamp used for the genesis block, uses machine's clock if not \
          provided"
       ~placeholder:"1970-01-01T00:00:00Z"

let blueprint_number_arg =
  let open Lwt_result_syntax in
  let open Tezos_clic in
  parameter (fun _ number ->
      try String.trim number |> Z.of_string |> return
      with _ -> failwith "Blueprint number must be an integer")
  |> default_arg
       ~long:"number"
       ~doc:"Level of the blueprint"
       ~placeholder:"0"
       ~default:"0"

let parent_hash_arg =
  let open Lwt_result_syntax in
  let open Tezos_clic in
  parameter (fun _ hash -> return hash)
  |> default_arg
       ~long:"parent-hash"
       ~doc:"Blueprint's parent hash"
       ~placeholder:
         "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
       ~default:
         "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

let tx_pool_timeout_limit_arg =
  Tezos_clic.default_arg
    ~long:"tx-pool-timeout-limit"
    ~placeholder:"3_600"
    ~default:"3_600"
    ~doc:"Transaction timeout limit inside the transaction pool (in seconds)."
    Params.int

let tx_pool_addr_limit_arg =
  Tezos_clic.default_arg
    ~long:"tx-pool-addr-limit"
    ~placeholder:"4_000"
    ~default:"4_000"
    ~doc:"Maximum allowed addresses inside the transaction pool."
    Params.int

let tx_pool_tx_per_addr_limit_arg =
  Tezos_clic.default_arg
    ~long:"tx-pool-tx-per-addr-limit"
    ~placeholder:"16"
    ~default:"16"
    ~doc:
      "Maximum allowed transactions per user address inside the transaction \
       pool."
    Params.int

let sequencer_key_arg =
  Tezos_clic.arg
    ~long:"sequencer-key"
    ~doc:"key to sign the blueprints."
    ~placeholder:"edsk..."
    Params.string

let proxy_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Start the EVM node in proxy mode"
    (args8
       data_dir_arg
       devmode_arg
       rpc_addr_arg
       rpc_port_arg
       cors_allowed_origins_arg
       cors_allowed_headers_arg
       verbose_arg
       keep_alive_arg)
    (prefixes ["run"; "proxy"; "with"; "endpoint"]
    @@ param
         ~name:"rollup-node-endpoint"
         ~desc:
           "The smart rollup node endpoint address (as ADDR:PORT) the node \
            will communicate with."
         Params.rollup_node_endpoint
    @@ stop)
    (fun ( data_dir,
           devmode,
           rpc_addr,
           rpc_port,
           cors_origins,
           cors_headers,
           verbose,
           keep_alive )
         rollup_node_endpoint
         () ->
      let*! () =
        let open Tezos_base_unix.Internal_event_unix in
        let config =
          if verbose then Some (make_with_defaults ~verbosity:Debug ())
          else None
        in
        init ?config ()
      in
      let*! () = Internal_event.Simple.emit Event.event_starting "proxy" in
      let* config =
        Cli.create_or_read_config
          ~data_dir
          ~devmode
          ?rpc_addr
          ?rpc_port
          ?cors_origins
          ?cors_headers
          ~proxy:{rollup_node_endpoint}
          ()
      in
      let* () = Configuration.save ~force:true ~data_dir config in
      let* () =
        if config.devmode then
          Evm_node_lib_dev.Proxy.main config ~keep_alive ~rollup_node_endpoint
        else
          Evm_node_lib_prod.Proxy.main config ~keep_alive ~rollup_node_endpoint
      in

      let wait, _resolve = Lwt.wait () in
      let* () = wait in
      return_unit)

let register_wallet ?password_filename ~wallet_dir () =
  let wallet_ctxt =
    new Client_context_unix.unix_io_wallet
      ~base_dir:wallet_dir
      ~password_filename
  in
  let () =
    Client_main_run.register_default_signer
      (wallet_ctxt :> Client_context.io_wallet)
  in
  wallet_ctxt

let sequencer_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Start the EVM node in sequencer mode"
    (args23
       data_dir_arg
       rpc_addr_arg
       rpc_port_arg
       private_rpc_port_arg
       cors_allowed_origins_arg
       cors_allowed_headers_arg
       verbose_arg
       kernel_arg
       preimages_arg
       preimages_endpoint_arg
       time_between_blocks_arg
       genesis_timestamp_arg
       maximum_blueprints_lag_arg
       maximum_blueprints_ahead_arg
       maximum_blueprints_catchup_arg
       catchup_cooldown_arg
       max_number_of_chunks_arg
       devmode_arg
       wallet_dir_arg
       tx_pool_timeout_limit_arg
       tx_pool_addr_limit_arg
       tx_pool_tx_per_addr_limit_arg
       (Client_config.password_filename_arg ()))
    (prefixes ["run"; "sequencer"; "with"; "endpoint"]
    @@ param
         ~name:"rollup-node-endpoint"
         ~desc:
           "The smart rollup node endpoint address (as ADDR:PORT) the node \
            will communicate with."
         Params.rollup_node_endpoint
    @@ prefixes ["signing"; "with"]
    @@ Params.sequencer_key @@ stop)
    (fun ( data_dir,
           rpc_addr,
           rpc_port,
           private_rpc_port,
           cors_origins,
           cors_headers,
           verbose,
           kernel,
           preimages,
           preimages_endpoint,
           time_between_blocks,
           genesis_timestamp,
           max_blueprints_lag,
           max_blueprints_ahead,
           max_blueprints_catchup,
           catchup_cooldown,
           max_number_of_chunks,
           devmode,
           wallet_dir,
           tx_pool_timeout_limit,
           tx_pool_addr_limit,
           tx_pool_tx_per_addr_limit,
           password_filename )
         rollup_node_endpoint
         sequencer_str
         () ->
      let wallet_ctxt = register_wallet ?password_filename ~wallet_dir () in
      let* sequencer =
        Client_keys.Secret_key.parse_source_string wallet_ctxt sequencer_str
      in
      let* pk_uri = Client_keys.neuterize sequencer in
      let* sequencer_pkh, _ = Client_keys.public_key_hash pk_uri in
      let*! () =
        let open Tezos_base_unix.Internal_event_unix in
        let verbosity = if verbose then Some Internal_event.Debug else None in
        let config =
          make_with_defaults
            ?verbosity
            ~enable_default_daily_logs_at:
              Filename.Infix.(data_dir // "daily_logs")
              (* Show only above Info rpc_server events, they are not
                 relevant as we do not have a REST-API server. If not
                 set, the daily logs are polluted with these
                 uninformative logs. *)
            ~daily_logs_section_prefixes:
              [
                ("rpc_server", Notice);
                ("rpc_server", Warning);
                ("rpc_server", Error);
                ("rpc_server", Fatal);
              ]
            ()
        in
        init ~config ()
      in
      let*! () = Internal_event.Simple.emit Event.event_starting "sequencer" in
      let* configuration =
        let sequencer =
          Configuration.sequencer_config_dft
            ?preimages
            ?preimages_endpoint
            ?time_between_blocks
            ?max_number_of_chunks
            ?private_rpc_port
            ~rollup_node_endpoint
            ~sequencer:sequencer_pkh
            ()
        in
        Cli.create_or_read_config
          ~data_dir
          ~devmode
          ?rpc_addr
          ?rpc_port
          ?cors_origins
          ?cors_headers
          ~tx_pool_timeout_limit:(Int64.of_int tx_pool_timeout_limit)
          ~tx_pool_addr_limit:(Int64.of_int tx_pool_addr_limit)
          ~tx_pool_tx_per_addr_limit:(Int64.of_int tx_pool_tx_per_addr_limit)
          ~sequencer
          ()
      in
      let* () = Configuration.save ~force:true ~data_dir configuration in
      if devmode then
        Evm_node_lib_dev.Sequencer.main
          ~data_dir
          ~rollup_node_endpoint
          ~max_blueprints_lag
          ~max_blueprints_ahead
          ~max_blueprints_catchup
          ~catchup_cooldown
          ?genesis_timestamp
          ~cctxt:(wallet_ctxt :> Client_context.wallet)
          ~sequencer
          ~configuration
          ?kernel
          ()
      else
        Evm_node_lib_prod.Sequencer.main
          ~data_dir
          ~rollup_node_endpoint
          ~max_blueprints_lag
          ~max_blueprints_ahead
          ~max_blueprints_catchup
          ~catchup_cooldown
          ?genesis_timestamp
          ~cctxt:(wallet_ctxt :> Client_context.wallet)
          ~sequencer
          ~configuration
          ?kernel
          ())

let observer_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Start the EVM node in observer mode"
    (args9
       data_dir_arg
       rpc_addr_arg
       rpc_port_arg
       cors_allowed_origins_arg
       cors_allowed_headers_arg
       verbose_arg
       kernel_arg
       preimages_arg
       preimages_endpoint_arg)
    (prefixes ["run"; "observer"; "with"; "endpoint"]
    @@ param
         ~name:"evm-node-endpoint"
         ~desc:
           "The EVM node endpoint address (as ADDR:PORT) the node will \
            communicate with."
         Params.evm_node_endpoint
    @@ prefixes ["and"; "rollup"; "node"; "endpoint"]
    @@ rollup_node_endpoint_param @@ stop)
  @@ fun ( data_dir,
           rpc_addr,
           rpc_port,
           cors_origins,
           cors_headers,
           verbose,
           kernel,
           preimages,
           preimages_endpoint )
             evm_node_endpoint
             rollup_node_endpoint
             () ->
  let open Evm_node_lib_dev in
  let*! () =
    let open Tezos_base_unix.Internal_event_unix in
    let config =
      if verbose then Some (make_with_defaults ~verbosity:Debug ()) else None
    in
    init ?config ()
  in
  let*! () = Internal_event.Simple.emit Event.event_starting "observer" in
  let* config =
    let observer =
      Configuration.observer_config_dft
        ?preimages
        ?preimages_endpoint
        ~evm_node_endpoint
        ()
    in
    Cli.create_or_read_config
      ~data_dir
      ~devmode:true
      ?rpc_addr
      ?rpc_port
      ?cors_origins
      ?cors_headers
      ~observer
      ()
  in
  let* () = Configuration.save ~force:true ~data_dir config in
  Observer.main
    ?kernel_path:kernel
    ~rollup_node_endpoint
    ~evm_node_endpoint
    ~data_dir
    ~config
    ()

let make_prod_messages ~kind ~smart_rollup_address data =
  let open Lwt_result_syntax in
  let open Evm_node_lib_dev in
  let open Evm_node_lib_dev_encoding in
  let transactions =
    List.map
      (fun s -> Ethereum_types.hex_of_string s |> Ethereum_types.hex_to_bytes)
      data
  in
  let* messages =
    match kind with
    | `Blueprint (cctxt, sk_uri, timestamp, number, parent_hash) ->
        let* blueprint =
          Sequencer_blueprint.create
            ~cctxt
            ~sequencer_key:sk_uri
            ~timestamp
            ~smart_rollup_address
            ~number:(Ethereum_types.quantity_of_z number)
            ~parent_hash:(Ethereum_types.block_hash_of_string parent_hash)
            ~transactions
            ~delayed_transactions:[]
        in
        return @@ List.map (fun (`External s) -> s) blueprint
    | `Transaction ->
        let*? chunks =
          List.map_e
            (fun tx ->
              Transaction_format.make_encoded_messages ~smart_rollup_address tx)
            transactions
        in
        return (chunks |> List.map snd |> List.flatten)
  in
  return (List.map (fun m -> m |> Hex.of_string |> Hex.show) messages)

let make_dev_messages ~kind ~smart_rollup_address data =
  let open Lwt_result_syntax in
  let open Evm_node_lib_dev in
  let open Evm_node_lib_dev_encoding in
  let transactions =
    List.map
      (fun s -> Ethereum_types.hex_of_string s |> Ethereum_types.hex_to_bytes)
      data
  in
  let* messages =
    match kind with
    | `Blueprint (cctxt, sk_uri, timestamp, number, parent_hash) ->
        let* blueprint =
          Sequencer_blueprint.create
            ~cctxt
            ~sequencer_key:sk_uri
            ~timestamp
            ~smart_rollup_address
            ~number:(Ethereum_types.quantity_of_z number)
            ~parent_hash:(Ethereum_types.block_hash_of_string parent_hash)
            ~transactions
            ~delayed_transactions:[]
        in
        return @@ List.map (fun (`External s) -> s) blueprint
    | `Transaction ->
        let*? chunks =
          List.map_e
            (fun tx ->
              Transaction_format.make_encoded_messages ~smart_rollup_address tx)
            transactions
        in
        return (chunks |> List.map snd |> List.flatten)
  in
  return (List.map (fun m -> m |> Hex.of_string |> Hex.show) messages)

let from_data_or_file data_for_file =
  let open Lwt_result_syntax in
  Client_aliases.parse_alternatives
    [
      ( "file",
        fun filename ->
          Lwt.catch
            (fun () ->
              let*! data = Lwt_utils_unix.read_file filename in
              return @@ String.split_on_char ' ' (String.trim data))
            (fun exn ->
              failwith "cannot read file (%s)" (Printexc.to_string exn)) );
      ("data", fun data -> return [data]);
    ]
    data_for_file

let chunker_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:
      "Chunk hexadecimal data according to the message representation of the \
       EVM rollup"
    (args9
       devmode_arg
       rollup_address_arg
       blueprint_mode_arg
       timestamp_arg
       blueprint_number_arg
       parent_hash_arg
       sequencer_key_arg
       wallet_dir_arg
       (Client_config.password_filename_arg ()))
    (prefixes ["chunk"; "data"]
    @@ seq_of_param
    @@ param
         ~name:"data or file"
         ~desc:
           "Data to prepare and chunk with the EVM rollup format. If the data \
            is prefixed with `file:`, the content is read from the given \
            filename and can contain a list of data separated by a whitespace."
         (Tezos_clic.parameter (fun _ -> from_data_or_file)))
    (fun ( devmode,
           rollup_address,
           as_blueprint,
           blueprint_timestamp,
           blueprint_number,
           blueprint_parent_hash,
           sequencer_str,
           wallet_dir,
           password_filename )
         data
         () ->
      let* kind =
        if as_blueprint then
          let*! sequencer_str =
            match sequencer_str with
            | Some k -> Lwt.return k
            | None -> Lwt.fail_with "missing sequencer key"
          in
          let wallet_ctxt = register_wallet ?password_filename ~wallet_dir () in
          let+ sequencer_key =
            Client_keys.Secret_key.parse_source_string wallet_ctxt sequencer_str
          in
          `Blueprint
            ( wallet_ctxt,
              sequencer_key,
              blueprint_timestamp,
              blueprint_number,
              blueprint_parent_hash )
        else return `Transaction
      in
      let data = List.flatten data in
      let print_chunks smart_rollup_address data =
        let* messages =
          if devmode then make_dev_messages ~kind ~smart_rollup_address data
          else make_prod_messages ~kind ~smart_rollup_address data
        in
        Format.printf "Chunked transactions :\n%!" ;
        List.iter (Format.printf "%s\n%!") messages ;
        return_unit
      in
      let rollup_address =
        Tezos_crypto.Hashed.Smart_rollup_address.to_string rollup_address
      in
      print_chunks rollup_address data)

let make_upgrade_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Create bytes payload for the upgrade entrypoint"
    (args1 devmode_arg)
    (prefixes ["make"; "upgrade"; "payload"; "with"; "root"; "hash"]
    @@ param
         ~name:"preimage_hash"
         ~desc:"Root hash of the kernel to upgrade to"
         Params.string
    @@ prefixes ["at"; "activation"; "timestamp"]
    @@ param
         ~name:"activation_timestamp"
         ~desc:
           "After activation timestamp, the kernel will upgrade to this value"
         Params.timestamp
    @@ stop)
    (fun devmode root_hash timestamp () ->
      let payload =
        if devmode then
          Evm_node_lib_dev_encoding.Ethereum_types.Upgrade.(
            to_bytes @@ {hash = Hash (Hex root_hash); timestamp})
        else
          Evm_node_lib_prod_encoding.Ethereum_types.Upgrade.(
            to_bytes @@ {hash = Hash (Hex root_hash); timestamp})
      in
      Printf.printf "%s%!" Hex.(of_bytes payload |> show) ;
      return_unit)

let make_sequencer_upgrade_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Create bytes payload for the sequencer upgrade entrypoint"
    (args2 wallet_dir_arg devmode_arg)
    (prefixes ["make"; "sequencer"; "upgrade"; "payload"]
    @@ prefixes ["with"; "pool"; "address"]
    @@ Tezos_clic.param
         ~name:"pool_address"
         ~desc:"pool address of the sequencer"
         Params.l2_address
    @@ prefixes ["at"; "activation"; "timestamp"]
    @@ param
         ~name:"activation_timestamp"
         ~desc:
           "After activation timestamp, the kernel will upgrade to this value"
         Params.timestamp
    @@ prefix "for" @@ Params.sequencer_key @@ stop)
    (fun (wallet_dir, devmode)
         pool_address
         activation_timestamp
         sequencer_str
         () ->
      let wallet_ctxt = register_wallet ~wallet_dir () in
      let* _pk_uri, sequencer_pk_opt =
        Client_keys.Public_key.parse_source_string wallet_ctxt sequencer_str
      in
      let*? sequencer =
        Option.to_result
          ~none:[error_of_fmt "invalid format or unknown public key."]
          sequencer_pk_opt
      in
      let* payload =
        if devmode then
          let open Evm_node_lib_dev_encoding.Ethereum_types in
          let sequencer_upgrade : Sequencer_upgrade.t =
            {sequencer; pool_address; timestamp = activation_timestamp}
          in
          return @@ Sequencer_upgrade.to_bytes sequencer_upgrade
        else
          tzfail
            (error_of_fmt
               "devmode must be set for producing the sequencer upgrade")
      in
      Printf.printf "%s%!" Hex.(of_bytes payload |> show) ;
      return_unit)

let init_from_rollup_node_command =
  let open Tezos_clic in
  let rollup_node_data_dir_param =
    Tezos_clic.param
      ~name:"rollup-node-data-dir"
      ~desc:(Format.sprintf "The path to the rollup node data directory.")
      Params.string
  in
  command
    ~desc:
      "initialises the EVM node data-dir using the data-dir of a rollup node."
    (args2 data_dir_arg devmode_arg)
    (prefixes ["init"; "from"; "rollup"; "node"]
    @@ rollup_node_data_dir_param @@ stop)
    (fun (data_dir, devmode) rollup_node_data_dir () ->
      if devmode then
        Evm_node_lib_dev.Evm_context.init_from_rollup_node
          ~data_dir
          ~rollup_node_data_dir
      else
        Evm_node_lib_prod.Evm_context.init_from_rollup_node
          ~data_dir
          ~rollup_node_data_dir)

let dump_to_rlp_command =
  let open Tezos_clic in
  let open Lwt_result_syntax in
  command
    ~desc:"Transforms the JSON list of instructions to a RLP list"
    (args2 devmode_arg keep_everything_arg)
    (prefixes ["transform"; "dump"]
    @@ param ~name:"dump.json" ~desc:"Description" Params.string
    @@ prefixes ["to"; "rlp"]
    @@ param ~name:"dump.rlp" ~desc:"Description" Params.string
    @@ stop)
    (fun (devmode, keep_everything) dump_json dump_rlp () ->
      let* dump_json = Lwt_utils_unix.Json.read_file dump_json in
      let config =
        Data_encoding.Json.destruct
          Octez_smart_rollup.Installer_config.encoding
          dump_json
      in

      let bytes =
        let aux =
          let open Evm_node_lib_dev_encoding.Rlp in
          if keep_everything then
            fun acc Octez_smart_rollup.Installer_config.(Set {value; to_}) ->
            List [Value (String.to_bytes to_); Value (String.to_bytes value)]
            :: acc
          else fun acc Octez_smart_rollup.Installer_config.(Set {value; to_}) ->
            if String.starts_with ~prefix:"/evm" to_ then
              List [Value (String.to_bytes to_); Value (String.to_bytes value)]
              :: acc
            else acc
        in
        if devmode then
          let open Evm_node_lib_dev_encoding.Rlp in
          List.fold_left aux [] config |> fun l -> encode (List l)
        else
          let aux =
            let open Evm_node_lib_prod_encoding.Rlp in
            if keep_everything then
              fun acc Octez_smart_rollup.Installer_config.(Set {value; to_}) ->
              List [Value (String.to_bytes to_); Value (String.to_bytes value)]
              :: acc
            else
              fun acc Octez_smart_rollup.Installer_config.(Set {value; to_}) ->
              if String.starts_with ~prefix:"/evm" to_ then
                List
                  [Value (String.to_bytes to_); Value (String.to_bytes value)]
                :: acc
              else acc
          in
          let open Evm_node_lib_prod_encoding.Rlp in
          List.fold_left aux [] config |> fun l -> encode (List l)
      in

      let write_bytes_to_file filename bytes =
        let oc = open_out filename in
        output_bytes oc bytes ;
        close_out oc
      in

      write_bytes_to_file dump_rlp bytes ;

      return_unit)

let reset_command =
  let open Tezos_clic in
  command
    ~desc:"Reset evm node data-dir to a specific block level."
    (args2
       data_dir_arg
       (Tezos_clic.switch
          ~long:"force"
          ~short:'f'
          ~doc:
            "force suppression of data to reset state of sequencer to a \
             specified l2 level."
          ()))
    (prefixes ["reset"; "at"]
    @@ Tezos_clic.param
         ~name:"level"
         ~desc:"level to reset to state to."
         (Tezos_clic.parameter (fun () s ->
              Lwt.return_ok
              @@ Evm_node_lib_dev_encoding.Ethereum_types.Qty (Z.of_string s)))
    @@ stop)
    (fun (data_dir, force) l2_level () ->
      if force then Evm_node_lib_dev.Evm_context.reset ~data_dir ~l2_level
      else
        failwith
          "You must provide the `--force` switch in order to use this command \
           and not accidentally delete data.")

(* List of program commands *)
let commands =
  [
    proxy_command;
    sequencer_command;
    observer_command;
    chunker_command;
    make_upgrade_command;
    make_sequencer_upgrade_command;
    init_from_rollup_node_command;
    dump_to_rlp_command;
    reset_command;
  ]

let global_options = Tezos_clic.no_options

let executable_name = Filename.basename Sys.executable_name

let argv () = Array.to_list Sys.argv |> List.tl |> Stdlib.Option.get

let dispatch args =
  let open Lwt_result_syntax in
  let commands =
    Tezos_clic.add_manual
      ~executable_name
      ~global_options
      (if Unix.isatty Unix.stdout then Tezos_clic.Ansi else Tezos_clic.Plain)
      Format.std_formatter
      commands
  in
  let* (), remaining_args =
    Tezos_clic.parse_global_options global_options () args
  in
  Tezos_clic.dispatch commands () remaining_args

let handle_error = function
  | Ok _ -> ()
  | Error [Tezos_clic.Version] ->
      let devmode = Tezos_version_value.Bin_version.etherlink_version_string in
      Format.printf "%s\n" devmode ;
      exit 0
  | Error [Tezos_clic.Help command] ->
      Tezos_clic.usage
        Format.std_formatter
        ~executable_name
        ~global_options
        (match command with None -> [] | Some c -> [c]) ;
      Stdlib.exit 0
  | Error errs ->
      Tezos_clic.pp_cli_errors
        Format.err_formatter
        ~executable_name
        ~global_options
        ~default:Error_monad.pp
        errs ;
      Stdlib.exit 1

let () =
  let _ =
    Tezos_clic.(
      setup_formatter
        Format.std_formatter
        (if Unix.isatty Unix.stdout then Ansi else Plain)
        Short)
  in
  let _ =
    Tezos_clic.(
      setup_formatter
        Format.err_formatter
        (if Unix.isatty Unix.stderr then Ansi else Plain)
        Short)
  in
  Lwt.Exception_filter.(set handle_all_except_runtime) ;
  Lwt_main.run (dispatch (argv ())) |> handle_error
