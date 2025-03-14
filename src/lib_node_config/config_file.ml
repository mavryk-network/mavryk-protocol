(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@mavryk.com>     *)
(* Copyright (c) 2019-2020 Nomadic Labs, <contact@nomadic-labs.com>          *)
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

open Filename.Infix

let home = try Sys.getenv "HOME" with Not_found -> "/root"

let data_dir_env_name = "MAVRYK_NODE_DIR"

let default_data_dir = home // ".mavryk-node"

let default_rpc_port = 8732

let default_max_active_rpc_connections =
  RPC_server.Max_active_rpc_connections.default

let default_metrics_port = 9932

let default_p2p_port = 9732

let default_discovery_port = 10732

type chain_name = Distributed_db_version.Name.t

type blockchain_network = {
  alias : string option;
  genesis : Genesis.t;
  genesis_parameters : Genesis.Parameters.t option;
  chain_name : chain_name;
  old_chain_name : chain_name option;
  incompatible_chain_name : chain_name option;
  sandboxed_chain_name : chain_name;
  user_activated_upgrades : User_activated.upgrades;
  user_activated_protocol_overrides : User_activated.protocol_overrides;
  default_bootstrap_peers : string list;
  dal_config : Mavryk_crypto_dal.Cryptobox.Config.t;
}

let make_blockchain_network ~alias ~chain_name ?old_chain_name
    ?incompatible_chain_name ~sandboxed_chain_name
    ?(user_activated_upgrades = []) ?(user_activated_protocol_overrides = [])
    ?(default_bootstrap_peers = []) ?genesis_parameters
    ?(dal_config = Mavryk_crypto_dal.Cryptobox.Config.default) genesis =
  let of_string = Distributed_db_version.Name.of_string in
  {
    alias = Some alias;
    genesis;
    genesis_parameters;
    chain_name = of_string chain_name;
    old_chain_name = Option.map of_string old_chain_name;
    incompatible_chain_name = Option.map of_string incompatible_chain_name;
    sandboxed_chain_name = of_string sandboxed_chain_name;
    user_activated_upgrades =
      List.map
        (fun (l, h) -> (l, Protocol_hash.of_b58check_exn h))
        user_activated_upgrades;
    user_activated_protocol_overrides =
      List.map
        (fun (a, b) ->
          (Protocol_hash.of_b58check_exn a, Protocol_hash.of_b58check_exn b))
        user_activated_protocol_overrides;
    default_bootstrap_peers;
    dal_config;
  }

(* The script in scripts/user_activated_upgrade.sh patches the following lines
   when it needs to set the user activated upgrade levels for Mainnet. *)
(* BEGIN_PATCHING_ZONE_FOR_MAINNET_USER_ACTIVATED_UPGRADES *)
let mainnet_user_activated_upgrades =
  [
    (28082l, "PsYLVpVvgbLhAhoqAkMFUo6gudkJ9weNXhUYCiLDzcUpFpkk8Wt");
    (204761l, "PsddFKi32cMJ2qPjf43Qv5GDWLDPZb3T3bF6fLKiF5HtvHNU7aP");
    (5898241l, "PtBzwViMCC1gfm98y5TDKqz2e3vjBXPAUoWu7jfEcN6yj2ZhCyT");
  ]

(* END_PATCHING_ZONE_FOR_MAINNET_USER_ACTIVATED_UPGRADES *)
(* it patches the following lines when it needs to set the user activated
   upgrade levels for a sandbox. *)
(* BEGIN_PATCHING_ZONE_FOR_SANDBOX_USER_ACTIVATED_UPGRADES *)
let sandbox_user_activated_upgrades = []
(* END_PATCHING_ZONE_FOR_SANDBOX_USER_ACTIVATED_UPGRADES *)

let blockchain_network_mainnet =
  make_blockchain_network
    ~alias:"mainnet"
    {
      time = Time.Protocol.of_notation_exn "2018-06-30T16:07:32Z";
      block =
        Block_hash.of_b58check_exn
          "BLockGenesisGenesisGenesisGenesisGenesisf79b5d1CoW2";
      protocol =
        Protocol_hash.of_b58check_exn
          "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P";
    }
    ~chain_name:"MAVRYK_MAINNET"
    ~old_chain_name:"MAVRYK_BETANET_2018-06-30T16:07:32Z"
    ~incompatible_chain_name:"INCOMPATIBLE"
    ~sandboxed_chain_name:"SANDBOXED_MAVRYK_MAINNET"
    ~user_activated_upgrades:mainnet_user_activated_upgrades
    ~user_activated_protocol_overrides:[]
    ~default_bootstrap_peers:
      ["boot.tzinit.org"; "boot.tzboot.net"; "boot.tzbeta.net"]
    ~dal_config:
      {
        activated = true;
        use_mock_srs_for_testing = false;
        bootstrap_peers =
          ["dalboot.mainnet.tzinit.org"; "dalboot.mainnet.tzboot.net"];
      }

