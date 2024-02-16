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

let buf = "KT1TxqZ8QtKvLu3V3JH7Gx58n7Co8pgtpQU5"

let adm = "mv1FpkYtjBvppr7rrrrBVKbmiDtcALjb4T21"

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
      return admin = unquote admin;
  | _ ->
      Test.fail "Unparseable token contract storage in %S: %S," contract storage

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
      (buf_storage.token_address = adm)
        string
        ~__LOC__
        ~error_msg:"Expected storage %R, got %L")
  in
  (* transfer mav to the buffer *)
  Log.info "Call default" ;
  let arg = sf "Unit" Constant.bootstrap1.public_key_hash in
  let* () =
    Client.call_contract
      ~hooks
      ~amount:(Tez.of_int 100)
      ~src:Constant.bootstrap1.alias
      ~destination:buf
      ~entrypoint:"default"
      ~arg:"Unit"
      ~burn_cap:(Tez.of_int 10)
      client
  in
  (* transfer funds to another address *)
  Log.info "Call transferFunds" ;
  let arg = sf "(%S)" Constan.bootstrap2.public_key_hash in
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
