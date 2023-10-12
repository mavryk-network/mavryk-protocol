(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

module Selected_distribution_for_cycle = struct
  module Cache_client = struct
    type cached_value = (Signature.Public_key_hash.t * Stake_repr.t) list

    let namespace = Cache_repr.create_namespace "stake_distribution"

    let cache_index = 1

    let value_of_identifier ctxt identifier =
      let cycle = Cycle_repr.of_string_exn identifier in
      Storage.Stake.Selected_distribution_for_cycle.get ctxt cycle
  end

  module Cache = (val Cache_repr.register_exn (module Cache_client))

  let identifier_of_cycle cycle = Format.asprintf "%a" Cycle_repr.pp cycle

  let init ctxt cycle stakes =
    let open Lwt_result_syntax in
    let id = identifier_of_cycle cycle in
    let* ctxt =
      Storage.Stake.Selected_distribution_for_cycle.init ctxt cycle stakes
    in
    let size = 1 (* that's symbolic: 1 cycle = 1 entry *) in
    let*? ctxt = Cache.update ctxt id (Some (stakes, size)) in
    return ctxt

  let get ctxt cycle =
    let open Lwt_result_syntax in
    let id = identifier_of_cycle cycle in
    let* value_opt = Cache.find ctxt id in
    match value_opt with
    | None -> Storage.Stake.Selected_distribution_for_cycle.get ctxt cycle
    | Some v -> return v

  let find ctxt cycle =
    let open Lwt_result_syntax in
    let id = identifier_of_cycle cycle in
    let* value_opt = Cache.find ctxt id in
    match value_opt with
    | None -> Storage.Stake.Selected_distribution_for_cycle.find ctxt cycle
    | Some _ as some_v -> return some_v

  let remove_existing ctxt cycle =
    let open Lwt_result_syntax in
    let id = identifier_of_cycle cycle in
    let*? ctxt = Cache.update ctxt id None in
    Storage.Stake.Selected_distribution_for_cycle.remove_existing ctxt cycle
end

let get_full_staking_balance ctxt delegate =
  let open Lwt_result_syntax in
  let+ staking_balance_opt = Storage.Stake.Staking_balance.find ctxt delegate in
  Option.value staking_balance_opt ~default:Full_staking_balance_repr.zero

let get_initialized_stake ctxt delegate =
  let open Lwt_result_syntax in
  let* balance_opt = Storage.Stake.Staking_balance.find ctxt delegate in
  match balance_opt with
  | Some staking_balance -> return (staking_balance, ctxt)
  | None ->
      let balance = Full_staking_balance_repr.zero in
      let* ctxt = Storage.Stake.Staking_balance.init ctxt delegate balance in
      return (balance, ctxt)

let has_minimal_stake ctxt staking_balance =
  let minimal_stake = Constants_storage.minimal_stake ctxt in
  Full_staking_balance_repr.has_minimal_stake ~minimal_stake staking_balance

let has_minimal_stake_and_frozen_stake ctxt full_staking_balance =
  let minimal_frozen_stake = Constants_storage.minimal_frozen_stake ctxt in
  let minimal_stake = Constants_storage.minimal_stake ctxt in
  Full_staking_balance_repr.has_minimal_stake_and_frozen_stake
    ~minimal_stake
    ~minimal_frozen_stake
    full_staking_balance

let update_stake ~f ctxt delegate =
  let open Lwt_result_syntax in
  let* staking_balance_before, ctxt = get_initialized_stake ctxt delegate in
  let*? staking_balance = f staking_balance_before in
  let* ctxt =
    Storage.Stake.Staking_balance.update ctxt delegate staking_balance
  in
  (* Since the staking balance has changed, the delegate might have
     moved across the minimal stake barrier. If so we may need to
     update the set of active delegates with minimal stake. *)
  let had_minimal_stake_before =
    has_minimal_stake ctxt staking_balance_before
  in
  let has_minimal_stake_after = has_minimal_stake ctxt staking_balance in
  match (had_minimal_stake_before, has_minimal_stake_after) with
  | true, false ->
      (* Decrease below the minimal stake. *)
      let* inactive = Delegate_activation_storage.is_inactive ctxt delegate in
      if inactive then
        (* The delegate is inactive so it wasn't in the set and we
           don't need to update it. *)
        return ctxt
      else
        let*! ctxt =
          Storage.Stake.Active_delegates_with_minimal_stake.remove ctxt delegate
        in
        return ctxt
  | false, true ->
      (* Increase above the minimal stake. *)
      let* inactive = Delegate_activation_storage.is_inactive ctxt delegate in
      if inactive then
        (* The delegate is inactive so we don't need to add it to the
           set. *)
        return ctxt
      else
        let*! ctxt =
          Storage.Stake.Active_delegates_with_minimal_stake.add ctxt delegate
        in
        return ctxt
  | false, false | true, true -> return ctxt

let remove_delegated_stake ctxt delegate amount =
  let current_cycle = (Raw_context.current_level ctxt).cycle in
  let f = Full_staking_balance_repr.remove_delegated ~current_cycle ~amount in
  update_stake ctxt delegate ~f

let remove_own_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.remove_own_frozen ~amount in
  update_stake ctxt delegate ~f

let remove_staked_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.remove_staked_frozen ~amount in
  update_stake ctxt delegate ~f

let remove_shared_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.remove_shared_frozen ~amount in
  update_stake ctxt delegate ~f

let remove_frozen_stake ctxt staker amount =
  match staker with
  | Staker_repr.Single (contract, delegate)
    when Contract_repr.(contract = Implicit delegate) ->
      remove_own_frozen_stake ctxt delegate amount
  | Single (_staker, delegate) ->
      remove_staked_frozen_stake ctxt delegate amount
  | Shared delegate -> remove_shared_frozen_stake ctxt delegate amount

let add_delegated_stake ctxt delegate amount =
  let current_cycle = (Raw_context.current_level ctxt).cycle in
  let f = Full_staking_balance_repr.add_delegated ~current_cycle ~amount in
  update_stake ctxt delegate ~f

let add_own_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.add_own_frozen ~amount in
  update_stake ctxt delegate ~f

let add_staked_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.add_staked_frozen ~amount in
  update_stake ctxt delegate ~f

let add_shared_frozen_stake ctxt delegate amount =
  let f = Full_staking_balance_repr.add_shared_frozen ~amount in
  update_stake ctxt delegate ~f

let add_frozen_stake ctxt staker amount =
  match staker with
  | Staker_repr.Single (contract, delegate)
    when Contract_repr.(contract = Implicit delegate) ->
      add_own_frozen_stake ctxt delegate amount
  | Single (_staker, delegate) -> add_staked_frozen_stake ctxt delegate amount
  | Shared delegate -> add_shared_frozen_stake ctxt delegate amount

let set_inactive ctxt delegate =
  let open Lwt_syntax in
  let* ctxt = Delegate_activation_storage.set_inactive ctxt delegate in
  Storage.Stake.Active_delegates_with_minimal_stake.remove ctxt delegate

let set_active ctxt delegate =
  let open Lwt_result_syntax in
  let* ctxt, inactive = Delegate_activation_storage.set_active ctxt delegate in
  if not inactive then return ctxt
  else
    let* staking_balance, ctxt = get_initialized_stake ctxt delegate in
    if has_minimal_stake ctxt staking_balance then
      let*! ctxt =
        Storage.Stake.Active_delegates_with_minimal_stake.add ctxt delegate
      in
      return ctxt
    else return ctxt

let max_snapshot_index = Storage.Stake.Last_snapshot.get

let set_selected_distribution_for_cycle ctxt cycle stakes total_stake =
  let open Lwt_result_syntax in
  let stakes = List.sort (fun (_, x) (_, y) -> Stake_repr.compare y x) stakes in
  let* ctxt = Selected_distribution_for_cycle.init ctxt cycle stakes in
  let*! ctxt = Storage.Stake.Total_active_stake.add ctxt cycle total_stake in
  Storage.Stake.Last_snapshot.update ctxt 0

let clear_cycle ctxt cycle =
  let open Lwt_result_syntax in
  let* ctxt = Storage.Stake.Total_active_stake.remove_existing ctxt cycle in
  Selected_distribution_for_cycle.remove_existing ctxt cycle

let fold_on_active_delegates_with_minimal_stake_es ctxt ~f ~order ~init =
  let open Lwt_result_syntax in
  Storage.Stake.Active_delegates_with_minimal_stake.fold
    ctxt
    ~order
    ~init:(Ok init)
    ~f:(fun delegate acc ->
      let*? acc in
      f delegate acc)

let clear_at_cycle_end ctxt ~new_cycle =
  let max_slashing_period = Constants_repr.max_slashing_period in
  match Cycle_repr.sub new_cycle max_slashing_period with
  | None -> return ctxt
  | Some cycle_to_clear -> clear_cycle ctxt cycle_to_clear

let fold_on_active_delegates_with_minimal_stake_s =
  Storage.Stake.Active_delegates_with_minimal_stake.fold

let get_selected_distribution = Selected_distribution_for_cycle.get

let find_selected_distribution = Selected_distribution_for_cycle.find

let prepare_stake_distribution ctxt =
  let open Lwt_result_syntax in
  let level = Level_storage.current ctxt in
  let* stakes = Selected_distribution_for_cycle.get ctxt level.cycle in
  let stake_distribution =
    List.fold_left
      (fun map (pkh, stake) -> Signature.Public_key_hash.Map.add pkh stake map)
      Signature.Public_key_hash.Map.empty
      stakes
  in
  return
    (Raw_context.init_stake_distribution_for_current_cycle
       ctxt
       stake_distribution)

let get_total_active_stake = Storage.Stake.Total_active_stake.get

let remove_contract_delegated_stake ctxt contract amount =
  let open Lwt_result_syntax in
  let* delegate_opt = Contract_delegate_storage.find ctxt contract in
  match delegate_opt with
  | None -> return ctxt
  | Some delegate -> remove_delegated_stake ctxt delegate amount

let add_contract_delegated_stake ctxt contract amount =
  let open Lwt_result_syntax in
  let* delegate_opt = Contract_delegate_storage.find ctxt contract in
  match delegate_opt with
  | None -> return ctxt
  | Some delegate -> add_delegated_stake ctxt delegate amount

module For_RPC = struct
  let get_staking_balance ctxt delegate =
    let open Lwt_result_syntax in
    let* staking_balance = Storage.Stake.Staking_balance.get ctxt delegate in
    let own_frozen = Full_staking_balance_repr.own_frozen staking_balance in
    let staked_frozen =
      Full_staking_balance_repr.staked_frozen staking_balance
    in
    let delegated =
      Full_staking_balance_repr.current_delegated staking_balance
    in
    let*? frozen = Tez_repr.(own_frozen +? staked_frozen) in
    let*? staking_balance = Tez_repr.(frozen +? delegated) in
    return staking_balance
end

module Internal_for_tests = struct
  let get ctxt delegate =
    let open Lwt_result_syntax in
    let*! result =
      Storage.Stake.Active_delegates_with_minimal_stake.mem ctxt delegate
    in
    match result with
    | true -> For_RPC.get_staking_balance ctxt delegate
    | false -> return Tez_repr.zero
end