let blockchain_network_basenet =
  make_blockchain_network
    ~alias:"basenet"
    {
      time = Time.Protocol.of_notation_exn "2022-01-25T15:00:00Z";
      block =
        Block_hash.of_b58check_exn
          "BLockGenesisGenesisGenesisGenesisGenesis1db77eJNeJ9";
      protocol =
        Protocol_hash.of_b58check_exn
          "Ps9mPmXaRzmzk35gbAYNCAw6UXdE2qoABTHbN2oEEc1qM7CwT9P";
    }
    ~genesis_parameters:
      {
        context_key = "sandbox_parameter";
        values =
          `O
            [
              ( "genesis_pubkey",
                `String "edpkuYLienS3Xdt5c1vfRX1ibMxQuvfM67ByhJ9nmRYYKGAAoTq1UC"
              );
            ];
      }
    ~chain_name:"MAVRYK_ITHACANET_2022-01-25T15:00:00Z"
    ~sandboxed_chain_name:"SANDBOXED_MAVRYK"
    ~user_activated_upgrades:
      [(6729729l, "PtBzwViMCC1gfm98y5TDKqz2e3vjBXPAUoWu7jfEcN6yj2ZhCyT")]
    ~default_bootstrap_peers:
      [
        "basenet.teztnets.com";
        "basenet.tzinit.org";
        "basenet.tzboot.net";
        "basenet.boot.ecadinfra.com";
        "basenet.stakenow.de:9733";
      ]
    ~dal_config:
      {
        activated = true;
        use_mock_srs_for_testing = false;
        bootstrap_peers =
          ["dalboot.basenet.tzinit.org"; "dalboot.basenet.tzboot.net"];
      }

let blockchain_network_sandbox =
  make_blockchain_network
    ~alias:"sandbox"
    {
      time = Time.Protocol.of_notation_exn "2018-06-30T16:07:32Z";
      block =
        Block_hash.of_b58check_exn
          "BLockGenesisGenesisGenesisGenesisGenesisf79b5d1CoW2";
      protocol =
        Protocol_hash.of_b58check_exn
          "ProtoGenesisGenesisGenesisGenesisGenesisGenesk612im";
    }
    ~genesis_parameters:
      (* Genesis public key corresponds to the following private key:
         unencrypted:edsk31vznjHSSpGExDMHYASz45VZqXN4DPxvsa4hAyY8dHM28cZzp6 *)
      {
        context_key = "sandbox_parameter";
        values =
          `O
            [
              ( "genesis_pubkey",
                `String "edpkuSLWfVU1Vq7Jg9FucPyKmma6otcMHac9zG4oU1KMHSTBpJuGQ2"
              );
            ];
      }
    ~chain_name:"MAVRYK"
    ~sandboxed_chain_name:"SANDBOXED_MAVRYK"
    ~user_activated_upgrades:sandbox_user_activated_upgrades
    ~dal_config:
      {activated = true; use_mock_srs_for_testing = false; bootstrap_peers = []}

