open Micheline

let admin_address = "mv1FpkYtjBvppr7rrrrBVKbmiDtcALjb4T21"

let buffer_init_storage =
  Script_repr.lazy_expr
    (Micheline.strip_locations
       (String (0, admin_address)))

let originate ctxt address_hash ~balance script =
  let open Lwt_result_syntax in
  let* ctxt =
    Contract_storage.raw_originate
      ctxt
      ~prepaid_bootstrap_storage:true
      address_hash
      ~script
  in
  let address = Contract_repr.Originated address_hash in
  let* size = Contract_storage.used_storage_space ctxt address in
  let* ctxt, _, origination_updates =
    Fees_storage.burn_origination_fees
      ~origin:Protocol_migration
      ctxt
      ~storage_limit:(Z.of_int64 Int64.max_int)
      ~payer:`Liquidity_baking_subsidies
  in
  let* ctxt, _, storage_updates =
    Fees_storage.burn_storage_fees
      ~origin:Protocol_migration
      ctxt
      ~storage_limit:(Z.of_int64 Int64.max_int)
      ~payer:`Liquidity_baking_subsidies
      size
  in
  let* ctxt, transfer_updates =
    Token.transfer
      ~origin:Protocol_migration
      ctxt
      `Liquidity_baking_subsidies
      (`Contract address)
      balance
  in
  let balance_updates =
    origination_updates @ storage_updates @ transfer_updates
  in
  let result : Migration_repr.origination_result =
    {
      balance_updates;
      originated_contracts = [address_hash];
      storage_size = size;
      paid_storage_size_diff = size;
    }
  in
  return (ctxt, result)

let init ctxt ~typecheck =
  let open Lwt_result_syntax in
  (* We use a custom origination nonce because it is unset when stitching from 009 *)
  let nonce = Operation_hash.hash_string ["buff, buff, buff."] in
  let ctxt = Raw_context.init_origination_nonce ctxt nonce in
  let* ctxt = Storage.Protocol_treasury.Toggle_ema.init ctxt 0l in
  let*? ctxt, buffer_address =
    Contract_storage.fresh_contract_from_current_nonce ctxt
  in
  let* ctxt = Storage.Protocol_treasury.Buffer_address.init ctxt buffer_address in
  let buffer_script =
    Script_repr.
      {
        code = Script_repr.lazy_expr Protocol_treasury_buffer.script;
        storage = buffer_init_storage;
      }
  in
  let* buffer_script, ctxt = typecheck ctxt buffer_script in
  let+ ctxt, buffer_result =
    originate ctxt buffer_address ~balance:Tez_repr.zero buffer_script
  in
  (* Unsets the origination nonce, which is okay because this is called after other originations in stitching. *)
  let ctxt = Raw_context.unset_origination_nonce ctxt in
  (ctxt, [buffer_result])
