(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2023 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(*****************************************************************************)

let now () =
  let now = Ptime_clock.now () in
  let now = Ptime.to_rfc3339 now in
  Time.Protocol.of_notation_exn now

let with_timing event k =
  let open Lwt_syntax in
  let start = Time.System.now () in

  let* res = k () in

  let stop = Time.System.now () in
  let diff = Ptime.diff stop start in
  let* () = event diff in

  return res

let unwrap_error_monad f =
  let open Lwt_syntax in
  let* res = f () in
  match res with
  | Ok v -> return v
  | Error errs ->
      Lwt.fail_with (Format.asprintf "%a" Error_monad.pp_print_trace errs)
