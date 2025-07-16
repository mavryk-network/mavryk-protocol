open Per_block_votes_repr

let get_protocol_treasury_address = Storage.Protocol_treasury.address

let get_buffer_address = Storage.Protocol_treasury.Buffer_address.get

let get_toggle_ema ctxt =
  let open Lwt_result_syntax in
  let* ema = Storage.Protocol_treasury.Toggle_ema.get ctxt in
  Liquidity_baking_toggle_EMA.of_int32 ema

let on_buffer_exists ctxt f =
  let open Lwt_result_syntax in
  let* buffer_contract = get_buffer_address ctxt in
  let*! exists =
    Contract_storage.exists ctxt (Contract_repr.Originated buffer_contract)
  in
  match exists with
  | false ->
      (* do nothing if the buffer is not found *)
      return (ctxt, [])
  | true -> f ctxt buffer_contract

let on_protocol_treasury_exists ctxt f =
  let open Lwt_result_syntax in
  let*! protocol_treasury_exists =
    Contract_storage.exists
      ctxt
      (Contract_repr.Originated get_protocol_treasury_address)
  in
  match protocol_treasury_exists with
  | false -> f ctxt get_protocol_treasury_address
  | true -> f ctxt get_protocol_treasury_address

let update_toggle_ema ctxt ~per_block_vote =
  let open Lwt_result_syntax in
  let* old_ema = get_toggle_ema ctxt in
  let new_ema = compute_new_liquidity_baking_ema ~per_block_vote old_ema in
  let+ ctxt =
    Storage.Protocol_treasury.Toggle_ema.update
      ctxt
      (Liquidity_baking_toggle_EMA.to_int32 new_ema)
  in
  (ctxt, new_ema)

let check_ema_below_threshold ctxt ema =
  Liquidity_baking_toggle_EMA.(
    ema < Constants_storage.liquidity_baking_toggle_ema_threshold ctxt)

let on_subsidy_allowed ctxt ~per_block_vote f =
  let open Lwt_result_syntax in
  let* ctxt, toggle_ema = update_toggle_ema ctxt ~per_block_vote in
  if check_ema_below_threshold ctxt toggle_ema then
    let+ ctxt, operation_results = on_protocol_treasury_exists ctxt f in
    (ctxt, operation_results, toggle_ema)
  else return (ctxt, [], toggle_ema)
