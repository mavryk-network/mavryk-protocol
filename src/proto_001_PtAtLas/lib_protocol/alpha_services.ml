(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2019-2020 Nomadic Labs <contact@nomadic-labs.com>           *)
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

open Alpha_context

let custom_root = RPC_path.open_root

module Seed_computation = struct
  module S = struct
    let seed_computation_status_encoding =
      let open Seed in
      Data_encoding.(
        union
          [
            case
              (Tag 0)
              ~title:"Nonce revelation stage"
              (obj1 (req "nonce_revelation_stage" unit))
              (function Nonce_revelation_stage -> Some () | _ -> None)
              (fun () -> Nonce_revelation_stage);
            case
              (Tag 1)
              ~title:"VDF revelation stage"
              (obj2
                 (req "seed_discriminant" Seed.seed_encoding)
                 (req "seed_challenge" Seed.seed_encoding))
              (function
                | Vdf_revelation_stage {seed_discriminant; seed_challenge} ->
                    Some (seed_discriminant, seed_challenge)
                | _ -> None)
              (fun (seed_discriminant, seed_challenge) ->
                Vdf_revelation_stage {seed_discriminant; seed_challenge});
            case
              (Tag 2)
              ~title:"Computation finished"
              (obj1 (req "computation_finished" unit))
              (function Computation_finished -> Some () | _ -> None)
              (fun () -> Computation_finished);
          ])

    let seed_computation =
      RPC_service.get_service
        ~description:"Seed computation status"
        ~query:RPC_query.empty
        ~output:seed_computation_status_encoding
        RPC_path.(custom_root / "context" / "seed_computation")
  end

  let () =
    let open Services_registration in
    register0 ~chunked:false S.seed_computation (fun ctxt () () ->
        Seed.get_seed_computation_status ctxt)

  let get ctxt block =
    RPC_context.make_call0 S.seed_computation ctxt block () ()
end

module Seed = struct
  module S = struct
    open Data_encoding

    let seed =
      RPC_service.post_service
        ~description:"Seed of the cycle to which the block belongs."
        ~query:RPC_query.empty
        ~input:empty
        ~output:Seed.seed_encoding
        RPC_path.(custom_root / "context" / "seed")
  end

  let () =
    let open Services_registration in
    register0 ~chunked:false S.seed (fun ctxt () () ->
        let l = Level.current ctxt in
        Seed.for_cycle ctxt l.cycle)

  let get ctxt block = RPC_context.make_call0 S.seed ctxt block () ()
end

module Nonce = struct
  type info = Revealed of Nonce.t | Missing of Nonce_hash.t | Forgotten

  let info_encoding =
    let open Data_encoding in
    union
      [
        case
          (Tag 0)
          ~title:"Revealed"
          (obj1 (req "nonce" Nonce.encoding))
          (function Revealed nonce -> Some nonce | _ -> None)
          (fun nonce -> Revealed nonce);
        case
          (Tag 1)
          ~title:"Missing"
          (obj1 (req "hash" Nonce_hash.encoding))
          (function Missing nonce -> Some nonce | _ -> None)
          (fun nonce -> Missing nonce);
        case
          (Tag 2)
          ~title:"Forgotten"
          empty
          (function Forgotten -> Some () | _ -> None)
          (fun () -> Forgotten);
      ]

  module S = struct
    let get =
      RPC_service.get_service
        ~description:"Info about the nonce of a previous block."
        ~query:RPC_query.empty
        ~output:info_encoding
        RPC_path.(custom_root / "context" / "nonces" /: Raw_level.rpc_arg)
  end

  let register () =
    let open Lwt_result_syntax in
    let open Services_registration in
    register1 ~chunked:false S.get (fun ctxt raw_level () () ->
        let level = Level.from_raw ctxt raw_level in
        let*! status = Nonce.get ctxt level in
        match status with
        | Ok (Revealed nonce) -> return (Revealed nonce)
        | Ok (Unrevealed {nonce_hash; _}) -> return (Missing nonce_hash)
        | Error _ -> return Forgotten)

  let get ctxt block level = RPC_context.make_call1 S.get ctxt block level () ()
end

type error += No_available_snapshots of {min_cycle : int32}