let blockchain_network_encoding : blockchain_network Data_encoding.t =
  let open Data_encoding in
  conv
    (fun {
           alias = _;
           genesis;
           genesis_parameters;
           chain_name;
           old_chain_name;
           incompatible_chain_name;
           sandboxed_chain_name;
           user_activated_upgrades;
           user_activated_protocol_overrides;
           default_bootstrap_peers;
           dal_config;
         } ->
      ( genesis,
        genesis_parameters,
        chain_name,
        old_chain_name,
        incompatible_chain_name,
        sandboxed_chain_name,
        user_activated_upgrades,
        user_activated_protocol_overrides,
        default_bootstrap_peers,
        dal_config ))
    (fun ( genesis,
           genesis_parameters,
           chain_name,
           old_chain_name,
           incompatible_chain_name,
           sandboxed_chain_name,
           user_activated_upgrades,
           user_activated_protocol_overrides,
           default_bootstrap_peers,
           dal_config ) ->
      {
        alias = None;
        genesis;
        genesis_parameters;
        chain_name;
        old_chain_name;
        incompatible_chain_name;
        sandboxed_chain_name;
        user_activated_upgrades;
        user_activated_protocol_overrides;
        default_bootstrap_peers;
        dal_config;
      })
    (let chain = Distributed_db_version.Name.encoding in
     obj10
       (req "genesis" Genesis.encoding)
       (opt "genesis_parameters" Genesis.Parameters.encoding)
       (req "chain_name" chain)
       (opt "old_chain_name" chain)
       (opt "incompatible_chain_name" chain)
       (req "sandboxed_chain_name" chain)
       (dft "user_activated_upgrades" User_activated.upgrades_encoding [])
       (dft
          "user_activated_protocol_overrides"
          User_activated.protocol_overrides_encoding
          [])
       (dft
          "default_bootstrap_peers"
          ~description:
            "List of hosts to use if p2p.bootstrap_peers is unspecified."
          (list string)
          [])
       (dft
          "dal_config"
          ~description:
            "USE FOR TESTING PURPOSE ONLY. Configuration for the \
             data-availibility layer"
          Mavryk_crypto_dal.Cryptobox.Config.encoding
          (* We use default config unless explicitly overridden via the config file.
             Note that such override is expected to only be used in test networks. *)
          Mavryk_crypto_dal.Cryptobox.Config.default))

let builtin_blockchain_networks_with_tags =
  [
    (1, blockchain_network_sandbox);
    (4, blockchain_network_mainnet);
    (19, blockchain_network_basenet);
  ]
  |> List.map (fun (tag, network) ->
         match network.alias with
         | None -> assert false (* all built-in networks must have aliases *)
         | Some alias -> (tag, alias, network))

let builtin_blockchain_networks =
  List.map
    (fun (_, name, network) -> (name, network))
    builtin_blockchain_networks_with_tags

