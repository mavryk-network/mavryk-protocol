(* SPDX-CopyrightText Trilitech <contact@trili.tech> *)
(* SPDX-CopyrightText Nomadic Labs <contact@nomadic-labs.com> *)

#include "./ticket_type.mligo"

type storage = unit

type parameter =
  | Mint of address
  | Burn of (address * tez_ticket)

type return = operation list * storage

// Mint creates [Mavryk.get_amount ()] tickets and transfers them to [address].
let mint address : return =
  let contract : tez_ticket contract =
    Mavryk.get_contract_with_error address "Invalid callback"
  in
  let amount: nat = Mavryk.get_amount () / 1mumav in
  let tickets : tez_ticket =
    match Mavryk.create_ticket (0n, None) amount with
    | Some (t : tez_ticket) -> t
    | None -> failwith "Could not mint ticket."
  in
  ([Mavryk.transaction tickets 0mumav contract], ())

// Burn destructs the [ticket] and sends back the tez to [address].
let burn address (ticket: tez_ticket) : return =
  if Mavryk.get_amount () > 0tez then
    failwith "Burn does not accept tez."
  else
    let (addr, (_, amt)), _ticket = Mavryk.read_ticket ticket in
    if addr <> (Mavryk.get_self_address ()) then
      failwith "Burn only accepts tez tickets."
    else
      let contract = Mavryk.get_contract_with_error address "Invalid callback" in
      let amount: mav = amt * 1mumav in
      ([Mavryk.transaction () amount contract], ())

(* Main access point that dispatches to the entrypoints according to
   the smart contract parameter. *)
let main (action, _store : parameter * storage) : return =
  match action with
  | Mint callback -> mint callback
  | Burn (callback, tt) -> burn callback tt
