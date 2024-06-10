(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs, <contact@nomadic-labs.com>               *)
(* Copyright (c) 2023 Functori, <contact@functori.com>                       *)
(*****************************************************************************)

type signer = {
  alias : string;
  pkh : Signature.public_key_hash;
  pk : Signature.public_key;
  sk : Client_keys.sk_uri;
}

let get_signer cctxt pkh =
  let open Lwt_result_syntax in
  let* alias, pk, sk = Client_keys.get_key cctxt pkh in
  return {alias; pkh; pk; sk}

type mav = {mumav : int64}

type fee_parameter = {
  minimal_fees : mav;
  minimal_nanomav_per_byte : Q.t;
  minimal_nanomav_per_gas_unit : Q.t;
  force_low_fee : bool;
  fee_cap : mav;
  burn_cap : mav;
}

(* Encoding for Tez amounts, replicated from mempool. *)
let tez_encoding =
  let open Data_encoding in
  let decode {mumav} = Z.of_int64 mumav in
  let encode = Json.wrap_error (fun i -> {mumav = Z.to_int64 i}) in
  Data_encoding.def
    "mumav"
    ~title:"A millionth of a mav"
    ~description:"One million mumav make a mav (1 mav = 1e6 mumav)"
    (conv decode encode n)

(* Encoding for nano-Tez amounts, replicated from mempool. *)
let nanomav_encoding =
  let open Data_encoding in
  def
    "nanomav"
    ~title:"A thousandth of a mumav"
    ~description:"One thousand nanomav make a mumav (1 mav = 1e9 nanomav)"
    (conv
       (fun q -> (q.Q.num, q.Q.den))
       (fun (num, den) -> {Q.num; den})
       (tup2 z z))

let fee_parameter_encoding ~(default_fee_parameter : fee_parameter) =
  let open Data_encoding in
  conv
    (fun {
           minimal_fees;
           minimal_nanomav_per_byte;
           minimal_nanomav_per_gas_unit;
           force_low_fee;
           fee_cap;
           burn_cap;
         } ->
      ( minimal_fees,
        minimal_nanomav_per_byte,
        minimal_nanomav_per_gas_unit,
        force_low_fee,
        fee_cap,
        burn_cap ))
    (fun ( minimal_fees,
           minimal_nanomav_per_byte,
           minimal_nanomav_per_gas_unit,
           force_low_fee,
           fee_cap,
           burn_cap ) ->
      {
        minimal_fees;
        minimal_nanomav_per_byte;
        minimal_nanomav_per_gas_unit;
        force_low_fee;
        fee_cap;
        burn_cap;
      })
    (obj6
       (dft
          "minimal-fees"
          ~description:"Exclude operations with lower fees"
          tez_encoding
          default_fee_parameter.minimal_fees)
       (dft
          "minimal-nanomav-per-byte"
          ~description:"Exclude operations with lower fees per byte"
          nanomav_encoding
          default_fee_parameter.minimal_nanomav_per_byte)
       (dft
          "minimal-nanomav-per-gas-unit"
          ~description:"Exclude operations with lower gas fees"
          nanomav_encoding
          default_fee_parameter.minimal_nanomav_per_gas_unit)
       (dft
          "force-low-fee"
          ~description:
            "Don't check that the fee is lower than the estimated default"
          bool
          default_fee_parameter.force_low_fee)
       (dft
          "fee-cap"
          ~description:"The fee cap"
          tez_encoding
          default_fee_parameter.fee_cap)
       (dft
          "burn-cap"
          ~description:"The burn cap"
          tez_encoding
          default_fee_parameter.burn_cap))
