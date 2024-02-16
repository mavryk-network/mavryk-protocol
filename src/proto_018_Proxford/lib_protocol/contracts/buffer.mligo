type storage = address

type parameter =
  | Default of unit
  | TransferFunds of address

type result = operation list * storage

let transferFunds (destinationAddr : address) (storage : storage) : result =
  begin
    if Mavryk.get_sender () <> storage
    then failwith "OnlyAdmin"
    else ();
    let total_balance = Mavryk.get_balance () in
    let destination_contract_opt = Mavryk.get_contract_opt destinationAddr in
    let destination_contract = 
      match destination_contract_opt with
        Some contract -> contract
      | None -> failwith "ContractsDoesNotExist" 
    in
    let transfer_operation = Mavryk.transaction () (total_balance) destination_contract in
    (([transfer_operation] : operation list), storage)
  end

let main (param, storage : parameter * storage) : result =
  begin
    match param with
    | Default _param -> (([] : operation list), storage)
    | TransferFunds param -> transferFunds param storage
  end
