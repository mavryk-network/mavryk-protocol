module type S = Simple_constants_repr_intf.S

module Optional : sig
  include S with type 'a w = 'a option
end

include S with type 'a w = 'a

val to_optional : t -> Optional.t

val optional_empty : Optional.t

val override : t -> Optional.t -> t