let sugared_blockchain_network_encoding : blockchain_network Data_encoding.t =
  let open Data_encoding in
  let builtin_encoding (tag, network_alias, network) =
    case
      (Tag tag)
      ~title:network_alias
      (constant network_alias)
      (fun candidate ->
        match candidate.alias with
        | None -> None
        | Some candidate_alias ->
            if String.equal candidate_alias network_alias then Some () else None)
      (fun () -> network)
  in
  (* It is important that built-in networks are listed before the Custom case,
     so that they have priority. Indeed, if possible we want to store the alias
     in the configuration file, not the full network description. Not just because
     it is prettier, but also in case user-activated upgrades are added to the built-in
     network: by writing the alias we ensure that new upgrades are used without having
     to update the configuration file manually. *)
  union
    ~tag_size:`Uint8
    (List.map builtin_encoding builtin_blockchain_networks_with_tags
    @ [
        case
          (Tag 0)
          ~title:"Custom"
          blockchain_network_encoding
          (fun x -> Some x)
          (fun x -> x);
      ])

type t = {
  data_dir : string;
  disable_config_validation : bool;
  p2p : p2p;
  rpc : rpc;
  log : Logs_simple_config.cfg;
  internal_events : Internal_event_config.t option;
  shell : Shell_limits.limits;
  blockchain_network : blockchain_network;
  metrics_addr : string list;
}

and p2p = {
  expected_pow : float;
  bootstrap_peers : string list option;
  listen_addr : string option;
  advertised_net_port : int option;
  discovery_addr : string option;
  private_mode : bool;
  limits : Mavryk_p2p_services.P2p_limits.t;
  disable_mempool : bool;
  enable_testchain : bool;
  reconnection_config : Mavryk_p2p_services.Point_reconnection_config.t;
  disable_peer_discovery : bool;
}

and rpc = {
  listen_addrs : string list;
  external_listen_addrs : string list;
  cors_origins : string list;
  cors_headers : string list;
  tls : tls option;
  acl : RPC_server.Acl.policy;
  media_type : Media_type.Command_line.t;
  max_active_rpc_connections : RPC_server.Max_active_rpc_connections.t;
}

and tls = {cert : string; key : string}

let default_p2p =
  {
    expected_pow = 26.;
    bootstrap_peers = None;
    listen_addr = Some ("[::]:" ^ string_of_int default_p2p_port);
    advertised_net_port = None;
    discovery_addr = None;
    private_mode = false;
    limits = Mavryk_p2p_services.P2p_limits.default;
    disable_mempool = false;
    enable_testchain = false;
    reconnection_config = Mavryk_p2p_services.Point_reconnection_config.default;
    disable_peer_discovery = false;
  }

let default_rpc =
  {
    listen_addrs = [];
    external_listen_addrs = [];
    cors_origins = [];
    cors_headers = [];
    tls = None;
    acl = RPC_server.Acl.empty_policy;
    media_type = Media_type.Command_line.Any;
    max_active_rpc_connections = default_max_active_rpc_connections;
  }

let default_disable_config_validation = false

let default_config =
  {
    data_dir = default_data_dir;
    p2p = default_p2p;
    rpc = default_rpc;
    log = Logs_simple_config.default_cfg;
    internal_events = None;
    shell = Shell_limits.default_limits;
    blockchain_network = blockchain_network_mainnet;
    disable_config_validation = default_disable_config_validation;
    metrics_addr = [];
  }

let p2p =
  let open Data_encoding in
  conv
    (fun {
           expected_pow;
           bootstrap_peers;
           listen_addr;
           advertised_net_port;
           discovery_addr;
           private_mode;
           limits;
           disable_mempool;
           enable_testchain;
           reconnection_config;
           disable_peer_discovery;
         } ->
      ( ( expected_pow,
          bootstrap_peers,
          listen_addr,
          advertised_net_port,
          discovery_addr ),
        ( private_mode,
          limits,
          disable_mempool,
          enable_testchain,
          reconnection_config,
          disable_peer_discovery ) ))
    (fun ( ( expected_pow,
             bootstrap_peers,
             listen_addr,
             advertised_net_port,
             discovery_addr ),
           ( private_mode,
             limits,
             disable_mempool,
             enable_testchain,
             reconnection_config,
             disable_peer_discovery ) ) ->
      {
        expected_pow;
        bootstrap_peers;
        listen_addr;
        advertised_net_port;
        discovery_addr;
        private_mode;
        limits;
        disable_mempool;
        enable_testchain;
        reconnection_config;
        disable_peer_discovery;
      })
    (merge_objs
       (obj5
          (dft
             "expected-proof-of-work"
             ~description:
               "Floating point number between 0 and 256 that represents a \
                difficulty, 24 signifies for example that at least 24 leading \
                zeroes are expected in the hash."
             float
             default_p2p.expected_pow)
          (opt
             "bootstrap-peers"
             ~description:
               "List of hosts. Mavryk can connect to both IPv6 and IPv4 hosts. \
                If the port is not specified, default port 9732 will be \
                assumed."
             (list string))
          (opt
             "listen-addr"
             ~description:
               "Host to listen to. If the port is not specified, the default \
                port 9732 will be assumed."
             string)
          (opt
             "advertised-net-port"
             ~description:
               "Alternative port advertised to other peers to connect to. If \
                the port is not specified, the port from listen-addr will be \
                assumed."
             uint16)
          (dft
             "discovery-addr"
             ~description:
               "Host for local peer discovery. If the port is not specified, \
                the default port 10732 will be assumed."
             (option string)
             default_p2p.discovery_addr))
       (obj6
          (dft
             "private-mode"
             ~description:
               "Specify if the node is in private mode or not. A node in \
                private mode rejects incoming connections from untrusted peers \
                and only opens outgoing connections to peers listed in \
                'bootstrap-peers' or provided with '--peer' option. Moreover, \
                these peers will keep the identity and the address of the \
                private node secret."
             bool
             default_p2p.private_mode)
          (dft
             "limits"
             ~description:"Network limits"
             Mavryk_p2p_services.P2p_limits.encoding
             Mavryk_p2p_services.P2p_limits.default)
          (dft
             "disable_mempool"
             ~description:
               "If set to [true], the node will not participate in the \
                propagation of pending operations (mempool). Default value is \
                [false]. It can be used to decrease the memory and computation \
                footprints of the node."
             bool
             default_p2p.disable_mempool)
          (dft
             "enable_testchain"
             ~description:
               "DEPRECATED. If set to [true], the node will spawn a testchain \
                during the protocol's testing voting period. Default value is \
                [false]. It is disabled to decrease the node storage usage and \
                computation by dropping the validation of the test network \
                blocks."
             bool
             default_p2p.enable_testchain)
          (let open Mavryk_p2p_services.Point_reconnection_config in
          dft
            "greylisting_config"
            ~description:
              "The reconnection policy regulates the frequency with which the \
               node tries to reconnect to an old known peer."
            encoding
            default)
          (dft
             "disable_peer_discovery"
             ~description:
               "This field should be used for testing purpose only. If set to \
                [true], the node will not participate to the peer discovery \
                mechanism. The node will not be able to find new peers to \
                connect with."
             bool
             default_p2p.disable_peer_discovery)))

let rpc : rpc Data_encoding.t =
  let open Data_encoding in
  conv
    (fun {
           cors_origins;
           cors_headers;
           listen_addrs;
           external_listen_addrs;
           tls;
           acl;
           media_type;
           max_active_rpc_connections;
         } ->
      let cert, key =
        match tls with
        | None -> (None, None)
        | Some {cert; key} -> (Some cert, Some key)
      in
      let external_listen_addrs =
        match external_listen_addrs with [] -> None | v -> Some v
      in
      ( (Some listen_addrs, external_listen_addrs, None, cors_origins),
        (cors_headers, cert, key, acl, media_type, max_active_rpc_connections)
      ))
    (fun ( ( listen_addrs,
             external_listen_addrs,
             legacy_listen_addr,
             cors_origins ),
           (cors_headers, cert, key, acl, media_type, max_active_rpc_connections)
         ) ->
      let tls =
        match (cert, key) with
        | None, _ | _, None -> None
        | Some cert, Some key -> Some {cert; key}
      in
      let listen_addrs =
        match (listen_addrs, legacy_listen_addr) with
        | Some addrs, None -> addrs
        | None, Some addr -> [addr]
        | None, None -> default_rpc.listen_addrs
        | Some _, Some _ ->
            Stdlib.failwith
              "Config file: Use only \"listen-addrs\" and not (legacy) \
               \"listen-addr\"."
      in
      let external_listen_addrs =
        Option.value
          external_listen_addrs
          ~default:default_rpc.external_listen_addrs
      in
      {
        listen_addrs;
        external_listen_addrs;
        cors_origins;
        cors_headers;
        tls;
        acl;
        media_type;
        max_active_rpc_connections;
      })
    (merge_objs
       (obj4
          (opt
             "listen-addrs"
             ~description:
               "Hosts to listen to. If the port is not specified, the default \
                port 8732 will be assumed."
             (list string))
          (opt
             "external-listen-addrs"
             ~description:
               "Hosts to listen to. If the port is not specified, the default \
                port 8732 will be assumed."
             (list string))
          (opt
             "listen-addr"
             ~description:"Legacy value: Host to listen to"
             string)
          (dft
             "cors-origin"
             ~description:
               "Cross Origin Resource Sharing parameters, see \
                https://en.wikipedia.org/wiki/Cross-origin_resource_sharing."
             (list string)
             default_rpc.cors_origins))
       (obj6
          (dft
             "cors-headers"
             ~description:
               "Cross Origin Resource Sharing parameters, see \
                https://en.wikipedia.org/wiki/Cross-origin_resource_sharing."
             (list string)
             default_rpc.cors_headers)
          (opt
             "crt"
             ~description:"Certificate file (necessary when TLS is used)."
             string)
          (opt
             "key"
             ~description:"Key file (necessary when TLS is used)."
             string)
          (dft
             "acl"
             ~description:"A list of RPC ACLs for specific listening addresses."
             RPC_server.Acl.policy_encoding
             default_rpc.acl)
          (dft
             "media-type"
             ~description:"The media types supported by the server."
             Media_type.Command_line.encoding
             default_rpc.media_type)
          (dft
             "max_active_rpc_connections"
             ~description:
               "The maximum number of active connections per RPC endpoint."
             RPC_server.Max_active_rpc_connections.encoding
             default_rpc.max_active_rpc_connections)))

let rpc_encoding = rpc

let encoding =
  let open Data_encoding in
  conv
    (fun {
           data_dir;
           disable_config_validation;
           rpc;
           p2p;
           log;
           internal_events;
           shell;
           blockchain_network;
           metrics_addr;
         } ->
      ( data_dir,
        disable_config_validation,
        rpc,
        p2p,
        log,
        internal_events,
        shell,
        blockchain_network,
        metrics_addr ))
    (fun ( data_dir,
           disable_config_validation,
           rpc,
           p2p,
           log,
           internal_events,
           shell,
           blockchain_network,
           metrics_addr ) ->
      {
        disable_config_validation;
        data_dir;
        rpc;
        p2p;
        log;
        internal_events;
        shell;
        blockchain_network;
        metrics_addr;
      })
    (obj9
       (dft
          "data-dir"
          ~description:"Location of the data dir on disk."
          string
          default_data_dir)
       (dft
          "disable-config-validation"
          ~description:"Disable the node configuration validation."
          bool
          default_disable_config_validation)
       (dft
          "rpc"
          ~description:"Configuration of rpc parameters"
          rpc
          default_rpc)
       (dft
          "p2p"
          ~description:"Configuration of network parameters"
          p2p
          default_p2p)
       (dft
          "log"
          ~description:
            "Configuration of the Lwt-log sink (part of the logging framework)"
          Logs_simple_config.cfg_encoding
          Logs_simple_config.default_cfg)
       (opt
          "internal-events"
          ~description:"Configuration of the structured logging framework"
          Internal_event_config.encoding)
       (dft
          "shell"
          ~description:"Configuration of network parameters"
          Shell_limits.limits_encoding
          Shell_limits.default_limits)
       (dft
          "network"
          ~description:"Configuration of which network/blockchain to connect to"
          sugared_blockchain_network_encoding
          blockchain_network_mainnet)
       (dft
          "metrics_addr"
          ~description:"Configuration of the Prometheus metrics endpoint"
          (list string)
          default_config.metrics_addr))

let () =
  Data_encoding.Registration.register (Data_encoding.def "node-config" encoding)

(* Abstract version of [Json_encoding.Cannot_destruct]: first argument is the
   string representation of the path, second argument is the error message
   of the actual exception which was raised (as [Cannot_destruct] takes an [exn]
   as second argument). *)
type error += Invalid_content of string option * string

let () =
  register_error_kind
    `Permanent
    ~id:"config_file.invalid_content"
    ~title:"Invalid config file"
    ~description:"Invalid content in node config file"
    ~pp:(fun ppf (path, exn) ->
      match path with
      | Some path ->
          Format.fprintf
            ppf
            "@[<hov>Invalid configuration file:@ at %s:@ %s@]"
            path
            exn
      | None ->
          Format.fprintf ppf "@[<hov>Invalid configuration file:@ %s@]" exn)
    Data_encoding.(obj2 (req "path" (option string)) (req "error" string))
    (function Invalid_content (p, e) -> Some (p, e) | _ -> None)
    (fun (p, e) -> Invalid_content (p, e))

