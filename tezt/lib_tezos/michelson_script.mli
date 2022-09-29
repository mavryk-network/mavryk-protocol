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

(** Represents a contract on the filesystem. *)
type t

(** This is the directory that will be used as the "root", otherwise known as
    the "prefix", where michelson scripts will be searched for. *)
val default_prefix : string

(** Find a Michelson script file.

    Usage: [find name protocol]

    This returns [michelson_scripts/NAME_MMM_NNN.tz] for the highest [MMM] and [NNN]
    such that [MMM <= Protocol.number protocol <= NNN] and such that this file exists.
    If no such file exists but [michelson_scripts/NAME.tz] does, this
    returns [michelson_scripts/NAME.tz]. Else, this fails.

    The intent is that:
    - new contracts are added without a [_MMM] suffix;
    - if a contract needs to be adapted for a new protocol, the file is
      duplicated and the new version is suffixed with [_MMM];
    - if a contract is no longer needed for future protocols, it can be
      disabled by attaching [_NNN] such that NNN is the last protocol
      which it is valid for.

    [name] is a list of path items where all but the last one are subdirectories
    and the last one is the base filename without [_NNN.tz].

    For instance, assume the following files exist:
    - [michelson_scripts/foo/bar/baz.tz]
    - [michelson_scripts/foo/bar/baz_015.tz]
    Then [path ["foo"; "bar"; "baz"] Lima] returns:
    [michelson_scripts/foo/bar/baz_015.tz]
    while [path ["foo"; "bar"; "baz"] Kathmandu] returns:
    [michelson_scripts/foo/bar/baz.tz]. *)
val find : ?prefix:string -> string list -> Protocol.t -> t

(** [all ?dirs ?maxdepth protocol] returns all contracts for a given protocol
    within [dirs] up to a maxdepth [maxdepth]. Setting [~maxdepth:1] is useful
    when you don't want to recurse into subdirectories. When [?dirs] is [None],
    returns all contracts. When [?dirs] is [Some dirs'], returns all contracts
    inside of the [dirs'] that match [protocol].
    
    For instance, assume the following files exist:
    - [michelson_scripts/a.tz]
    - [michelson_scripts/a_015.tz]
    - [michelson_scripts/a_016.tz]
    - [michelson_scripts/b/c.tz]
    - [michelson_scripts/b/c_015.tz]
    - [michelson_scripts/b/c_016.tz]
    - [michelson_scripts/d/e/f.tz]
    - [michelson_scripts/d/e/f_016.tz]

    And assume [p] is a [Protocol.t] such that [Protocol.number p = 015].

    Then [all ~dirs:[[]; ["d"; "e"]] p] returns:
    - [michelson_scripts/a_015.tz]
    - [michelson_scripts/d/e/f.tz]
    
    And [all p] returns:
    - [michelson_scripts/a_015.tz]
    - [michelson_scripts/b/c_015.tz]
    - [michelson_scripts/d/e/f.tz]
    *)
val all :
  ?prefix:string ->
  ?dirs:string list list ->
  ?maxdepth:int ->
  Protocol.t ->
  t list

(** Same as [all ~dirs:["legacy"] p]. *)
val all_legacy : Protocol.t -> t list

(** The path to the contract relative to [/] (the repo root). *)
val path : t -> string

(** The logical name of the contract. *)
val name : t -> string list

(** The logical name as a string. This is [name t |> String.concat "/"]. *)
val name_s : t -> string

(** Pretty printer for [t]. This is mostly useful for debugging. Perhaps you
    were looking for [path] instead. *)
val pretty_string : t -> string