let () =
  Error_monad.register_error_kind
    `Permanent
    ~id:"no_available_snapshots"
    ~title:"No available snapshots"
    ~description:"No available snapshots"
    ~pp:(fun ppf min_cycle ->
      Format.fprintf ppf "No available snapshots until cycle %ld" min_cycle)
    Data_encoding.(obj1 (req "min_cycle" int32))
    (function
      | No_available_snapshots {min_cycle} -> Some min_cycle | _ -> None)
    (fun min_cycle -> No_available_snapshots {min_cycle})

module Snapshot_index = struct
  module S = struct
    let cycle_query : Cycle.t option RPC_query.t =
      let open RPC_query in
      query (fun x -> x)
      |+ opt_field "cycle" Cycle.rpc_arg (fun cycle -> cycle)
      |> seal

    let selected_snapshot =
      RPC_service.get_service
        ~description:
          "Returns the index of the selected snapshot for the current cycle or \
           for the specific `cycle` passed as argument, if any."
        ~query:cycle_query
        ~output:Data_encoding.int31
        RPC_path.(custom_root / "context" / "selected_snapshot")
  end

  let register () =
    let open Services_registration in
    register0 ~chunked:false S.selected_snapshot (fun ctxt cycle () ->
        (* max_snapshot_index can be determined using constants only *)
        let blocks_per_stake_snapshot =
          Alpha_context.Constants.blocks_per_stake_snapshot ctxt
        in
        let blocks_per_cycle = Alpha_context.Constants.blocks_per_cycle ctxt in
        let preserved_cycles =
          Int32.of_int (Alpha_context.Constants.preserved_cycles ctxt)
        in
        let cycle =
          match cycle with
          | None -> Level.(current ctxt).cycle
          | Some cycle -> cycle
        in
        if Compare.Int32.(Cycle.to_int32 cycle <= Int32.succ preserved_cycles)
        then
          (* Early cycles are corner cases, fail if requested *)
          tzfail
            (No_available_snapshots {min_cycle = Int32.add preserved_cycles 2l})
        else
          let max_snapshot_index =
            Int32.div blocks_per_cycle blocks_per_stake_snapshot |> Int32.to_int
          in
          Alpha_context.Stake_distribution.compute_snapshot_index
            ctxt
            cycle
            ~max_snapshot_index)

  let get ctxt block ?cycle () =
    RPC_context.make_call0 S.selected_snapshot ctxt block cycle ()
end

module Contract = Contract_services
module Constants = Constants_services
module Delegate = Delegate_services
module Voting = Voting_services
module Sapling = Sapling_services
module Adaptive_issuance = Adaptive_issuance_services

module Liquidity_baking = struct
  module S = struct
    let get_cpmm_address =
      RPC_service.get_service
        ~description:"Liquidity baking CPMM address"
        ~query:RPC_query.empty
        ~output:Alpha_context.Contract.originated_encoding
        RPC_path.(custom_root / "context" / "liquidity_baking" / "cpmm_address")
  end

  let register () =
    let open Services_registration in
    register0 ~chunked:false S.get_cpmm_address (fun ctxt () () ->
        Alpha_context.Liquidity_baking.get_cpmm_address ctxt)

  let get_cpmm_address ctxt block =
    RPC_context.make_call0 S.get_cpmm_address ctxt block () ()
end

module Protocol_treasury = struct
  module S = struct
    let get_protocol_treasury_address =
      RPC_service.get_service
        ~description:"Protocol treasury address"
        ~query:RPC_query.empty
        ~output:Alpha_context.Contract.originated_encoding
        RPC_path.(custom_root / "context" / "protocol_treasury" / "address")

    let get_buffer_address =
      RPC_service.get_service
        ~description:"Protocol treasury buffer address"
        ~query:RPC_query.empty
        ~output:Alpha_context.Contract.originated_encoding
        RPC_path.(custom_root / "context" / "protocol_treasury" / "buffer_address")
  end

  let register () =
    let open Services_registration in
    register0 ~chunked:false S.get_protocol_treasury_address (fun _ctxt () () ->
        return Alpha_context.Protocol_treasury.get_protocol_treasury_address) ;
    register0 ~chunked:false S.get_buffer_address (fun ctxt () () ->
        Alpha_context.Protocol_treasury.get_buffer_address ctxt)

  let get_buffer_address ctxt block =
    RPC_context.make_call0 S.get_buffer_address ctxt block () ()

  let get_protocol_treasury_address ctxt block =
    RPC_context.make_call0 S.get_protocol_treasury_address ctxt block () ()
end

module Cache = struct
  module S = struct
    let cached_contracts =
      RPC_service.get_service
        ~description:"Return the list of cached contracts"
        ~query:RPC_query.empty
        ~output:Data_encoding.(list @@ tup2 Contract_hash.encoding int31)
        RPC_path.(custom_root / "context" / "cache" / "contracts" / "all")

    let contract_cache_size =
      RPC_service.get_service
        ~description:"Return the size of the contract cache"
        ~query:RPC_query.empty
        ~output:Data_encoding.int31
        RPC_path.(custom_root / "context" / "cache" / "contracts" / "size")

    let contract_cache_size_limit =
      RPC_service.get_service
        ~description:"Return the size limit of the contract cache"
        ~query:RPC_query.empty
        ~output:Data_encoding.int31
        RPC_path.(
          custom_root / "context" / "cache" / "contracts" / "size_limit")

    let contract_rank =
      RPC_service.post_service
        ~description:
          "Return the number of cached contracts older than the provided \
           contract"
        ~query:RPC_query.empty
        ~input:Alpha_context.Contract.originated_encoding
        ~output:Data_encoding.(option int31)
        RPC_path.(custom_root / "context" / "cache" / "contracts" / "rank")
  end

  let register () =
    let open Services_registration in
    register0 ~chunked:true S.cached_contracts (fun ctxt () () ->
        Script_cache.entries ctxt |> Lwt.return) ;
    register0 ~chunked:false S.contract_cache_size (fun ctxt () () ->
        Script_cache.size ctxt |> return) ;
    register0 ~chunked:false S.contract_cache_size_limit (fun ctxt () () ->
        Script_cache.size_limit ctxt |> return) ;
    register0 ~chunked:false S.contract_rank (fun ctxt () contract ->
        Script_cache.contract_rank ctxt contract |> return)

  let cached_contracts ctxt block =
    RPC_context.make_call0 S.cached_contracts ctxt block () ()

  let contract_cache_size ctxt block =
    RPC_context.make_call0 S.contract_cache_size ctxt block () ()

  let contract_cache_size_limit ctxt block =
    RPC_context.make_call0 S.contract_cache_size_limit ctxt block () ()

  let contract_rank ctxt block contract =
    RPC_context.make_call0 S.contract_rank ctxt block () contract
end

module Denunciations = struct
  type denunciations_with_key =
    Signature.Public_key_hash.t * Denunciations_repr.item

  let denunciations_with_key_encoding : denunciations_with_key Data_encoding.t =
    let open Data_encoding in
    merge_objs
      (obj1 (req "slashed_delegate" Signature.Public_key_hash.encoding))
      Denunciations_repr.item_encoding

  module S = struct
    let denunciations =
      let open Data_encoding in
      RPC_service.get_service
        ~description:
          "Returns the denunciations for misbehavior in the current cycle."
        ~query:RPC_query.empty
        ~output:(list denunciations_with_key_encoding)
        RPC_path.(custom_root / "context" / "denunciations")
  end

  let register () =
    let open Services_registration in
    let open Lwt_result_syntax in
    register0 ~chunked:false S.denunciations (fun ctxt () () ->
        let*! r =
          Alpha_context.Delegate.For_RPC.current_cycle_denunciations_list ctxt
        in
        return r)

  let denunciations ctxt block =
    RPC_context.make_call0 S.denunciations ctxt block () ()
end

let register () =
  Contract.register () ;
  Constants.register () ;
  Delegate.register () ;
  Nonce.register () ;
  Snapshot_index.register () ;
  Voting.register () ;
  Sapling.register () ;
  Liquidity_baking.register () ;
  Protocol_treasury.register () ;
  Cache.register () ;
  Adaptive_issuance.register () ;
  Denunciations.register ()