module Event = struct
  include Internal_event.Simple

  let section = ["node"; "main"]

  let level = Internal_event.Warning

  let cannot_convert_to_ipv4 =
    Internal_event.Simple.declare_1
      ~section
      ~level
      ~name:"cannot_convert_to_ipv4"
      ~msg:"failed to convert {addr} to an ipv4 address"
      ~pp1:(fun ppf -> Format.fprintf ppf "%S")
      ("addr", Data_encoding.string)

  let all_rpc_allowed =
    declare_1
      ~level:Error
      ~section
      ~name:"all_rpc_allowed"
      ~msg:"FULL access to RPC enabled; this is very risky."
      ~pp1:
        Format.(
          pp_print_list
            ~pp_sep:(fun fmt () -> pp_print_string fmt ", ")
            P2p_point.Id.pp_addr_port_id)
      ("addresses", Data_encoding.(list P2p_point.Id.addr_port_id_encoding))
end

let string_of_json_encoding_error exn =
  Format.asprintf "%a" (Json_encoding.print_error ?print_unknown:None) exn

let read fp =
  let open Lwt_result_syntax in
  if Sys.file_exists fp then
    let* json = Lwt_utils_unix.Json.read_file fp in
    try return (Data_encoding.Json.destruct encoding json) with
    | Json_encoding.Cannot_destruct (path, exn) ->
        let path = Json_query.json_pointer_of_path path in
        let exn = string_of_json_encoding_error exn in
        tzfail (Invalid_content (Some path, exn))
    | ( Json_encoding.Unexpected _ | Json_encoding.No_case_matched _
      | Json_encoding.Bad_array_size _ | Json_encoding.Missing_field _
      | Json_encoding.Unexpected_field _ | Json_encoding.Bad_schema _ ) as exn
      ->
        let exn = string_of_json_encoding_error exn in
        tzfail (Invalid_content (None, exn))
  else return default_config

