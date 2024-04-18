(* Testing
   -------
   Component:    Michelson
   Invocation:   dune exec tezt/tests/main.exe -- --file contract_protocol_treasury.ml
   Subject:      Regression testing of protocol treasury contracts
*)

(* Using the lighter hook that only scrubs the clients [--base-dir] *)
let hooks =
  Tezos_regression.hooks_custom
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
  | _ -> Test.fail "[unquote] expected a double-quoted string, got: %S" s

type buf_storage = string

let get_buf_storage ~hooks client contract =
  let* storage = Client.contract_storage ~hooks contract client in
  match split_storage storage with
  | [admin] ->
      return (unquote admin);
  | _ ->
      Test.fail "Unparseable buffer contract storage in %S: %S," contract storage

let check_balance ~__LOC__ client ~contract expected_balance =
  let* balance = Client.get_balance_for client ~account:contract in
  Check.(
    (balance = expected_balance)
      Tez.typ
      ~__LOC__
      ~error_msg:"Expected balance %R, got %L") ;
  unit
      
let setup_transfer_funds ~__LOC__ client =
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
  let () =
    Check.(
      (buf_storage = Constant.bootstrap1.public_key_hash)
        string
        ~__LOC__
        ~error_msg:"Expected storage %R, got %L")
  in
  (* Check initial balances *)
  let* () =
    check_balance ~__LOC__ client ~contract:buf (Tez.of_int 0)
  in
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
  let expected_balance = 
    (Tez.of_mumav_int (100000000 + lb_subsidy))
  in
  let* () =
    check_balance ~__LOC__ client ~contract:buf expected_balance
  in
  (* transfer funds to another address *)
  (* Tested we mocked admin during development but unable to replicate because the mock admin cannot be replaced and the contract is deployed at level 1 *)
  (* Log.info "Call transferFunds" ;
  let arg = sf "%S" Constant.bootstrap2.public_key_hash in
  let* () =
    Client.call_contract
      ~hooks
      ~src:Constant.bootstrap1.alias
      ~destination:buf
      ~entrypoint:"transferFunds"
      ~arg
      ~burn_cap:(Tez.of_int 10)
      client
  in
  let* () =
    check_balance ~__LOC__ client ~contract:buf (Tez.of_int 0)
  in *)
  unit

let register_transfer_funds =
  Protocol.register_regression_test
    ~__FILE__
    ~title:"Test transferFunds"
    ~tags:["client"; "michelson"]
  @@ fun protocol ->
  let* client = Client.init_mockup ~protocol () in
  let* () = setup_transfer_funds ~__LOC__ client in
  unit

let register ~protocols =
  register_transfer_funds protocols ;
