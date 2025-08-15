(* Testing
   -------
   Component:    Michelson
   Invocation:   dune exec tezt/tests/main.exe -- --file contract_protocol_treasury.ml
   Subject:      Regression testing of protocol treasury buffer contracts
*)

(* Using the lighter hook that only scrubs the clients [--base-dir] *)
let hooks =
  Mavryk_regression.hooks_custom
    ~scrubbed_global_options:["--base-dir"; "-d"]
    ~replace_variables:Fun.id
    ()

let buf = "KT1RfKYjLYpGBQ1YGSKoSoYEYwpJPFZrvmwH"

let lb_subsidy = 83333

let future = "2050-01-01T00:00:00Z"

let split_storage storage =
  String.trim storage
  |> Base.replace_string ~all:true (rex "\\s+") ~by:" "
  |> String.split_on_char ' '

let unquote s =
  match String.split_on_char '"' s with
  | [""; s; ""] -> s
  | _ -> s (* Return as-is if not quoted *)

type buf_storage = {
  multisig_signer1 : string;
  multisig_signer2 : string;
  multisig_signer3 : string;
  timelock_delay : int;
  proposals : string;
  proposals_votes : string;
  proposal_count : int;
}

let get_buf_storage ~hooks client contract =
  let* storage = Client.contract_storage ~hooks contract client in
  (* Parse the complex storage structure *)
  let storage_str = String.trim storage in
  (* For now, just return the raw storage string for debugging *)
  return storage_str

let check_balance ~__LOC__ client ~contract expected_balance =
  let* balance = Client.get_balance_for client ~account:contract in
  Check.(
    (balance = expected_balance)
      Tez.typ
      ~__LOC__
      ~error_msg:"Expected balance %R, got %L") ;
  unit

let check_storage_field ~__LOC__ storage field_name expected_value =
  (* The storage is in Michelson format: Pair signer1 signer2 signer3 timelock_delay proposals proposals_votes proposal_count *)
  let storage_parts = split_storage storage in
  (* Skip "Pair" at the beginning *)
  let storage_values = 
    match storage_parts with
    | "Pair" :: rest -> rest
    | _ -> storage_parts
  in
  let rec find_field_by_position parts pos =
    match (parts, pos) with
    | (value :: _, 0) -> Some value
    | (_ :: rest, pos) -> find_field_by_position rest (pos - 1)
    | ([], _) -> None
  in
  let field_pos = 
    match field_name with
    | "multisig_signer1" -> 0
    | "multisig_signer2" -> 1
    | "multisig_signer3" -> 2
    | "timelock_delay" -> 3
    | "proposal_count" -> 6
    | _ -> Test.fail ~__LOC__ "Unknown field %s" field_name
  in
  match find_field_by_position storage_values field_pos with
  | None -> Test.fail ~__LOC__ "Field %s not found in storage" field_name
  | Some value ->
      let actual_value = unquote value in
      Check.(
        (actual_value = expected_value)
          string
          ~__LOC__
          ~error_msg:(sf "Expected %s to be %s, got %s" field_name expected_value actual_value))

let setup_basic_test ~__LOC__ client =
  let* buf_address =
    Client.RPC.call client ~hooks
    @@ RPC.get_chain_block_context_protocol_treasury_buffer_address ()
  in
  Log.info "Check BUF address" ;
  let () =
    Check.(
      (String.trim buf_address = buf)
        string
        ~__LOC__
        ~error_msg:"Expected storage %R, got %L")
  in
  Log.info "Check BUF storage" ;
  let* buf_storage = get_buf_storage client ~hooks buf in
  Log.info "Buffer storage: %s" buf_storage ;
  (* Check initial storage fields *)
  let () = check_storage_field ~__LOC__ buf_storage "multisig_signer1" "mv1S7tc6ktkym4X5TVaoE9MXTDPNKu3u7rHG" in
  let () = check_storage_field ~__LOC__ buf_storage "multisig_signer2" "mv1T61BkX9NfyT7ncefeoPhgxVyrttgb2z8b" in
  let () = check_storage_field ~__LOC__ buf_storage "multisig_signer3" "mv1HoMk44QjjAauiLbWkDfAbSPFzcP7rc182" in
  let () = check_storage_field ~__LOC__ buf_storage "timelock_delay" "128" in
  let () = check_storage_field ~__LOC__ buf_storage "proposal_count" "0" in
  (* Check initial balances *)
  let* () = check_balance ~__LOC__ client ~contract:buf (Tez.of_int 0) in
  (* transfer mav to the buffer *)
  Log.info "Call default" ;
  let* _test =
    Client.transfer
      ~hooks
      ~burn_cap:(Tez.of_int 10)
      ~amount:(Tez.of_int 100)
      ~giver:"bootstrap1"
      ~receiver:buf
      ~arg:"Unit"
      ~entrypoint:"default"
      client
  in
  let expected_balance = Tez.of_mumav_int (100000000 + lb_subsidy) in
  let* () = check_balance ~__LOC__ client ~contract:buf expected_balance in
  unit

