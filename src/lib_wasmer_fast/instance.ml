(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 TriliTech <contact@trili.tech>                         *)
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

(* For documentation please refer to the [Tezos_wasmer] module. *)

open Api
open Utils

module Resolver = Map.Make (struct
  type t = string * string * Unsigned.uint64

  let compare (l1, l2, l3) (r1, r2, r3) =
    match
      (String.compare l1 r1, String.compare l2 r2, Unsigned.UInt64.compare l3 r3)
    with
    | 0, 0, r -> r
    | 0, r, _ -> r
    | r, _, _ -> r
end)

type t = {
  module_ : Module.t;
  instance : Types.Instance.t Ctypes.ptr;
  clean : unit -> unit;
}

exception
  Unsatisfied_import of {
    module_ : string;
    name : string;
    kind : Unsigned.uint64;
  }

let resolve_imports store modul resolver =
  let cleaners = ref [] in
  let imports = Functions.Imports.new_ () in
  let lookup import =
    let module_ = Functions.ImportType.module_ import in
    let module_str = Functions.String.contents module_ in
    let name = Functions.ImportType.name import in
    let name_str = Functions.String.contents name in
    let kind = Functions.ImportType.kind import in
    let match_ = Resolver.find_opt (module_str, name_str, kind) resolver in
    let item, clean =
      match match_ with
      | None ->
          raise
            (Unsatisfied_import {module_ = module_str; name = name_str; kind})
      | Some m -> Extern.to_extern store m
    in
    Functions.Imports.define imports module_ name item ;
    cleaners := clean :: !cleaners
  in
  Module.imports modul |> Ctypes.CArray.iter lookup ;
  let clean () = List.iter (fun f -> f ()) !cleaners in
  (imports, Fun.id, clean)

let create store module_ externs =
  let open Lwt.Syntax in
  let imports, clean_after_instantiation, clean =
    externs
    |> List.map (fun (module_, name, extern) ->
           ((module_, name, Extern.kind extern), extern))
    |> List.to_seq |> Resolver.of_seq
    |> resolve_imports store module_
  in

  let instantiate () =
    Lwt_preemptive.detach
      (fun (store, module_, imports) ->
        Functions.Instance.new_ store module_ imports)
      (store, module_, imports)
  in

  let+ instance =
    Lwt.finalize instantiate (fun () ->
        (* At this point we can clean up some objects because the instantiation has
           acquired its own handles to relevant objects. *)
        clean_after_instantiation () ;
        Lwt.return_unit)
  in

  check_null_ptr Error.(make_exception Instantiate_module) instance ;

  {module_; instance; clean}

let delete inst =
  Functions.Instance.delete inst.instance ;
  inst.clean ()
