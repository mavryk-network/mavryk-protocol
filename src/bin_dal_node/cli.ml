(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

module Types = Mavryk_dal_node_services.Types

module Term = struct
  let p2p_point_arg ~default_port =
    let open Cmdliner in
    let decoder str =
      match P2p_point.Id.of_string ~default_port str with
      | Ok x -> Ok x
      | Error msg -> Error (`Msg msg)
    in
    let printer = P2p_point.Id.pp in
    Arg.conv (decoder, printer)

  let docs = "OPTIONS"

  let data_dir =
    let open Cmdliner in
    let doc =
      Format.sprintf
        "The directory where the Mavkit DAL node will store all its data. \
         Parent directories are created if necessary."
    in
    Arg.(
      value
      & opt (some string) None
      & info ~docs ~docv:"DIR" ~doc ["data-dir"; "d"])

  let rpc_addr =
    let open Cmdliner in
    let default_port = Configuration_file.default.rpc_addr |> snd in
    let doc =
      Format.asprintf
        "The TCP address and optionally the port at which the RPC server of \
         this instance can be reached. The default address is 0.0.0.0. The \
         default port is 10732."
    in
    Arg.(
      value
      & opt (some (p2p_point_arg ~default_port)) None
      & info ~docs ~doc ~docv:"ADDR[:PORT]" ["rpc-addr"])

  let expected_pow =
    let open Cmdliner in
    let doc =
      "The expected proof-of-work difficulty level for the peers' identity."
    in
    Arg.(
      value
      & opt (some float) None
      & info ~docs ~doc ~docv:"FLOAT" ["expected-pow"])

  let net_addr =
    let open Cmdliner in
    let default_port = Configuration_file.default.listen_addr |> snd in
    let doc =
      Format.asprintf
        "The TCP address and optionally the port bound by the DAL node. If \
         --public-addr is not provided, this is also the address and port at \
         which this instance can be reached by other P2P nodes. The default \
         address is 0.0.0.0. The default port is 11732."
    in
    Arg.(
      value
      & opt (some (p2p_point_arg ~default_port)) None
      & info ~docs ~doc ~docv:"ADDR[:PORT]" ["net-addr"])

  let public_addr =
    let open Cmdliner in
    let default_port = Configuration_file.default.public_addr |> snd in
    let doc =
      Format.asprintf
        "The TCP address and optionally the port at which this instance can be \
         reached by other P2P nodes. The default address is 0.0.0.0. The \
         default port is 11732."
    in
    Arg.(
      value
      & opt (some (p2p_point_arg ~default_port)) None
      & info ~docs ~doc ~docv:"ADDR[:PORT]" ["public-addr"])

  let endpoint_arg =
    let open Cmdliner in
    let decoder string =
      try Uri.of_string string |> Result.ok
      with _ -> Error (`Msg "The string '%s' is not a valid URI")
    in
    let printer = Uri.pp_hum in
    Arg.conv (decoder, printer)

  let endpoint =
    let open Cmdliner in
    let doc =
      "The endpoint (an URI) of the Mavryk node that the DAL node should \
       connect to. The default endpoint is 'http://localhost:8732'."
    in
    Arg.(
      value
      & opt (some endpoint_arg) None
      & info ~docs ~doc ~docv:"URI" ["endpoint"])

  let operator_profile_printer fmt = function
    | Types.Attester pkh ->
        Format.fprintf fmt "%a" Signature.Public_key_hash.pp pkh
    | Producer {slot_index} -> Format.fprintf fmt "%d" slot_index
    | Observer {slot_index} -> Format.fprintf fmt "%d" slot_index

  let attester_profile_arg =
    let open Cmdliner in
    let decoder string =
      match Signature.Public_key_hash.of_b58check_opt string with
      | None -> Error (`Msg "Unrecognized profile")
      | Some pkh -> Types.Attester pkh |> Result.ok
    in
    Arg.conv (decoder, operator_profile_printer)

  let producer_profile_arg =
    let open Cmdliner in
    let decoder string =
      let error () =
        Format.kasprintf
          (fun s -> Error (`Msg s))
          "Unrecognized profile for producer (expected non-negative integer, \
           got %s)"
          string
      in
      match int_of_string_opt string with
      | None -> error ()
      | Some i when i < 0 -> error ()
      | Some slot_index -> Types.Producer {slot_index} |> Result.ok
    in
    Arg.conv (decoder, operator_profile_printer)

  let observer_profile_arg =
    let open Cmdliner in
    let decoder string =
      let error () =
        Format.kasprintf
          (fun s -> Error (`Msg s))
          "Unrecognized profile for observer (expected nonnegative integer, \
           got %s)"
          string
      in
      match int_of_string_opt string with
      | None -> error ()
      | Some i when i < 0 -> error ()
      | Some slot_index -> Types.Observer {slot_index} |> Result.ok
    in
    Arg.conv (decoder, operator_profile_printer)

  let attester_profile =
    let open Cmdliner in
    let doc =
      "The Mavkit DAL node attester profiles for given public key hashes."
    in
    Arg.(
      value
      & opt (list attester_profile_arg) []
      & info ~docs ~doc ~docv:"PKH1,PKH2,..." ["attester-profiles"])

  let producer_profile =
    let open Cmdliner in
    let doc = "The Mavkit DAL node producer profiles for given slot indexes." in
    Arg.(
      value
      & opt (list producer_profile_arg) []
      & info ~docs ~doc ~docv:"INDEX1,INDEX2,..." ["producer-profiles"])

  let observer_profile =
    let open Cmdliner in
    let doc = "The Mavkit DAL node observer profiles for given slot indexes." in
    Arg.(
      value
      & opt (list observer_profile_arg) []
      & info ~docs ~doc ~docv:"INDEX1,INDEX2,..." ["observer-profiles"])

  let bootstrap_profile =
    let open Cmdliner in
    let doc =
      "The Mavkit DAL node bootstrap node profile. Note that a bootstrap node \
       cannot also be an attester or a slot producer"
    in
    Arg.(value & flag & info ~docs ~doc ["bootstrap-profile"])

  let peers =
    let open Cmdliner in
    let default_list = Configuration_file.default.peers in
    let doc =
      "An additional peer list to expand the bootstrap peers from the Mavkit \
       node's configuration parameter dal_config.bootstrap_peers."
    in
    Arg.(
      value
      & opt (list string) default_list
      & info ~docs ~doc ~docv:"ADDR:PORT,..." ["peers"])

  let metrics_addr =
    let open Cmdliner in
    let doc =
      "The TCP address and optionally the port of the node's metrics server. \
       The default address is 0.0.0.0. The default port is 11733."
    in
    let default_port = Configuration_file.default.metrics_addr |> snd in
    Arg.(
      value
      & opt (some (p2p_point_arg ~default_port)) None
      & info ~docs ~doc ~docv:"ADDR[:PORT]" ["metrics-addr"])

  let history_mode =
    let open Cmdliner in
    let open Result_syntax in
    let doc =
      "The duration for the shards to be kept in the node storage. Either a \
       number, the string \"full\" or the string \"auto\". A number is \
       interpreted as the number of blocks the shards should be kept; the \
       string \"full\" means no shard deletion, the string \"auto\" means the \
       default of the profile: 3 months for an observer or a slot producer, \
       twice the attestation lag for an attester and other profiles."
    in
    let decoder =
      Configuration_file.(
        function
        | "full" -> return Full
        | "auto" -> return @@ Rolling {blocks = `Auto}
        | s -> (
            match int_of_string_opt s with
            | Some i -> return @@ Rolling {blocks = `Some i}
            | None ->
                Error (`Msg ("Invalid argument " ^ s ^ " for history-mode."))))
    in
    let printer fmt = function
      | Configuration_file.Full -> Format.fprintf fmt "full"
      | Rolling {blocks = `Auto} -> Format.fprintf fmt "auto"
      | Rolling {blocks = `Some i} -> Format.fprintf fmt "%d" i
    in
    let history_mode_arg = Arg.conv (decoder, printer) in
    Arg.(
      value
      & opt (some history_mode_arg) None
      & info ~docs ~doc ["history-mode"])

  let term process =
    Cmdliner.Term.(
      ret
        (const process $ data_dir $ rpc_addr $ expected_pow $ net_addr
       $ public_addr $ endpoint $ metrics_addr $ attester_profile
       $ producer_profile $ observer_profile $ bootstrap_profile $ peers
       $ history_mode))