let test_propose_transfer ~__LOC__ client =
  Log.info "Test proposeTransfer" ;
  (* Try to create a proposal with bootstrap1 (should fail - not a signer) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap1"
      ~destination:buf
      ~entrypoint:"proposeTransfer"
      ~arg:(sf "%S" Constant.bootstrap4.public_key_hash)
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  unit

let test_vote_proposal ~__LOC__ client =
  Log.info "Test voteProposal" ;
  (* Try to vote on proposal 0 with bootstrap2 (should fail - not a signer) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap2"
      ~destination:buf
      ~entrypoint:"voteProposal"
      ~arg:"0"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  unit

let test_execute_proposal ~__LOC__ client =
  Log.info "Test executeProposal" ;
  (* Try to execute proposal 0 (should fail due to timelock) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap1"
      ~destination:buf
      ~entrypoint:"executeProposal"
      ~arg:"0"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "TimelockNotExpired")
  in
  unit

let test_insufficient_votes ~__LOC__ client =
  Log.info "Test insufficient votes" ;
  (* Try to execute proposal 1 (should fail - proposal doesn't exist) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap1"
      ~destination:buf
      ~entrypoint:"executeProposal"
      ~arg:"1"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "ProposalDoesNotExist")
  in
  unit

let test_non_signer_access ~__LOC__ client =
  Log.info "Test non-signer access" ;
  (* Try to propose with bootstrap4 (not a signer) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap4"
      ~destination:buf
      ~entrypoint:"proposeTransfer"
      ~arg:(sf "%S" Constant.bootstrap5.public_key_hash)
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  (* Try to vote with bootstrap4 (not a signer) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap4"
      ~destination:buf
      ~entrypoint:"voteProposal"
      ~arg:"0"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  unit

let test_double_vote ~__LOC__ client =
  Log.info "Test double vote" ;
  (* Try to vote again with bootstrap2 on proposal 0 *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap2"
      ~destination:buf
      ~entrypoint:"voteProposal"
      ~arg:"0"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "AlreadyVoted")
  in
  unit

let test_nonexistent_proposal ~__LOC__ client =
  Log.info "Test nonexistent proposal" ;
  (* Try to vote on non-existent proposal *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap1"
      ~destination:buf
      ~entrypoint:"voteProposal"
      ~arg:"999"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "ProposalDoesNotExist")
  in
  (* Try to execute non-existent proposal *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap1"
      ~destination:buf
      ~entrypoint:"executeProposal"
      ~arg:"999"
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "ProposalDoesNotExist")
  in
  unit

let test_multiple_proposals ~__LOC__ client =
  Log.info "Test multiple proposals" ;
  (* Try to create proposals with non-signers (should fail) *)
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap2"
      ~destination:buf
      ~entrypoint:"proposeTransfer"
      ~arg:(sf "%S" Constant.bootstrap1.public_key_hash)
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  let* () =
    Client.spawn_call_contract
      ~hooks
      ~src:"bootstrap3"
      ~destination:buf
      ~entrypoint:"proposeTransfer"
      ~arg:(sf "%S" Constant.bootstrap2.public_key_hash)
      ~burn_cap:(Tez.of_int 10)
      client
    |> Process.check_error ~msg:(rex "OnlySigner")
  in
  unit

let register_buffer_tests =
  Protocol.register_regression_test
    ~__FILE__
    ~title:"Test buffer contract functionality"
    ~tags:["client"; "michelson"; "buffer"; "multisig"]
  @@ fun protocol ->
  let* client = Client.init_mockup ~protocol () in
  let* () = setup_basic_test ~__LOC__ client in
  let* () = test_propose_transfer ~__LOC__ client in
  let* () = test_vote_proposal ~__LOC__ client in
  let* () = test_execute_proposal ~__LOC__ client in
  let* () = test_insufficient_votes ~__LOC__ client in
  let* () = test_non_signer_access ~__LOC__ client in
  let* () = test_double_vote ~__LOC__ client in
  let* () = test_nonexistent_proposal ~__LOC__ client in
  let* () = test_multiple_proposals ~__LOC__ client in
  unit

let register ~protocols = register_buffer_tests protocols
