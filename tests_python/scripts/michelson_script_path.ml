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

  [-a action=[find/all]]: defines the action. either [find] and
   version a single script or return [all] contracts vaild for the
   given protocol.

  [-a action=[find/all]]: defines the [action]. Either [find] and
   version a single script or return [all] contracts vaild for the
   given protocol.


  If [ACTION] is [find], then the argument [-a name=NAME] must be given
   where [NAME] is a '/'-separated logical script name
   (e.g. 'opcodes/swap').

  If [ACTION] is [all], then the argument [-a directories=NAME] must be supplied
   to delimit the search to a given number of sub-directories.

Examples:

$ dune exec ./tests_python/scripts/michelson_script_path.exe -- -a action=all -a directories=ill_typed -a protocol=014
ill_typed/badly_indented                 
ill_typed/big_map_arity
$ dune exec ./tests_python/scripts/michelson_script_path.exe -- -a action=find -a name=ill_typed/badly_indented -a protocol=014
michelson_test_scripts/ill_typed/badly_indented.tz

*)

open Tezt
open Tezt_tezos

let sf = Format.asprintf

type action = Find | All

let () =
  let cli_get_opt f name =
    Cli.get ~default:None (fun x -> Some (Some (f x))) name
  in
  let prefix = cli_get_opt Fun.id "prefix" in
  let action =
    match Cli.get_string "action" with
    | "find" -> Find
    | "all" -> All
    | _ -> raise (Invalid_argument (sf "Action must be 'find' or 'all'"))
  in
  let protocol =
    Cli.get
      ~default:Protocol.Alpha
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
  match action with
  | Find ->
      let name = String.split_on_char '/' @@ Cli.get_string "name" in
      print_endline
      @@ (Michelson_script.find ?prefix name protocol |> Michelson_script.path)
  | All ->
      let dirs =
        List.map
          (fun s -> [s])
          (String.split_on_char ',' (Cli.get_string "directories"))
      in
      List.iter
        print_endline
        (Michelson_script.all ?prefix ~dirs protocol
        |> List.map Michelson_script.name_s)
