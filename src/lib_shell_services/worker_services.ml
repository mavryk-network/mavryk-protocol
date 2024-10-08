(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
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

open Data_encoding

module Prevalidators = struct
  module S = struct
    let list =
      Mavryk_rpc.Service.get_service
        ~description:"Lists the Prevalidator workers and their status."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (list
             (obj4
                (req "chain_id" Chain_id.encoding)
                (req
                   "status"
                   (Worker_types.worker_status_encoding
                      Mavryk_rpc.Error.encoding))
                (req
                   "information"
                   (Worker_types.worker_information_encoding
                      Mavryk_rpc.Error.encoding))
                (req "pipelines" int16)))
        Mavryk_rpc.Path.(root / "workers" / "prevalidators")

    let state =
      Mavryk_rpc.Service.get_service
        ~description:"Introspect the state of prevalidator workers."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (Worker_types.full_status_encoding
             Prevalidator_worker_state.Request.encoding
             Mavryk_rpc.Error.encoding)
        Mavryk_rpc.Path.(
          root / "workers" / "prevalidators" /: Chain_services.chain_arg)
  end

  open Mavryk_rpc.Context

  let list ctxt = make_call S.list ctxt () () ()

  let state ctxt h = make_call1 S.state ctxt h () ()
end

module Block_validator = struct
  module S = struct
    let state =
      Mavryk_rpc.Service.get_service
        ~description:"Introspect the state of the block_validator worker."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (Worker_types.full_status_encoding
             Block_validator_worker_state.Request.encoding
             Mavryk_rpc.Error.encoding)
        Mavryk_rpc.Path.(root / "workers" / "block_validator")
  end

  open Mavryk_rpc.Context

  let state ctxt = make_call S.state ctxt () () ()
end

module Peer_validators = struct
  module S = struct
    let list =
      Mavryk_rpc.Service.get_service
        ~description:"Lists the peer validator workers and their status."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (list
             (obj4
                (req "peer_id" P2p_peer.Id.encoding)
                (req
                   "status"
                   (Worker_types.worker_status_encoding
                      Mavryk_rpc.Error.encoding))
                (req
                   "information"
                   (Worker_types.worker_information_encoding
                      Mavryk_rpc.Error.encoding))
                (req
                   "pipelines"
                   Peer_validator_worker_state.pipeline_length_encoding)))
        Mavryk_rpc.Path.(
          root / "workers" / "chain_validators" /: Chain_services.chain_arg
          / "peers_validators")

    let state =
      Mavryk_rpc.Service.get_service
        ~description:"Introspect the state of a peer validator worker."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (Worker_types.full_status_encoding
             Peer_validator_worker_state.Request.encoding
             Mavryk_rpc.Error.encoding)
        Mavryk_rpc.Path.(
          root / "workers" / "chain_validators" /: Chain_services.chain_arg
          / "peers_validators" /: P2p_peer.Id.rpc_arg)
  end

  open Mavryk_rpc.Context

  let list ctxt n = make_call1 S.list ctxt n () ()

  let state ctxt n h = make_call2 S.state ctxt n h () ()
end

module Chain_validators = struct
  module S = struct
    let list =
      Mavryk_rpc.Service.get_service
        ~description:"Lists the chain validator workers and their status."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (list
             (obj4
                (req "chain_id" Chain_id.encoding)
                (req
                   "status"
                   (Worker_types.worker_status_encoding
                      Mavryk_rpc.Error.encoding))
                (req
                   "information"
                   (Worker_types.worker_information_encoding
                      Mavryk_rpc.Error.encoding))
                (req "pipelines" int16)))
        Mavryk_rpc.Path.(root / "workers" / "chain_validators")

    let state =
      Mavryk_rpc.Service.get_service
        ~description:"Introspect the state of a chain validator worker."
        ~query:Mavryk_rpc.Query.empty
        ~output:
          (Worker_types.full_status_encoding
             Chain_validator_worker_state.Request.encoding
             Mavryk_rpc.Error.encoding)
        Mavryk_rpc.Path.(
          root / "workers" / "chain_validators" /: Chain_services.chain_arg)

    let ddb_state =
      Mavryk_rpc.Service.get_service
        ~description:
          "Introspect the state of the DDB attached to a chain validator \
           worker."
        ~query:Mavryk_rpc.Query.empty
        ~output:Chain_validator_worker_state.Distributed_db_state.encoding
        Mavryk_rpc.Path.(
          root / "workers" / "chain_validators" /: Chain_services.chain_arg
          / "ddb")
  end

  open Mavryk_rpc.Context

  let list ctxt = make_call S.list ctxt () () ()

  let state ctxt h = make_call1 S.state ctxt h () ()

  let ddb_state ctxt h = make_call1 S.ddb_state ctxt h () ()
end
