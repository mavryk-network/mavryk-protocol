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

let default_prefix = "michelson_test_scripts"

type version_range = {range_start : int; range_end : int option}

let in_range {range_start; range_end} protocol =
  let n = Protocol.number protocol in
  let range_end = Option.value range_end ~default:Int.max_int in
  range_start <= n && n <= range_end

(**
  Represents a contract on the filesystem. Documentation for each field:
  - [prefix]
    This is the path to the contracts directory, for instance: [michelson_scripts].
  - [dirname]
    This is the relative path under [prefix] that leads you to the actual contract.
  - [basename]
    This is the name of the file in which the contract is stored. E.g: [foobar_001.tz].
  - [name]
    This is the logical name of the contract. E.g: if basename = foobar_001.tz then name = foobar.
  - [version]
    If the basename contains a version suffix [foobar_NNN.tz], then this value is Some NNN.
*)
type t = {
  prefix : string;
  dirname : string list;
  basename : string;
  name : string;
  version_range : version_range;
  depth : int;
}

let really_compare f fs =
  let rec loop cmp = function
    | [] -> cmp
    | f :: fs -> if cmp = 0 then loop (f ()) fs else cmp
  in
  loop (f ()) fs

let compare_version_range {range_start; range_end} t2 =
  let f () = Int.compare range_start t2.range_start in
  let fs = [(fun () -> Option.compare Int.compare range_end t2.range_end)] in
  really_compare f fs

let compare {prefix; dirname; basename; name; version_range; depth} t2 =
  let f () = String.compare prefix t2.prefix in
  let fs =
    [
      (fun () -> List.compare String.compare dirname t2.dirname);
      (fun () -> String.compare basename t2.basename);
      (fun () -> String.compare name t2.name);
      (fun () -> compare_version_range version_range t2.version_range);
      (fun () -> Int.compare depth t2.depth);
    ]
  in
  really_compare f fs

let parse_basename : string -> (string * version_range) option =
  let re3 = rex "(.*)_([0-9]{3,})_([0-9]{3,})\\.tz" in
  let re2 = rex "(.*)_([0-9]{3,})\\.tz" in
  let re1 = rex "(.*).tz" in
  fun s ->
    match s =~*** re3 with
    | Some (name, range_start, range_end) ->
        let version_range =
          {
            range_start = int_of_string range_start;
            range_end = Some (int_of_string range_end);
          }
        in
        Some (name, version_range)
    | None -> (
        match s =~** re2 with
        | Some (name, range_start) ->
            let version_range =
              {range_start = int_of_string range_start; range_end = None}
            in
            Some (name, version_range)
        | None -> (
            match s =~* re1 with
            | Some name ->
                let version_range = {range_start = 0; range_end = None} in
                Some (name, version_range)
            | None -> None))

let find_all ?(prefix = default_prefix) () =
  let maxdepth = Int.max_int in
  let dirname = [] in
  lazy
    (let rec walk depth dirname =
       if depth >= maxdepth then []
       else
         List.fold_left ( // ) prefix dirname
         |> Sys.readdir |> Array.to_list
         |> List.concat_map (fun basename ->
                let dirname' = dirname @ [basename] in
                let dirname_s' = List.fold_left ( // ) prefix dirname' in
                if Sys.is_directory dirname_s' then walk (depth + 1) dirname'
                else
                  parse_basename basename
                  |> Option.map (fun (name, version_range) ->
                         {prefix; dirname; basename; name; version_range; depth})
                  |> Option.to_list)
     in
     walk 1 dirname |> List.sort compare)

let find ?(prefix = default_prefix) name protocol =
  let expected_dirname, expected_name =
    match List.rev name with
    | [] -> Test.fail "name must not be an empty list"
    | name :: dirname_rev -> (List.rev dirname_rev, name)
  in
  let expected_dirname_s = String.concat Filename.dir_sep expected_dirname in
  let expected_version = Protocol.number protocol in
  match
    Lazy.force (find_all ~prefix ())
    |> List.filter (fun t ->
           t.dirname = expected_dirname
           && t.name = expected_name
           && protocol |> in_range t.version_range)
    |> List.rev
  with
  | t :: _ -> t
  | [] ->
      Test.fail
        "could not find contract %S for protocol %03d in %s: found no file \
         named %s_NNN.tz such that 000 <= NNN <= %03d; found no unversioned \
         file named %s.tz"
        (expected_dirname_s // expected_name)
        expected_version
        prefix
        expected_name
        expected_version
        expected_name

let path t = t.prefix // String.concat Filename.dir_sep t.dirname // t.basename

let name t = t.dirname @ [t.name]

let name_s t = name t |> String.concat "/"

let all ?(prefix = default_prefix) ?(dirs = [[]]) ?(maxdepth = Int.max_int)
    protocol =
  let dirs = match dirs with [] -> [[]] | _ -> dirs in
  Lazy.force (find_all ~prefix ())
  |> List.filter (fun t ->
         prefix = t.prefix
         && List.exists (fun dir -> List.equal String.equal dir t.dirname) dirs
         && t.depth < maxdepth)
  |> List.fold_left
       (fun map t ->
         let key = String.concat Filename.dir_sep t.dirname // t.name in
         map
         |> String_map.update key (function
                | None -> Some [t]
                | Some data -> Some (t :: data)))
       String_map.empty
  |> String_map.filter_map (fun _key ts ->
         ts
         |> List.sort (fun t1 t2 -> -1 * compare t1 t2)
         |> List.find_opt (fun t -> protocol |> in_range t.version_range))
  |> String_map.bindings |> List.map snd

let pretty_string {prefix; dirname; basename; name; version_range; depth} =
  let option_to_string f opt =
    match opt |> Option.map f with None -> "None" | Some s -> "Some " ^ s
  in
  String.concat
    "\n"
    [
      "{";
      "  prefix = " ^ prefix;
      "  dirname = " ^ String.concat Filename.dir_sep dirname;
      "  basename = " ^ basename;
      "  name = " ^ name;
      "  version_range = ";
      "  {";
      "    range_start = " ^ string_of_int version_range.range_start;
      "    range_end = "
      ^ option_to_string string_of_int version_range.range_end;
      "  }";
      "  depth = " ^ string_of_int depth;
      "}";
    ]

let all_legacy protocol = all ~dirs:[["legacy"]] protocol