end

module Run = struct
  let description =
    [`S "DESCRIPTION"; `P "This command runs an Mavkit DAL node."]

  let man = description

  let info =
    let version = Mavryk_version_value.Bin_version.mavkit_version_string in
    Cmdliner.Cmd.info ~doc:"Run the Mavkit DAL node" ~man ~version "run"

  let cmd run = Cmdliner.Cmd.v info (Term.term run)
end

module Config = struct
  let description =
    [
      `S "CONFIG DESCRIPTION";
      `P
        "Entry point for initializing, configuring and running an Mavkit DAL \
         node.";
    ]

  let man = description

  module Init = struct
    let man =
      [
        `S "DESCRIPTION";
        `P
          "This commands creates a configuration file with the parameters \
           provided on the command-line, if no configuration file exists \
           already in the specified or default location. Otherwise, the \
           command-line parameters override the existing ones, and old \
           parameters are lost. This configuration is then used by the run \
           command.";
      ]

    let info =
      let version = Mavryk_version_value.Bin_version.mavkit_version_string in
      Cmdliner.Cmd.info ~doc:"Configuration initialisation" ~man ~version "init"

    let cmd run = Cmdliner.Cmd.v info (Term.term run)
  end

  let cmd run =
    let default = Cmdliner.Term.(ret (const (`Help (`Pager, None)))) in
    let info =
      let version = Mavryk_version_value.Bin_version.mavkit_version_string in
      Cmdliner.Cmd.info
        ~doc:"Manage the Mavkit DAL node configuration"
        ~man
        ~version
        "config"
    in
    Cmdliner.Cmd.group ~default info [Init.cmd run]
