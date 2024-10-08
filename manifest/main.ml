(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 Trili Tech <contact@trili.tech>                   *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
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

open Manifest
module Externals = Externals
open Externals
module Internals = Internals
module Mavkit = Product_mavkit
open Mavkit
module Client_libs = Product_client_libs
module Tooling = Product_tooling
module Etherlink = Product_etherlink
module CIAO = Product_ciao

(* Add entries to this function to declare that some dune and .opam files are
   not generated by the manifest on purpose.

   - DO NOT add packages to this list without a good reason.
   - DO NOT add released packages to this list even with a good reason.
     Instead, you need a VERY good reason, because those packages prevent
     automatic opam releases.
   - ALWAYS add a comment to explain why a package is excluded. *)
let exclude filename =
  let is_proto_ name = String.starts_with ~prefix:"proto_" name in
  match String.split_on_char '/' filename with
  (* Dune files in src/proto_*/parameters only have a (copy_files) stanza
     (no library / executable / test). *)
  | "src" :: maybe_proto :: "parameters" :: _ when is_proto_ maybe_proto -> true
  (* This dune file does not contain any targets, only a dirs stanza. *)
  | ["src"; maybe_proto; "lib_protocol"; "test"; "regression"; "tezt"; "dune"]
    when is_proto_ maybe_proto ->
      true
  (* The following directory has a very specific structure that would be hard
     to port to the manifest. Also, it is not released, and is not a dependency
     for releases as it is an opt-in instrumentation. *)
  | "src" :: "lib_time_measurement" :: _ -> true
  (* The following file only defines aliases (no library / executable / test). *)
  | ["src"; "lib_protocol_compiler"; "test"; "dune"] -> true
  (* We don't generate the toplevel dune file. *)
  | ["dune"] -> true
  (* The following directories do not contain packages that we release on opam. *)
  | "vendors" :: _ -> true
  | "scripts" :: _ -> true
  (* opam/mandatory-for-make.opam is a trick to have [make build-deps]
     install some optional dependencies in a mandatory way.
     Once we use lock files, we can remove this, probably. *)
  | ["opam"; "mandatory-for-make.opam"] -> true
  (* opam-repository is used by scripts/opam-release.sh *)
  | "opam-repository" :: _ -> true
  (* data-encoding is imported as data-only for now *)
  | "data-encoding" :: _ -> true
  | _ -> false

let () =
  (* [make_tezt_exe] makes the global executable that contains all tests.
     [generate] gives it the list of libraries that register Tezt tests
     so that it can link all of them. *)
  let module GlobalTezt = Internals.Product (struct
    let name = "tezt-tests"
  end) in
  let tezt_exe_deps =
    [
      mavkit_test_helpers |> open_;
      tezt_wrapper |> open_ |> open_ ~m:"Base";
      str;
      mavryk_bls12_381;
      tezt_mavryk |> open_ |> open_ ~m:"Runnable.Syntax";
      Mavkit.tezt_risc_v_sandbox;
      tezt_tx_kernel;
      data_encoding;
      mavkit_base;
      mavkit_base_unix;
      mavkit_stdlib_unix;
      Protocol.(main alpha);
    ]
  in
  let make_tezt_exe test_libs =
    GlobalTezt.test
      "main"
      ~with_macos_security_framework:true
      ~alias:""
      ~path:"tezt/tests"
        (* Instrument with sigterm handler, to ensure that coverage from
           Tezt worker processes are collected. *)
      ~bisect_ppx:With_sigterm
      ~opam:""
      ~deps:(tezt_exe_deps @ test_libs)
  in
  generate
    ~make_tezt_exe
    ~tezt_exe_deps
    ~default_profile:"mavkit-deps"
    ~add_to_meta_package:
      [
        (* [ledgerwallet_tezos] is an optional dependency, but we want
           [opam install mavkit] to always install it. *)
        ledgerwallet_tezos;
      ]

(* Generate a dune-workspace file at the root of the repo *)
let () =
  let p_dev = Env.Profile "dev" in
  let p_static = Env.Profile "static" in
  let p_release = Env.Profile "release" in
  let warnings_for_dev =
    (* We mark all warnings as error and disable the few ones we don't want *)
    (* The last warning number 72 should be revisited when we move from OCaml.4.14 *)
    "@1..72" ^ Flags.disabled_warnings_to_string warnings_disabled_by_default
  in
  let env =
    Env.empty
    |> Env.add p_static ~key:"ocamlopt_flags" Dune.[S ":standard"; S "-O3"]
    |> Env.add p_release ~key:"ocamlopt_flags" Dune.[S ":standard"; S "-O3"]
    |> Env.add
         p_dev
         ~key:"flags"
         Dune.[S ":standard"; S "-w"; S warnings_for_dev]
    |> Env.add
         Env.Any
         ~key:"js_of_ocaml"
         Dune.[S "runtest_alias"; S "runtest_js"]
  in
  let dune =
    Dune.
      [
        [
          S "context";
          [S "default"; [S "paths"; [S "ORIGINAL_PATH"; S ":standard"]]];
        ];
      ]
  in
  generate_workspace env dune

(* Generate active_protocol_versions. *)
let () =
  let write_protocol fmt protocol =
    match Protocol.number protocol with
    | Alpha | V _ -> Format.fprintf fmt "%s\n" (Protocol.name_dash protocol)
    | Other -> ()
  in
  write "script-inputs/active_protocol_versions" @@ fun fmt ->
  List.iter (write_protocol fmt) Protocol.active

(* Generate active_protocol_versions_without_number. *)
let () =
  let write_protocol fmt protocol =
    match Protocol.number protocol with
    | Alpha | V _ -> Format.fprintf fmt "%s\n" (Protocol.short_hash protocol)
    | Other -> ()
  in
  write "script-inputs/active_protocol_versions_without_number" @@ fun fmt ->
  List.iter (write_protocol fmt) Protocol.active

(* Generate documentation index for [mavkit-libs] *)
let () =
  write "src/lib_base/index.mld" @@ fun fmt ->
  let header =
    "{0 Mavkit-libs: Mavkit libraries}\n\n\
     This is a package containing some libraries used by the Mavkit project.\n\n\
     It contains the following libraries:\n\n"
  in
  Sub_lib.pp_documentation_of_container ~header fmt registered_mavkit_libs

(* Generate documentation index for [mavkit-shell-libs] *)
let () =
  write "src/lib_shell/index.mld" @@ fun fmt ->
  let header =
    "{0 Mavkit-shell-libs: mavkit shell libraries}\n\n\
     This is a package containing some libraries used by the shell of Mavkit.\n\n\
     It contains the following libraries:\n\n"
  in
  Sub_lib.pp_documentation_of_container ~header fmt registered_mavkit_shell_libs

(* Generate documentation index for [mavkit-proto-libs] *)
let () =
  write "src/lib_protocol_environment/index.mld" @@ fun fmt ->
  let header =
    "{0 Mavkit-proto-libs: mavkit protocol libraries}\n\n\
     This is a package containing some libraries related to the Mavryk \
     protocol.\n\n\
     It contains the following libraries:\n\n"
  in
  Sub_lib.pp_documentation_of_container ~header fmt registered_mavkit_proto_libs

(* Generate documentation index for [mavkit-l2-libs] *)
let () =
  write "src/lib_smart_rollup/index.mld" @@ fun fmt ->
  let header =
    "{0 Mavkit-l2-libs: mavkit layer2 libraries}\n\n\
     This is a package containing some libraries used by the layer 2 of \
     Mavkit.\n\n\
     It contains the following libraries:\n\n"
  in
  Sub_lib.pp_documentation_of_container ~header fmt registered_mavkit_l2_libs

(* Generate documentation index for [mavkit-evm-node-libs] *)
let () =
  write "etherlink/bin_node/index.mld" @@ fun fmt ->
  let header =
    "{0 Mavkit-evm-node-libs: mavkit EVM Node libraries}\n\n\
     This is a package containing some libraries used by the EVM Node of \
     Mavkit.\n\n\
     It contains the following libraries:\n\n"
  in
  Sub_lib.pp_documentation_of_container
    ~header
    fmt
    Etherlink.registered_mavkit_evm_node_libs

let () = postcheck ~exclude ()
