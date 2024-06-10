(** The type of kernel's durable storage. *)
type t

exception Durable_empty

val empty : t

val of_tree : Mavryk_tree_encoding.wrapped_tree -> t

(** @raise Durable_empty *)
val to_tree_exn : t -> Mavryk_tree_encoding.wrapped_tree

val to_tree : t -> Mavryk_tree_encoding.wrapped_tree option
