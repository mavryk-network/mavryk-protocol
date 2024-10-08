(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

exception Rpc_dir_creation_failure of tztrace

module Directory = Resto_directory.Make (Mavryk_rpc.Encoding)

let hash_of_block ?cache (rpc_context : #Mavryk_rpc.Context.simple)
    (chain : Mavryk_shell_services.Shell_services.chain)
    (block : Mavryk_shell_services.Block_services.block) =
  let open Lwt_result_syntax in
  match
    Option.bind cache (fun table ->
        Stdlib.Hashtbl.find_opt table (chain, block))
  with
  | Some hash ->
      (* Result is in cache *)
      return hash
  | None ->
      let* hash =
        Mavryk_shell_services.Block_services.Empty.hash
          rpc_context
          ~chain
          ~block
          ()
      in
      (* Fill cache with result *)
      Option.iter
        (fun table -> Stdlib.Hashtbl.add table (chain, block) hash)
        cache ;
      return hash

type mode =
  | Light_client of Light.sources
  | Proxy_client
  | Proxy_server of {
      sleep : float -> unit Lwt.t;
      sym_block_caching_time : Ptime.span option;
      on_disk_proxy_builder :
        (Context_hash.t ->
        Mavryk_protocol_environment.Proxy_delegate.t tzresult Lwt.t)
        option;
    }

let to_client_server_mode = function
  | Light_client _ | Proxy_client -> Proxy.Client
  | Proxy_server _ -> Proxy.Server

let get_protocols ?expected_protocol rpc_context chain block =
  let open Lwt_result_syntax in
  let* ({next_protocol; _} as protocols) =
    Mavryk_shell_services.Block_services.protocols rpc_context ~chain ~block ()
  in
  match expected_protocol with
  | None -> return protocols
  | Some proto_hash ->
      if Protocol_hash.equal next_protocol proto_hash then return protocols
      else
        failwith
          "Protocol passed to the proxy (%a) and protocol of the node (%a) \
           differ."
          Protocol_hash.pp
          proto_hash
          Protocol_hash.pp
          next_protocol

type env_cache_key = Mavryk_shell_services.Chain_services.chain * Block_hash.t

module Env_cache_key_hashed_type :
  Stdlib.Hashtbl.HashedType with type t = env_cache_key = struct
  type t = env_cache_key

  let equal ((lchain, lblock) : t) ((rchain, rblock) : t) =
    (* Avoid using polymorphic equality *)
    lchain = rchain && Block_hash.equal lblock rblock

  let hash = Hashtbl.hash
end

module Env_cache =
  (* Rationale for this configuration:

     - Using LRU as it'll discard old heads if the client is always using
       the <head> identifier (supposing that new blocks keep coming)
     - overflow:Strong: we want collection to happen before the GC MUST do
       it, because we don't want performance to degrade with a nearly-full
       heap all the time.
     - accounting:Sloppy: because ringo specifies that Sloppy's antagonist
       (Precise) should mainly be used when removing a lot or inserting the same
       key often. We do none of that, so Sloppy seems better. *)
    Aches.Rache.Transfer (Aches.Rache.LRU) (Env_cache_key_hashed_type)
module Env_cache_lwt = Aches_lwt.Lache.Make_result (Env_cache)

let build_directory (printer : Mavryk_client_base.Client_context.printer)
    (rpc_context : Mavryk_rpc.Context.generic) (mode : mode) expected_protocol :
    unit Mavryk_rpc.Directory.t =
  let block_hash_cache =
    (* We consider that the duration of a run of a client command is
       below the time between blocks so that aliases (`head`, levels,
       ...) don't change. Obviously, this assumption is incorrect in
       a long living proxy server. *)
    match mode with
    | Proxy_server _ -> None
    | Light_client _ | Proxy_client -> Some (Stdlib.Hashtbl.create 17)
  in
  let make proxy_env chain block =
    match mode with
    | Light_client sources ->
        Proxy_getter.Of_rpc
          (fun (module P_RPC : Proxy_proto.PROTO_RPC) ->
            let open Lwt_syntax in
            let (module C) = Light_core.get_core proxy_env printer sources in
            let chain_string, block_string =
              Mavryk_shell_services.Block_services.
                (chain_to_string chain, to_string block)
            in
            let* () =
              Light_logger.Logger.(
                emit core_created (chain_string, block_string))
            in
            let module M = Proxy_getter.Make (C) (P_RPC) in
            Lwt.return (module M : Proxy_getter.M))
    | Proxy_client | Proxy_server {on_disk_proxy_builder = None; _} ->
        Proxy_getter.Of_rpc
          (fun (module P_RPC : Proxy_proto.PROTO_RPC) ->
            let module M = Proxy_getter.MakeProxy (P_RPC) in
            Lwt.return (module M : Proxy_getter.M))
    | Proxy_server {on_disk_proxy_builder = Some f; _} ->
        Proxy_getter.Of_data_dir f
  in
  (* proxy_server case: given that a new block arrives every minute,
     make the cache keep blocks from approximately the last hour.
     Starting at protocol G, blocks may arrive faster than one per minute.
     We can either forward the protocol's constants here, or do an
     RPC call to obtain the exact value.
     Anyway we're safe, having an appromixation here is fine. *)
  let envs_cache =
    Env_cache_lwt.create
      (match mode with
      | Proxy_server _ -> 64
      | Proxy_client | Light_client _ -> 16)
  in
  let get_env_rpc_context chain block =
    let open Lwt_result_syntax in
    let* block_hash =
      hash_of_block ?cache:block_hash_cache rpc_context chain block
    in
    let key = (chain, block_hash) in
    let compute_value (chain, block_hash) =
      let block_key = `Hash (block_hash, 0) in
      let* block_header =
        Mavryk_shell_services.Block_services.Empty.Header.shell_header
          rpc_context
          ~chain
          ~block:block_key
          ()
      in
      let* resulting_context_hash =
        Mavryk_shell_services.Block_services.Empty.resulting_context_hash
          rpc_context
          ~chain
          ~block:block_key
          ()
      in
      let* protocols =
        get_protocols ?expected_protocol rpc_context chain block_key
      in
      let* proxy_env =
        Registration.get_registered_proxy printer protocols.next_protocol
      in
      let (module Proxy_environment) = proxy_env in
      let ctx : Proxy_getter.rpc_context_args =
        {
          printer = Some printer;
          proxy_builder = make (module Proxy_environment) chain block_key;
          rpc_context;
          mode = to_client_server_mode mode;
          chain;
          block = block_key;
        }
      in
      let* initial_context =
        Proxy_environment.initial_context ctx resulting_context_hash
      in
      let mapped_directory =
        Mavryk_rpc.Directory.map
          (fun (_chain, _block) ->
            Lwt.return
              Mavryk_protocol_environment.
                {block_hash; block_header; context = initial_context})
          Proxy_environment.directory
      in
      return
        (Mavryk_rpc.Directory.register
           mapped_directory
           Mavryk_shell_services.Block_services.Empty.S.protocols
           (fun _ctxt () () -> return protocols))
    in
    Env_cache_lwt.bind_or_put envs_cache key compute_value Lwt.return
  in
  let get_env_rpc_context' chain block =
    let open Lwt_syntax in
    let* res = get_env_rpc_context chain block in
    match res with
    | Error trace -> (
        (* proto_directory expects a unit Directory.t Lwt.t, and we
           can't give it a unit tzresult Directory.t Lwt.t, hence
           we throw an exception instead if we can't make the
           directory.

           This happens notably in the proxy server case when a
           request is made for a block baked on a protocol differing
           from the protocol the proxy server is currently running on.

           In the proxy server case, we'd prefer to return a 404
           instead of a 500. Luckily, Resto handles the [Not_found]
           exception specially and returns a 404, which our
           query-forwarding middleware (see
           Mavryk_rpc_http.RPC_middleware) can then turn into a redirect
           to the node.

           In the client cases, we throw an exception (which Resto
           turns into a 500) and print the trace. *)
        match mode with
        | Proxy_server _ -> raise Not_found
        | Light_client _ | Proxy_client ->
            let* () =
              printer#warning
                "Error while building RPC directory (perhaps a protocol \
                 version mismatch between block and client?): %a"
                Error_monad.pp_print_trace
                trace
            in
            raise (Rpc_dir_creation_failure trace))
    | Ok res -> Lwt.return res
  in
  let proto_directory =
    (* register protocol-specific RPCs *)
    Mavryk_rpc.Directory.register_dynamic_directory
      Mavryk_rpc.Directory.empty
      (Mavryk_rpc.Path.prefix
         Mavryk_shell_services.Chain_services.path
         Mavryk_shell_services.Block_services.path)
      (fun ((_, chain), block) ->
        (* The Mavryk_protocol_environment.rpc_context values returned
           by init_env_rpc_context contain proxy_getter's RPC
           cache. We wanna keep it in between RPC calls, hence
           the use of get_env_rpc_context' to cache init_env_rpc_context
           values. *)
        get_env_rpc_context' chain block)
  in
  Mavryk_rpc.Directory.register_describe_directory_service
    proto_directory
    Mavryk_rpc.Service.description_service
