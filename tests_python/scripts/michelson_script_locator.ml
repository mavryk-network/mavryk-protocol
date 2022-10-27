(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs <contact@nomadic-labs.com>                *)
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

(*

This script implements a wrapper around [Tezt_tezos.Michelson_script].

Usage:

  [dune exec ./tests_python/scripts/michelson_script_path.exe --
   [args]]

where args can be:

  [-a prefix=PREFIX]: the directory in which to search for Michelson
   scripts (mandatory)


  [-a protocol=NNN]: return scripts for this protocol version
   (mandatory)

  [-a action=[find/find_all/find_all_legacy]]: defines the
  action. either [find] and version a single script, [find_all] that
  returns all contracts valid for the given protocol (optionally
  delimited by [-a directories=DIRS]) or [find_all_legacy].


  If [ACTION] is [find], then the argument [-a name=NAME] must be given
   where [NAME] is a '/'-separated logical script name
   (e.g. 'opcodes/swap').

Examples:

$ dune exec ./tests_python/scripts/michelson_script_path.exe -- -a action=find_all -a directories=macros -a protocol=014
macros/assert.tz
...
$ dune exec ./tests_python/scripts/michelson_script_path.exe -- -a action=find -a name=ill_typed/badly_indented -a protocol=014
michelson_test_scripts/ill_typed/badly_indented.tz

*)

open Tezt
open Tezt_tezos

let sf = Format.asprintf

type action = Find | Find_all | Find_all_well_typed | Find_all_legacy

let () =
  let cli_get_opt f name =
    Cli.get ~default:None (fun x -> Some (Some (f x))) name
  in
  let prefix = cli_get_opt Fun.id "prefix" in
  let action =
    match Cli.get_string "action" with
    | "find_all" -> Find_all
    | "find_all_legacy" -> Find_all_legacy
    | "find_all_well_typed" -> Find_all_well_typed
    | "find" -> Find
    | _ -> raise (Invalid_argument (sf "Action must be 'find' or 'all'"))
  in
  let protocol =
    Cli.get
      (fun i ->
        let i = int_of_string i in
        match List.find_opt (fun p -> Protocol.number p = i) Protocol.all with
        | Some p -> Some p
        | None ->
            let protocol_nums =
              Protocol.all
              |> List.map (fun p -> p |> Protocol.number |> string_of_int)
              |> String.concat ","
            in
            raise
              (Invalid_argument
                 (sf "No protocol %d, choose between %s" i protocol_nums)))
      "protocol"
  in
  let print_all_script_names scripts =
    List.iter print_endline (scripts |> List.map Michelson_script.name_s)
  in
  match action with
  | Find ->
      let name = String.split_on_char '/' @@ Cli.get_string "name" in
      print_endline
      @@ (Michelson_script.find ?prefix name protocol |> Michelson_script.path)
  | Find_all ->
      let directory_filter =
        Cli.get
          ~default:Fun.id
          (fun directories ->
            let directories = String.split_on_char ',' directories in
            Some
              (fun scripts ->
                List.filter_map
                  (fun (script : Michelson_script.t) ->
                    match script.dirname with
                    | top_directory :: _p
                      when List.mem top_directory directories ->
                        Some script
                    | _ -> None)
                  scripts))
          "directories"
      in
      Michelson_script.find_all ?prefix protocol
      |> directory_filter |> print_all_script_names
  | Find_all_well_typed ->
      Michelson_script.find_all_well_typed ?prefix protocol
      |> print_all_script_names
  | Find_all_legacy ->
      Michelson_script.find_all_legacy ?prefix protocol
      |> print_all_script_names
