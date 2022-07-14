module type S = sig
  type 'a w

  type t = {
    preserved_cycles : int w;
    hard_gas_limit_per_operation : Gas_limit_repr.Arith.integral w;
  }

  val encoding : t Data_encoding.t
end
