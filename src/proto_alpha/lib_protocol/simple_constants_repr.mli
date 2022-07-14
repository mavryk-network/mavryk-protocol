module type S = Simple_constants_repr_intf.S

module Optional : S with type 'a w = 'a option

include S with type 'a w = 'a
