module Optional : sig
  type t = {
    preserved_cycles : int option;
    hard_gas_limit_per_operation : Gas_limit_repr.Arith.integral option;
  }

  val encoding : t Data_encoding.t
end

type t = {
  preserved_cycles : int;
  hard_gas_limit_per_operation : Gas_limit_repr.Arith.integral;
}

val encoding : t Data_encoding.t
