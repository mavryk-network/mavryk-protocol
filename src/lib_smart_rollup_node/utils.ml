(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2023 Functori, <contact@functori.com>                       *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

module Reveal_hash_map = Map.Make (struct
  type t = Dac_plugin.hash

  let compare = Dac_plugin.raw_compare
end)

let lock ?(when_locked = `Block) lockfile_path =
  let open Lwt_result_syntax in
  let* lockfile =
    protect @@ fun () ->
    Lwt_unix.openfile
      lockfile_path
      [Unix.O_CREAT; O_RDWR; O_CLOEXEC; O_SYNC]
      0o644
    |> Lwt_result.ok
  in
  let* () =
    trace (Rollup_node_errors.Could_not_acquire_lock lockfile_path)
    @@ protect ~on_error:(fun err ->
           let*! () = Lwt_unix.close lockfile in
           fail err)
    @@ fun () ->
    let command =
      match when_locked with `Block -> Unix.F_LOCK | `Fail -> Unix.F_TLOCK
    in
    let*! () = Lwt_unix.lockf lockfile command 0 in
    return_unit
  in
  return lockfile

let unlock lockfile =
  Lwt.finalize
    (fun () -> Lwt_unix.lockf lockfile Unix.F_ULOCK 0)
    (fun () -> Lwt_unix.close lockfile)

let with_lockfile ?when_locked lockfile_path f =
  let open Lwt_result_syntax in
  let* lockfile = lock ?when_locked lockfile_path in
  Lwt.finalize f (fun () -> unlock lockfile)
