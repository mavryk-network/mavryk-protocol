(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
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

(** The OCaml compiler not being implemented with Lwt, the compilation
    take place in a separated process (by using [Lwt_process.exec]).

    The [main] function is the entry point for the forked process.
    While [Updater.compile] is the 'forking' function to be called by
    the [mavkit-node] process.

*)

open Compiler

(* TODO: fail in the presence of "external" *)

module Backend = struct
  (* See backend_intf.mli. *)

  let symbol_for_global' = Compilenv.symbol_for_global'

  let closure_symbol = Compilenv.closure_symbol

  let really_import_approx = Import_approx.really_import_approx

  let import_symbol = Import_approx.import_symbol

  let size_int = Arch.size_int

  let big_endian = Arch.big_endian

  let max_sensible_number_of_arguments =
    (* The "-1" is to allow for a potential closure environment parameter. *)
    Proc.max_arguments_for_tailcalls - 1
end

let backend = (module Backend : Backend_intf.S)

(** Semi-generic compilation functions *)

let pack_objects output objects =
  let output = output ^ ".cmx" in
  Compmisc.init_path () ;
  Asmpackager.package_files
    ~backend
    ~ppf_dump:Format.err_formatter
    Protocol_compiler_env.env
    objects
    output ;
  Warnings.check_fatal () ;
  output

let link_shared output objects =
  Compenv.(readenv Format.err_formatter Before_link) ;
  Compmisc.init_path () ;
  Asmlink.link_shared ~ppf_dump:Format.err_formatter objects output ;
  Warnings.check_fatal ()

let compile_ml ?for_pack source_file =
  let output_prefix = Filename.chop_extension source_file in
  Clflags.for_package := for_pack ;
  Compenv.(readenv Format.err_formatter (Before_compile source_file)) ;
  Optcompile.implementation
    ~backend
    ~source_file
    ~output_prefix
    ~start_from:Clflags.Compiler_pass.Parsing ;
  Clflags.for_package := None ;
  output_prefix ^ ".cmx"

let () = Clflags.native_code := true

let driver = {compile_ml; link_shared; pack_objects}
