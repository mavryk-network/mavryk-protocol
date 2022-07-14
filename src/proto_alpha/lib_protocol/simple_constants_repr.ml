type t = {
  preserved_cycles : int;
  hard_gas_limit_per_operation : Gas_limit_repr.Arith.integral;
}

let encoding : t Data_encoding.t =
  let open Data_encoding in
  conv
    (fun {preserved_cycles; hard_gas_limit_per_operation} ->
      (preserved_cycles, hard_gas_limit_per_operation))
    (fun (preserved_cycles, hard_gas_limit_per_operation) ->
      {preserved_cycles; hard_gas_limit_per_operation})
    (obj2
       (req "preserved_cycles" uint8)
       (req
          "hard_gas_limit_per_operation"
          Gas_limit_repr.Arith.z_integral_encoding))
