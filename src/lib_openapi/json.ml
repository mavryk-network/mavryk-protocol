(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2020 Nomadic Labs, <contact@nomadic-labs.com>               *)
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

(** Helpers to read JSON values.

    Contains functions to parse JSON values, show them for debugging, and
    extract information from them.

    Functions which extract information are rather strict: they don't try
    to be smart and automatically convert. For instance, [as_record] makes sure
    that all fields are taken into account. This is suited to write a tool that
    must be updated when the format of JSON values being manipulated changes.
    In our case, if the JSON schemas we read start to get more fields, we want
    to know; otherwise the resulting OpenAPI specification could be inaccurate. *)

(* String representations of JSON values, annotated with their origin.
   Used to store raw JSON in errors, for display purposes.
   Field [raw_origin] is the [~origin] argument of [parse],
   and field [raw_string] is the string representation. *)
type raw = {raw_origin : string; raw_string : string}

(* [raw] is only present for values that cannot be found easily elsewhere.

   [origin] is the string representation of the value of type [origin].
   It is more precise than [raw.raw_origin].

   [message] is the error message. *)
type error = {raw : raw option; origin : string; message : string}

exception Error of error

type u = Ezjsonm.value

(* Each [JSON.t] comes with its origin so that we can print nice error messages.

   - [Origin] denotes the original JSON value. Field [name] describes where it comes from,
     for instance ["RPC response"]. Field [json] is the full original JSON value.

   - [Field] denotes a field taken a JSON object.
     This JSON object itself originates from [origin], and the field name is [name].

   - [Item] denotes an item taken a JSON array.
     This JSON array itself originates from [origin], and the item index is [index].

   - [Error] denotes a field or an item taken from [origin] but which does not exist.
     The exact reason why it does not exist is [message]. *)
type origin =
  | Origin of {name : string; json : u}
  | Field of {origin : origin; name : string}
  | Item of {origin : origin; index : int}
  | Error of {origin : origin; message : string}

type t = {origin : origin; node : u}

let encode_u = Ezjsonm.value_to_string ~minify:false

let encode {node; _} = Ezjsonm.value_to_string ~minify:false node

let encode_to_file_u filename json =
  let ch = open_out filename in
  try
    Ezjsonm.value_to_channel ~minify:false ch json ;
    close_out ch
  with exn ->
    close_out ch ;
    raise exn

let encode_to_file filename json = encode_to_file_u filename json.node

let annotate ~origin node = {origin = Origin {name = origin; json = node}; node}

let unannotate {node; _} = node

let fail_string origin message =
  let rec gather_origin message fields = function
    | Origin {name; json} ->
        let origin =
          match fields with
          | [] -> name
          | _ :: _ -> name ^ ", at " ^ String.concat "" fields
        in
        raise
          (Error
             {
               raw = Some {raw_origin = name; raw_string = encode_u json};
               origin;
               message;
             })
    | Field {origin; name} ->
        gather_origin message (("." ^ name) :: fields) origin
    | Item {origin; index} ->
        gather_origin
          message
          (("[" ^ string_of_int index ^ "]") :: fields)
          origin
    | Error {origin; message} -> gather_origin message [] origin
  in
  gather_origin message [] origin

let fail origin x = Printf.ksprintf (fail_string origin) x

let error {origin; _} = fail origin

let null_because_error origin message =
  let origin =
    match origin with
    | Error _ -> origin
    | Origin _ | Field _ | Item _ -> Error {origin; message}
  in
  {origin; node = `Null}

let get name {origin; node} =
  match node with
  | `O fields -> (
      match List.assoc_opt name fields with
      | None -> null_because_error origin ("missing field: " ^ name)
      | Some node -> {origin = Field {origin; name}; node})
  | _ -> null_because_error origin "not an object"

let ( |-> ) json name = get name json

let geti index {origin; node} =
  match node with
  | `A items -> (
      match List.nth_opt items index with
      | None ->
          null_because_error origin ("missing item: " ^ string_of_int index)
      | Some node -> {origin = Item {origin; index}; node})
  | _ -> null_because_error origin "not an array"

let ( |=> ) json index = geti index json

let check as_opt error_message json =
  match as_opt json with
  | None -> fail json.origin error_message
  | Some value -> value

let test as_opt json = match as_opt json with None -> false | Some _ -> true

let is_null {node; _} = match node with `Null -> true | _ -> false

let as_opt json = match json.node with `Null -> None | _ -> Some json

let as_bool_opt json = match json.node with `Bool b -> Some b | _ -> None

let as_bool = check as_bool_opt "expected a boolean"

let is_bool = test as_bool_opt

let as_int_opt json =
  match json.node with
  | `Float f -> if Float.is_integer f then Some (Float.to_int f) else None
  | `String s -> int_of_string_opt s
  | _ -> None

let as_int = check as_int_opt "expected an integer"

let is_int = test as_int_opt

let as_int64_opt json =
  match json.node with
  | `Float f -> if Float.is_integer f then Some (Int64.of_float f) else None
  | `String s -> Int64.of_string_opt s
  | _ -> None

let as_int64 = check as_int64_opt "expected a 64-bit integer"

let is_int64 = test as_int64_opt

let as_int32_opt json =
  match json.node with
  | `Float f -> if Float.is_integer f then Some (Int32.of_float f) else None
  | `String s -> Int32.of_string_opt s
  | _ -> None

let as_int32 = check as_int32_opt "expected a 32-bit integer"

let is_int32 = test as_int32_opt

let as_float_opt json =
  match json.node with
  | `Float f -> Some f
  | `String s -> float_of_string_opt s
  | _ -> None

let as_float = check as_float_opt "expected a number"

let is_float = test as_float_opt

let as_string_opt json = match json.node with `String s -> Some s | _ -> None

let as_string = check as_string_opt "expected a string"

let is_string = test as_string_opt

let as_list_opt json =
  match json.node with
  | `Null -> Some []
  | `A l ->
      Some
        (List.mapi
           (fun index node ->
             {origin = Item {origin = json.origin; index}; node})
           l)
  | _ -> None

let as_list = check as_list_opt "expected an array"

let is_list = test as_list_opt

let as_object_opt json =
  match json.node with
  | `Null -> Some []
  | `O l ->
      Some
        (List.map
           (fun (name, node) ->
             (name, {origin = Field {origin = json.origin; name}; node}))
           l)
  | _ -> None

let as_object = check as_object_opt "expected an object"

let is_object = test as_object_opt

let as_variant json =
  match as_object json with
  | [(name, value)] -> (name, value)
  | _ -> error json "expected an object with a single field"

let as_variant_named json name =
  match as_variant json with
  | name', value when name' = name -> value
  | _ -> error json "expected a variant named %s" name

let ( |~> ) json name = as_variant_named json name

(* Convert an [`O] into a record.
   Ensure no field is left.
   [make] takes an argument to get field from their names,
   and if at the end it did not consume all fields,
   an exception is raised. *)
let as_record json make =
  let fields = ref (as_object json) in
  let get (field : string) =
    let rec find previous = function
      | [] -> None
      | ((head_name, head_value) as head) :: tail ->
          if head_name = field then (
            fields := List.rev_append previous tail ;
            Some head_value)
          else find (head :: previous) tail
    in
    find [] !fields
  in
  let result = make get in
  if !fields <> [] then
    error
      json
      "unexpected fields in object: %s"
      (String.concat ", " (List.map fst !fields)) ;
  result

let output json =
  Ezjsonm.value_to_channel ~minify:false stdout json ;
  print_newline ()