let write fp cfg =
  let open Lwt_result_syntax in
  let* () =
    Data_version.ensure_data_dir
      ~mode:Exists
      cfg.blockchain_network.genesis
      (Filename.dirname fp)
  in
  Lwt_utils_unix.Json.write_file fp (Data_encoding.Json.construct encoding cfg)

let to_string cfg =
  Data_encoding.Json.to_string (Data_encoding.Json.construct encoding cfg)

let update ?(disable_config_validation = false) ?data_dir ?min_connections
    ?expected_connections ?max_connections ?max_download_speed ?max_upload_speed
    ?binary_chunks_size ?peer_table_size ?expected_pow ?bootstrap_peers
    ?listen_addr ?advertised_net_port ?discovery_addr ?(rpc_listen_addrs = [])
    ?(external_rpc_listen_addrs = []) ?(allow_all_rpc = [])
    ?(media_type = Media_type.Command_line.Any)
    ?(max_active_rpc_connections = default_rpc.max_active_rpc_connections)
    ?(metrics_addr = []) ?operation_metadata_size_limit
    ?(private_mode = default_p2p.private_mode)
    ?(disable_p2p_maintenance =
      Option.is_none default_p2p.limits.maintenance_idle_time)
    ?(disable_p2p_swap = Option.is_none default_p2p.limits.swap_linger)
    ?(disable_mempool = default_p2p.disable_mempool)
    ?(enable_testchain = default_p2p.enable_testchain) ?(cors_origins = [])
    ?(cors_headers = []) ?rpc_tls ?log_output ?log_coloring
    ?synchronisation_threshold ?history_mode ?network ?latency
    ?disable_context_pruning ?storage_maintenance_delay cfg =
  let open Lwt_result_syntax in
  let disable_config_validation =
    cfg.disable_config_validation || disable_config_validation
  in
  let data_dir = Option.value ~default:cfg.data_dir data_dir in
  let*! () =
    if List.compare_length_with allow_all_rpc 1 >= 0 then
      Event.(emit all_rpc_allowed allow_all_rpc)
    else Lwt.return_unit
  in
  let* () =
    Data_version.ensure_data_dir
      ~mode:Exists
      cfg.blockchain_network.genesis
      data_dir
  in
  let peer_table_size = Option.map (fun i -> (i, i / 4 * 3)) peer_table_size in
  let unopt_list ~default = function [] -> default | l -> l in
  let limits : Mavryk_p2p_services.P2p_limits.t =
    {
      cfg.p2p.limits with
      min_connections =
        Option.value ~default:cfg.p2p.limits.min_connections min_connections;
      expected_connections =
        Option.value
          ~default:cfg.p2p.limits.expected_connections
          expected_connections;
      max_connections =
        Option.value ~default:cfg.p2p.limits.max_connections max_connections;
      max_download_speed =
        Option.either max_download_speed cfg.p2p.limits.max_download_speed;
      max_upload_speed =
        Option.either max_upload_speed cfg.p2p.limits.max_upload_speed;
      max_known_points =
        Option.either peer_table_size cfg.p2p.limits.max_known_points;
      max_known_peer_ids =
        Option.either peer_table_size cfg.p2p.limits.max_known_peer_ids;
      binary_chunks_size = Option.map (fun x -> x lsl 10) binary_chunks_size;
      maintenance_idle_time =
        (if disable_p2p_maintenance then None
        else cfg.p2p.limits.maintenance_idle_time);
      swap_linger =
        (if disable_p2p_swap then None else cfg.p2p.limits.swap_linger);
    }
  in
  let acl =
    (* Take addresses listed in allow_all_rpc and add each of them with allow_all
       ACL to the policy. *)
    List.fold_right
      RPC_server.Acl.put_policy
      (List.map (fun addr -> (addr, RPC_server.Acl.allow_all)) allow_all_rpc)
      cfg.rpc.acl
  in
  let p2p : p2p =
    {
      expected_pow = Option.value ~default:cfg.p2p.expected_pow expected_pow;
      bootstrap_peers =
        Option.value ~default:cfg.p2p.bootstrap_peers bootstrap_peers;
      listen_addr = Option.either listen_addr cfg.p2p.listen_addr;
      advertised_net_port =
        Option.either advertised_net_port cfg.p2p.advertised_net_port;
      discovery_addr = Option.either discovery_addr cfg.p2p.discovery_addr;
      private_mode = cfg.p2p.private_mode || private_mode;
      limits;
      disable_mempool = cfg.p2p.disable_mempool || disable_mempool;
      enable_testchain = cfg.p2p.enable_testchain || enable_testchain;
      reconnection_config = cfg.p2p.reconnection_config;
      disable_peer_discovery = cfg.p2p.disable_peer_discovery;
    }
  and rpc : rpc =
    {
      listen_addrs = unopt_list ~default:cfg.rpc.listen_addrs rpc_listen_addrs;
      external_listen_addrs =
        unopt_list
          ~default:cfg.rpc.external_listen_addrs
          external_rpc_listen_addrs;
      cors_origins = unopt_list ~default:cfg.rpc.cors_origins cors_origins;
      cors_headers = unopt_list ~default:cfg.rpc.cors_headers cors_headers;
      tls = Option.either rpc_tls cfg.rpc.tls;
      acl;
      media_type;
      max_active_rpc_connections;
    }
  and metrics_addr = unopt_list ~default:cfg.metrics_addr metrics_addr
  and log : Logs_simple_config.cfg =
    {
      cfg.log with
      colors = Option.value ~default:cfg.log.colors log_coloring;
      output = Option.value ~default:cfg.log.output log_output;
    }
  and shell =
    Shell_limits.
      {
        peer_validator_limits = cfg.shell.peer_validator_limits;
        block_validator_limits =
          {
            cfg.shell.block_validator_limits with
            operation_metadata_size_limit =
              Option.value
                ~default:
                  cfg.shell.block_validator_limits.operation_metadata_size_limit
                operation_metadata_size_limit;
          };
        prevalidator_limits = cfg.shell.prevalidator_limits;
        chain_validator_limits =
          (let synchronisation : synchronisation_limits =
             {
               latency =
                 Option.value
                   ~default:
                     cfg.shell.chain_validator_limits.synchronisation.latency
                   latency;
               threshold =
                 Option.value
                   ~default:
                     cfg.shell.chain_validator_limits.synchronisation.threshold
                   synchronisation_threshold;
             }
           in
           {synchronisation});
        history_mode = Option.either history_mode cfg.shell.history_mode;
        disable_context_pruning =
          Option.either
            disable_context_pruning
            cfg.shell.disable_context_pruning;
        storage_maintenance_delay =
          Option.either
            storage_maintenance_delay
            cfg.shell.storage_maintenance_delay;
      }
  in
  (* If --network is specified it overrides the "network" entry of the
     configuration file, which itself defaults to mainnet. *)
  let blockchain_network =
    Option.value ~default:cfg.blockchain_network network
  in
  return
    {
      cfg with
      disable_config_validation;
      data_dir;
      p2p;
      rpc;
      log;
      shell;
      blockchain_network;
      metrics_addr;
    }

