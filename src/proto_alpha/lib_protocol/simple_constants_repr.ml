module MAKE =
functor
  (W : sig
     type 'a w

     val w : 'a Data_encoding.t -> 'a w Data_encoding.t
   end)
  ->
  struct
    open W

    type 'a w = 'a W.w

    type t = {
      preserved_cycles : int w;
      hard_gas_limit_per_operation : Gas_limit_repr.Arith.integral w;
    }

    let encoding : t Data_encoding.t =
      let open Data_encoding in
      conv
        (fun {preserved_cycles; hard_gas_limit_per_operation} ->
          (preserved_cycles, hard_gas_limit_per_operation))
        (fun (preserved_cycles, hard_gas_limit_per_operation) ->
          {preserved_cycles; hard_gas_limit_per_operation})
        (obj2
           (req "preserved_cycles" (w uint8))
           (req
              "hard_gas_limit_per_operation"
              (w Gas_limit_repr.Arith.z_integral_encoding)))
  end

module Optional = MAKE (struct
  type 'a w = 'a option

  let w e = Data_encoding.option e
end)

include MAKE (struct
  type 'a w = 'a

  let w e = e
end)
