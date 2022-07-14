module type S = Simple_constants_repr_intf.S

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

module Required = MAKE (struct
  type 'a w = 'a

  let w e = e
end)

module Mapper
    (M1 : S)
    (M2 : S) (M : sig
      val map_field : 'a M1.w -> 'a M2.w
    end) =
struct
  let map : M1.t -> M2.t =
   fun M1.{preserved_cycles; hard_gas_limit_per_operation} ->
    {
      preserved_cycles = M.map_field preserved_cycles;
      hard_gas_limit_per_operation = M.map_field hard_gas_limit_per_operation;
    }
end

module Setter
    (M1 : S) (M : sig
      val def_field : 'a M1.w
    end) =
struct
  let def : M1.t =
    {preserved_cycles = M.def_field; hard_gas_limit_per_operation = M.def_field}
end

module Combiner
    (M1 : S)
    (M2 : S)
    (M3 : S) (M : sig
      val combine_field : 'a M1.w -> 'a M2.w -> 'a M3.w
    end) =
struct
  let combine : M1.t -> M2.t -> M3.t =
   fun a b ->
    {
      preserved_cycles = M.combine_field a.preserved_cycles b.preserved_cycles;
      hard_gas_limit_per_operation =
        M.combine_field
          a.hard_gas_limit_per_operation
          b.hard_gas_limit_per_operation;
    }
end

module Wrap_opt =
  Mapper (Required) (Optional)
    (struct
      let map_field x = Some x
    end)

module Set_none =
  Setter
    (Optional)
    (struct
      let def_field = None
    end)

module Combine_opt =
  Combiner (Required) (Optional) (Required)
    (struct
      let combine_field a b = Option.value ~default:a b
    end)

let to_optional = Wrap_opt.map

let optional_empty = Set_none.def

let override = Combine_opt.combine

include Required