let to_ipv4 ipv6_l =
  let open Lwt_syntax in
  let convert_or_warn (ipv6, port) =
    let ipv4 = Ipaddr.v4_of_v6 ipv6 in
    match ipv4 with
    | None ->
        let* () =
          Event.(emit cannot_convert_to_ipv4) (Ipaddr.V6.to_string ipv6)
        in
        return_none
    | Some ipv4 -> return_some (ipv4, port)
  in
  List.filter_map_s convert_or_warn ipv6_l

let resolve_discovery_addrs discovery_addr =
  let open Lwt_result_syntax in
  let* points =
    P2p_resolve.resolve_addr
      ~default_addr:Ipaddr.V4.(to_string broadcast)
      ~default_port:default_discovery_port
      ~passive:true
      discovery_addr
  in
  let*! points = to_ipv4 points in
  return points

let resolve_listening_addrs listen_addr =
  P2p_resolve.resolve_addr
    ~default_addr:"::"
    ~default_port:default_p2p_port
    ~passive:true
    listen_addr

let resolve_rpc_listening_addrs listen_addr =
  P2p_resolve.resolve_addr
    ~default_addr:"localhost"
    ~default_port:default_rpc_port
    ~passive:true
    listen_addr

let resolve_metrics_addrs ?(default_metrics_port = default_metrics_port)
    metrics_addr =
  P2p_resolve.resolve_addr
    ~default_addr:"localhost"
    ~default_port:default_metrics_port
    ~passive:true
    metrics_addr

let resolve_bootstrap_addrs peers =
  List.concat_map_es
    (P2p_resolve.resolve_addr_with_peer_id
       ~default_addr:"::"
       ~default_port:default_p2p_port)
    peers

let bootstrap_peers config =
  Option.value
    ~default:config.blockchain_network.default_bootstrap_peers
    config.p2p.bootstrap_peers