end

type options = {
  data_dir : string option;
  rpc_addr : P2p_point.Id.t option;
  expected_pow : float option;
  listen_addr : P2p_point.Id.t option;
  public_addr : P2p_point.Id.t option;
  endpoint : Uri.t option;
  profiles : Types.profiles option;
  metrics_addr : P2p_point.Id.t option;
  peers : string list;
  history_mode : Configuration_file.history_mode option;
}

type t = Run | Config_init

let make ~run =
  let run subcommand data_dir rpc_addr expected_pow listen_addr public_addr
      endpoint metrics_addr attesters producers observers bootstrap_flag peers
      history_mode =
    let run profiles =
      run
        subcommand
        {
          data_dir;
          rpc_addr;
          expected_pow;
          listen_addr;
          public_addr;
          endpoint;
          profiles;
          metrics_addr;
          peers;
          history_mode;
        }
    in
    match (bootstrap_flag, attesters @ producers @ observers) with
    | false, [] -> run None
    | true, [] -> run @@ Some Types.Bootstrap
    | false, operator_profiles -> run @@ Some (Operator operator_profiles)
    | true, _ :: _ ->
        `Error
          ( false,
            "A bootstrap node cannot also be an attester or a slot producer." )
  in
  let default = Cmdliner.Term.(ret (const (`Help (`Pager, None)))) in
  let info =
    let version = Mavryk_version_value.Bin_version.mavkit_version_string in
    Cmdliner.Cmd.info ~doc:"The Mavkit DAL node" ~version "mavkit-dal-node"
  in
  Cmdliner.Cmd.group
    ~default
    info
    [Run.cmd (run Run); Config.cmd (run Config_init)]
