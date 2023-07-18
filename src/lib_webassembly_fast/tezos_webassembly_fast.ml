type engine

type modul

external engine_new : unit -> engine = "engine_new"

external module_new : engine -> string -> modul option * string option
  = "module_new"
