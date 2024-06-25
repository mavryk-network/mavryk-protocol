(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

open Error_monad
open Lwt_result_syntax

(** [Sink] is an {!Internal_event.SINK} implementation logging through Tezt's {!Log}. *)
module Sink : Internal_event.SINK = struct
  type t = unit

  let uri_scheme = "tezt-log"

  let configure _ = return_unit

  let should_handle ?section:_ (_ : t) _m = true

  let handle (type a) (_ : t) m ?section ev =
    let module M = (val m : Internal_event.EVENT_DEFINITION with type t = a) in
    ignore section ;
    let level =
      match M.level with
      | Internal_event.Debug -> Cli.Logs.Debug
      | Internal_event.Info | Internal_event.Notice -> Cli.Logs.Info
      | Internal_event.Warning -> Cli.Logs.Warn
      | Internal_event.Fatal | Internal_event.Error -> Cli.Logs.Error
    in
    Log.log ~level "%a" (M.pp ~all_fields:true ~block:true) ev ;
    return_unit

  let close (_ : t) : unit tzresult Lwt.t = return_unit
end

let sink : Sink.t Internal_event.sink_definition =
  (module Sink : Internal_event.SINK with type t = Sink.t)

(** Activate the Tezt {!Sink} *)
let activate =
  let is_active = ref false in
  fun () ->
    if !is_active then Lwt.return_unit
    else (
      is_active := true ;
      Internal_event.All_sinks.register sink ;
      let*! r =
        Internal_event.All_sinks.activate
          (Uri.of_string (Sink.uri_scheme ^ "://"))
      in
      match r with
      | Ok () -> Lwt.return_unit
      | Error errors ->
          Test.fail
            "Could not initialize Tezt sink:\n   %a\n"
            pp_print_trace
            errors)
