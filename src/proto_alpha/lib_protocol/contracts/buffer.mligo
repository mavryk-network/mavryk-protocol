type storage =
  [@layout:comb]
 {
  multisig_signer1 : address;
  multisig_signer2 : address;
  multisig_signer3 : address;
  timelock_delay : nat;
  proposals : (nat, (address * nat)) map;
  proposals_votes : (nat, address set) map;
  proposal_count : nat;
}

type parameter =
  | Default of unit
  | ProposeTransfer of address
  | VoteProposal of nat
  | ExecuteProposal of nat

type result = operation list * storage

let is_signer (signer : address) (storage : storage) : bool =
  signer = storage.multisig_signer1 || signer = storage.multisig_signer2 || signer = storage.multisig_signer3

let proposeTransfer (destinationAddr : address) (storage : storage) : result =
  begin
    if not (is_signer (Mavryk.get_sender ()) storage)
    then failwith "OnlySigner"
    else ();
    let proposal = (destinationAddr, Mavryk.get_level ()) in
    let old_proposal_count = storage.proposal_count in
    let new_proposal_count = old_proposal_count + 1n in
    let new_proposals = Map.add old_proposal_count proposal storage.proposals in
    let new_storage = { storage with proposals = new_proposals; proposal_count = new_proposal_count } in
    (([], new_storage) : result)
  end

let voteProposal (proposal_id : nat) (storage : storage) : result =
  begin
    if not (is_signer (Mavryk.get_sender ()) storage)
    then failwith "OnlySigner"
    else ();
    match Map.find_opt proposal_id storage.proposals with
    | None -> failwith "ProposalDoesNotExist"
    | Some (_destinationAddr, _proposal_level) ->
        let sender = Mavryk.get_sender () in
        let proposal_votes = match Map.find_opt proposal_id storage.proposals_votes with
        | None -> Set.empty
        | Some votes -> votes
        in
        if Set.mem sender proposal_votes
        then failwith "AlreadyVoted"
        else ();
        let new_proposal_votes = Set.add sender proposal_votes in
        let new_storage = { storage with proposals_votes = Map.add proposal_id new_proposal_votes storage.proposals_votes } in
        (([], new_storage) : result)
  end

let executeProposal (proposal_id : nat) (storage : storage) : result =
  begin
    if not (is_signer (Mavryk.get_sender ()) storage)
    then failwith "OnlySigner"
    else ();
    match Map.find_opt proposal_id storage.proposals with
    | None -> failwith "ProposalDoesNotExist"
    | Some (destinationAddr, proposal_level) ->
        let now = Mavryk.get_level () in
        if now < proposal_level + storage.timelock_delay
        then failwith "TimelockNotExpired"
        else ();
        let proposal_votes = match Map.find_opt proposal_id storage.proposals_votes with
        | None -> Set.empty
        | Some votes -> votes
        in
        let vote_count = Set.cardinal proposal_votes in
        if vote_count < 2n
        then failwith "InsufficientVotes"
        else ();
        let total_balance = Mavryk.get_balance () in
        let destination_contract_opt = Mavryk.get_contract_opt destinationAddr in
        let destination_contract = 
          match destination_contract_opt with
            Some contract -> contract
          | None -> failwith "ContractsDoesNotExist" 
        in
        let transfer_operation = Mavryk.transaction () (total_balance) destination_contract in
        let new_proposals = Map.remove proposal_id storage.proposals in
        let new_proposals_votes = Map.remove proposal_id storage.proposals_votes in
        let new_storage = { storage with proposals = new_proposals; proposals_votes = new_proposals_votes } in
        (([transfer_operation] : operation list), new_storage)
  end

let main (param, storage : parameter * storage) : result =
  begin
    match param with
    | Default _param -> (([] : operation list), storage)
    | ProposeTransfer param -> proposeTransfer param storage
    | VoteProposal param -> voteProposal param storage
    | ExecuteProposal param -> executeProposal param storage
  end
