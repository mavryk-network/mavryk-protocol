(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs. <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

let build_rpc_directory node_version config store =
  let static_dir = Tezos_shell.Version_directory.rpc_directory node_version in
  let dir =
    Tezos_shell.Config_directory.build_rpc_directory_for_rpc_process
      ~user_activated_upgrades:
        config.Config_file.blockchain_network.user_activated_upgrades
      ~user_activated_protocol_overrides:
        config.blockchain_network.user_activated_protocol_overrides
      ~dal_config:config.blockchain_network.dal_config
      dir
  in
  let static_dir =
    Tezos_rpc.Directory.register0
      static_dir
      Node_services.S.config
      (fun () () -> Lwt.return_ok config)
  in
  Tezos_rpc.Directory.register_dynamic_directory
    static_dir
    (Tezos_rpc.Path.subst1 Tezos_shell_services.Chain_services.path)
    (fun ((), chain) ->
      let dir =
        Tezos_shell.Chain_directory.rpc_directory_without_validator ()
      in
      let dir =
        Tezos_rpc.Directory.map
          (fun ((), _chain) ->
            match !store with
            | None -> assert false
            | Some store ->
                Tezos_shell.Chain_directory.get_chain_store_exn store chain)
          dir
      in
      Lwt.return dir)
