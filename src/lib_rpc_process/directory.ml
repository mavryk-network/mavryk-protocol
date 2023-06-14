(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs. <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

let monitor_head dir (store : Store.t option ref)
    (head_watcher : (Block_hash.t * Block_header.t) Lwt_watcher.input) =
  let dir = ref dir in
  let gen_register1 s f =
    dir := Tezos_rpc.Directory.gen_register !dir s (fun ((), a) p q -> f a p q)
  in
  gen_register1 Tezos_shell_services.Monitor_services.S.heads (fun chain q () ->
      let open Lwt_syntax in
      let head_watcher = Lwt_watcher.create_stream head_watcher in
      let* store =
        match !store with
        | Some store -> return store
        | None -> Lwt.fail Not_found
      in
      Tezos_shell.Monitor_directory.monitor_head ~head_watcher store chain q ()) ;
  !dir

let build_rpc_directory node_version config dynamic_store
    ~(head_watcher : (Block_hash.t * Block_header.t) Lwt_watcher.input) =
  let static_dir = Tezos_shell.Version_directory.rpc_directory node_version in
  let static_dir =
    Tezos_shell.Config_directory.build_rpc_directory_for_rpc_process
      ~user_activated_upgrades:
        config.Config_file.blockchain_network.user_activated_upgrades
      ~user_activated_protocol_overrides:
        config.blockchain_network.user_activated_protocol_overrides
      ~dal_config:config.blockchain_network.dal_config
      static_dir
  in
  let static_dir =
    Tezos_rpc.Directory.register0
      static_dir
      Node_services.S.config
      (fun () () -> Lwt.return_ok config)
  in
  let static_dir = monitor_head static_dir dynamic_store head_watcher in
  Tezos_rpc.Directory.register_dynamic_directory
    static_dir
    (Tezos_rpc.Path.subst1 Tezos_shell_services.Chain_services.path)
    (fun ((), chain) ->
      let dir = Tezos_shell.Chain_directory.rpc_directory_generic () in
      let dir =
        Tezos_rpc.Directory.map
          (fun ((), _chain) ->
            let store = !dynamic_store in
            match store with
            | None -> Lwt.fail Not_found
            | Some store ->
                Tezos_shell.Chain_directory.get_chain_store_exn store chain)
          dir
      in
      Lwt.return dir)
