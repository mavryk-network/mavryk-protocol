(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2003-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2024 TriliTech <contact@trili.tech>                   *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*                                                                           *)
(*****************************************************************************)

open Manifest
open Externals
open Internals

include Product (struct
  let name = "mavkit"
end)

module String_set = Set.Make (String)

let final_protocol_versions =
  let path = "src/lib_protocol_compiler/final_protocol_versions" in
  let ic = open_in path in
  let rec loop acc =
    try
      let s = input_line ic in
      let acc' = if String.equal s "" then acc else String_set.add s acc in
      loop acc'
    with End_of_file ->
      close_in ic ;
      acc
  in
  loop String_set.empty

(* Fork of https://github.com/essdotteedot/distributed, used for plonk.
   uwt has been removed. The directories examples and tests have been dropped.
*)
let distributed_internal =
  public_lib
    "mavkit-distributed-internal"
    ~internal_name:"distributed"
    ~path:"src/lib_distributed_internal/src"
    ~synopsis:"Fork of distributed. Use for Mavkit only"
    ~deps:[unix]

let distributed_internal_lwt =
  public_lib
    "mavkit-distributed-lwt-internal"
    ~internal_name:"distributed_lwt"
    ~path:"src/lib_distributed_internal/lwt"
    ~synopsis:"Fork of distributed-lwt. Use for Mavkit only"
    ~deps:[unix; distributed_internal; lwt; lwt_unix; logs_lwt]

(* The main module [Mavkit_alcotest] is [open_] so that one can replace
   the [alcotest] dependency with [alcotezt] and it just works.
   If we use [~internal_name:"alcotest"] here, it would also work,
   except in cases where the real Alcotest is also a dependency. *)
let alcotezt =
  public_lib
    "mavkit-alcotezt"
    ~path:"tezt/lib_alcotezt"
      (* TODO: https://gitlab.com/tezos/tezos/-/issues/4727

         we mark "mavkit-alcotezt" as released but the real solution is to
         modify the manifest to add build instructions for dune to be
         used `with-test` *)
    ~release_status:Released
    ~synopsis:
      "Provide the interface of Alcotest for Mavkit, but with Tezt as backend"
    ~js_compatible:true
    ~deps:[tezt_core_lib]
  |> open_

(* Container of the registered sublibraries of [mavkit-libs] *)
let registered_mavkit_libs = Sub_lib.make_container ()

(* Container of the registered sublibraries of [mavkit-shell-libs] *)
let registered_mavkit_shell_libs = Sub_lib.make_container ()

(* Container of the registered sublibraries of [mavkit-proto-libs] *)
let registered_mavkit_proto_libs = Sub_lib.make_container ()

(* Container of the registered sublibraries of [mavkit-l2-libs] *)
let registered_mavkit_l2_libs = Sub_lib.make_container ()

(* Container of the registered sublibraries of [mavkit-internal-libs] *)
let mavkit_internal_libs = Sub_lib.make_container ()

(* Registers a sub-library in [mavkit-libs] packages.
   This package should contain all Mavkit basic libraries. *)
let mavkit_lib =
  Sub_lib.sub_lib
    ~package_synopsis:
      "A package that contains multiple base libraries used by the Mavkit suite"
    ~container:registered_mavkit_libs
    ~package:"mavkit-libs"

(* Registers a sub-library in the [mavkit-shell-libs] package.
   This package should contain all the libraries related to the shell. *)
let mavkit_shell_lib =
  Sub_lib.sub_lib
    ~package_synopsis:"Mavkit shell libraries"
    ~container:registered_mavkit_shell_libs
    ~package:"mavkit-shell-libs"

(* Registers a sub-library in the [mavkit-proto-libs] package.
   This package should contain all the libraries related to the protocol. *)
let mavkit_proto_lib =
  Sub_lib.sub_lib
    ~package_synopsis:"Mavkit protocol libraries"
    ~container:registered_mavkit_proto_libs
    ~package:"mavkit-proto-libs"

(* Registers a sub-library in the [mavkit-l2-libs] package.
   This package should contain all the libraries related to layer 2. *)
let mavkit_l2_lib =
  Sub_lib.sub_lib
    ~package_synopsis:"Mavkit layer2 libraries"
    ~container:registered_mavkit_l2_libs
    ~package:"mavkit-l2-libs"

(* Registers a sub-library in the [mavkit-internal-libs] package.

   This package should contain Mavkit dependencies that are under the
   ISC license (as of December 2023, these are exactly the Irmin
   packages). *)
let mavkit_internal_lib =
  Sub_lib.sub_lib
    ~package_synopsis:
      "A package that contains some libraries used by the Mavkit suite"
    ~container:mavkit_internal_libs
    ~package:"mavkit-internal-libs"
    ~license:"ISC"
    ~extra_authors:["Thomas Gazagnaire"; "Thomas Leonard"; "Craig Ferguson"]

let tezt_wrapper =
  mavkit_lib "tezt-wrapper" ~path:"tezt/lib_wrapper" ~deps:[tezt_lib]

let mavkit_test_helpers =
  mavkit_lib
    "test-helpers"
    ~path:"src/lib_test"
    ~internal_name:"mavryk_test_helpers"
    ~deps:[uri; fmt; qcheck_alcotest; lwt; pure_splitmix; data_encoding]
    ~js_compatible:true
    ~linkall:true
    ~release_status:Released
    ~dune:
      Dune.
        [
          (* This rule is necessary for `make lint-tests-pkg`, without it dune
             complains that the alias is empty. *)
          alias_rule "runtest_js" ~action:(S "progn");
        ]

let mavkit_expect_helper =
  mavkit_lib
    "expect-helper"
    ~internal_name:"mavryk_expect_helper"
    ~path:"src/lib_expect_helper"

let _mavkit_expect_helper_test =
  private_lib
    "mavryk_expect_helper_test"
    ~opam:"mavkit-libs"
    ~path:"src/lib_expect_helper/test"
    ~deps:[mavkit_expect_helper]
    ~inline_tests:ppx_expect

let mavkit_stdlib =
  mavkit_lib
    "stdlib"
    ~internal_name:"mavryk_stdlib"
    ~path:"src/lib_stdlib"
    ~synopsis:"Yet-another local-extension of the OCaml standard library"
    ~deps:[hex; zarith; zarith_stubs_js; lwt; aches]
    ~js_compatible:true
    ~js_of_ocaml:
      [[S "javascript_files"; G (Dune.of_atom_list ["tzBytes_js.js"])]]
    ~inline_tests:ppx_expect
    ~foreign_stubs:{language = C; flags = []; names = ["tzBytes_c"]}

let _mavkit_stdlib_tests =
  tezt
    [
      "test_bits";
      "test_tzList";
      "test_bounded_heap";
      "test_tzString";
      "test_fallbackArray";
      "test_functionalArray";
      "test_hash_queue";
      "test_tzBytes";
      "test_arrays";
    ]
    ~path:"src/lib_stdlib/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-libs"
    ~modes:[Native; JS]
    ~deps:
      [
        mavkit_stdlib |> open_;
        alcotezt;
        bigstring;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
      ]
    ~js_compatible:true

let _mavkit_stdlib_test_unix =
  tezt
    [
      "test_lwt_pipe";
      "test_circular_buffer";
      "test_circular_buffer_fuzzy";
      "test_hash_queue_lwt";
      "test_lwt_utils";
    ]
    ~path:"src/lib_stdlib/test-unix"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_stdlib |> open_;
        alcotezt;
        bigstring;
        lwt_unix;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
      ]

let mavkit_lwt_result_stdlib_bare_functor_outputs =
  mavkit_lib
    "lwt-result-stdlib.bare.functor-outputs"
    ~path:"src/lib_lwt_result_stdlib/bare/functor_outputs"
    ~internal_name:"bare_functor_outputs"
    ~js_compatible:true
    ~deps:[lwt]

let mavkit_lwt_result_stdlib_bare_sigs =
  mavkit_lib
    "lwt-result-stdlib.bare.sigs"
    ~path:"src/lib_lwt_result_stdlib/bare/sigs"
    ~internal_name:"bare_sigs"
    ~js_compatible:true
    ~deps:[seqes; lwt; mavkit_lwt_result_stdlib_bare_functor_outputs]

let mavkit_lwt_result_stdlib_bare_structs =
  mavkit_lib
    "lwt-result-stdlib.bare.structs"
    ~path:"src/lib_lwt_result_stdlib/bare/structs"
    ~internal_name:"bare_structs"
    ~js_compatible:true
    ~deps:[seqes; lwt; mavkit_lwt_result_stdlib_bare_sigs]

let mavkit_lwt_result_stdlib_traced_functor_outputs =
  mavkit_lib
    "lwt-result-stdlib.traced.functor-outputs"
    ~path:"src/lib_lwt_result_stdlib/traced/functor_outputs"
    ~internal_name:"traced_functor_outputs"
    ~js_compatible:true
    ~deps:[lwt; mavkit_lwt_result_stdlib_bare_sigs]

let mavkit_lwt_result_stdlib_traced_sigs =
  mavkit_lib
    "lwt-result-stdlib.traced.sigs"
    ~path:"src/lib_lwt_result_stdlib/traced/sigs"
    ~internal_name:"traced_sigs"
    ~js_compatible:true
    ~deps:
      [
        lwt;
        mavkit_lwt_result_stdlib_bare_sigs;
        mavkit_lwt_result_stdlib_bare_structs;
        mavkit_lwt_result_stdlib_traced_functor_outputs;
      ]

let mavkit_lwt_result_stdlib_traced_structs =
  mavkit_lib
    "lwt-result-stdlib.traced.structs"
    ~path:"src/lib_lwt_result_stdlib/traced/structs"
    ~internal_name:"traced_structs"
    ~js_compatible:true
    ~deps:
      [
        lwt;
        mavkit_lwt_result_stdlib_traced_sigs;
        mavkit_lwt_result_stdlib_bare_structs;
      ]

let mavkit_lwt_result_stdlib =
  mavkit_lib
    "lwt-result-stdlib"
    ~path:"src/lib_lwt_result_stdlib"
    ~internal_name:"mavryk_lwt_result_stdlib"
    ~synopsis:"error-aware stdlib replacement"
    ~js_compatible:true
    ~documentation:
      Dune.
        [
          [S "package"; S "mavkit-libs"];
          [S "mld_files"; S "mavryk_lwt_result_stdlib"];
        ]
    ~deps:
      [
        lwt;
        mavkit_lwt_result_stdlib_bare_sigs;
        mavkit_lwt_result_stdlib_bare_structs;
        mavkit_lwt_result_stdlib_traced_sigs;
        mavkit_lwt_result_stdlib_traced_structs;
      ]

let mavkit_lwt_result_stdlib_examples_traces =
  mavkit_lib
    "lwt-result-stdlib.examples.traces"
    ~path:"src/lib_lwt_result_stdlib/examples/traces"
    ~internal_name:"traces"
    ~deps:
      [
        lwt;
        mavkit_lwt_result_stdlib_bare_structs;
        mavkit_lwt_result_stdlib_traced_sigs;
      ]

let _mavkit_lwt_result_stdlib_tests =
  tezt
    [
      "support";
      "traits_tiered";
      "test_hashtbl";
      "test_list_basic";
      "test_list_basic_lwt";
      "test_seq_basic";
      "test_fuzzing_lib";
      "test_fuzzing_list_against_stdlib";
      "test_fuzzing_option_against_stdlib";
      "test_fuzzing_set_against_stdlib";
      "test_fuzzing_map_against_stdlib";
    ]
    ~path:"src/lib_lwt_result_stdlib/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_lwt_result_stdlib |> open_;
        mavkit_lwt_result_stdlib_examples_traces;
        lwt_unix;
        alcotezt;
        qcheck_alcotest;
        mavkit_test_helpers |> open_;
      ]
    ~dune_with_test:Only_on_64_arch

let mavkit_error_monad =
  mavkit_lib
    "error-monad"
    ~internal_name:"mavryk_error_monad"
    ~path:"src/lib_error_monad"
    ~synopsis:"Error monad"
    ~deps:
      [
        mavkit_stdlib |> open_;
        data_encoding |> open_;
        lwt_canceler;
        lwt;
        mavkit_lwt_result_stdlib;
      ]
    ~conflicts:[external_lib "result" V.(less_than "1.5")]
    ~js_compatible:true

let mavkit_error_monad_legacy =
  mavkit_lib
    "error-monad-legacy"
    ~internal_name:"mavryk_error_monad_legacy"
    ~path:"src/lib_error_monad_legacy"
    ~synopsis:"Error monad (legacy)"
    ~deps:[lwt; mavkit_error_monad]
    ~conflicts:[external_lib "result" V.(less_than "1.5")]
    ~js_compatible:true

let mavkit_hacl =
  let js_stubs = ["random.js"; "evercrypt.js"] in
  let js_generated = "runtime-generated.js" in
  let js_helper = "helper.js" in
  mavkit_lib
    "hacl"
    ~internal_name:"mavryk_hacl"
    ~path:"src/lib_hacl"
    ~synopsis:"Thin layer around hacl-star"
    ~deps:[hacl_star; hacl_star_raw; ctypes_stubs_js]
    ~js_of_ocaml:
      [
        [
          S "javascript_files";
          G (Dune.of_atom_list (js_generated :: js_helper :: js_stubs));
        ];
      ]
    ~conflicts:[Conflicts.hacl_x25519; Conflicts.stdcompat]
    ~dune:
      Dune.
        [
          [
            S "rule";
            [S "targets"; S js_generated];
            [
              S "deps";
              S "gen/api.json";
              S "gen/gen.exe";
              G (of_atom_list js_stubs);
            ];
            [
              S "action";
              [
                S "with-stdout-to";
                S "%{targets}";
                of_list
                  (List.map
                     (fun l -> H (of_atom_list l))
                     Stdlib.List.(
                       ["run"; "gen/gen.exe"] :: ["-api"; "gen/api.json"]
                       :: List.map (fun s -> ["-stubs"; s]) js_stubs));
              ];
            ];
          ];
        ]

let _mavkit_hacl_gen0 =
  private_exe
    "gen0"
    ~path:"src/lib_hacl/gen/"
    ~opam:"mavkit-libs"
    ~with_macos_security_framework:true
    ~bisect_ppx:No
    ~modules:["gen0"]
    ~deps:[compiler_libs_common]

let _mavkit_hacl_gen =
  private_exe
    "gen"
    ~path:"src/lib_hacl/gen/"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[ctypes_stubs; ctypes; hacl_star_raw; ezjsonm]
    ~modules:["gen"; "bindings"; "api_json"]
    ~dune:
      (let package = "mavkit-libs" in
       Dune.
         [
           targets_rule
             ["bindings.ml"]
             ~deps:[Dune.(H [[S "package"; S "hacl-star-raw"]])]
             ~action:
               [
                 S "with-stdout-to";
                 S "%{targets}";
                 [
                   S "run";
                   S "./gen0.exe";
                   S "%{lib:hacl-star-raw:ocamlevercrypt.cma}";
                 ];
               ];
           [
             S "rule";
             [S "alias"; S "runtest_js"];
             [S "target"; S "api.json.corrected"];
             [S "package"; S package];
             [
               S "action";
               [
                 S "setenv";
                 S "NODE_PRELOAD";
                 S "hacl-wasm";
                 [S "run"; S "node"; S "%{dep:./check-api.js}"];
               ];
             ];
           ];
           alias_rule
             ~package
             "runtest_js"
             ~action:[S "diff"; S "api.json"; S "api.json.corrected"];
         ])

let _mavkit_hacl_tests =
  tezt
    [
      "test_prop_signature_pk";
      "test_hacl";
      "test_prop_hacl_hash";
      "test";
      "vectors_p256";
      "vectors_ed25519";
    ]
    ~path:"src/lib_hacl/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_error_monad |> open_ ~m:"TzLwtreslib";
        mavkit_lwt_result_stdlib |> open_;
        zarith;
        zarith_stubs_js;
        data_encoding |> open_;
        mavkit_hacl |> open_;
        qcheck_alcotest;
        alcotezt;
        mavkit_test_helpers |> open_;
      ]
    ~modes:[Native; JS]
    ~js_compatible:true

let _mavkit_error_monad_tests =
  tezt
    ["test_registration"; "test_splitted_error_encoding"]
    ~path:"src/lib_error_monad/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-libs"
    ~modes:[Native; JS]
    ~deps:[mavkit_error_monad |> open_; data_encoding; alcotezt]
    ~js_compatible:true

let mavkit_rpc =
  mavkit_lib
    "rpc"
    ~internal_name:"mavryk_rpc"
    ~path:"src/lib_rpc"
    ~synopsis:
      "Library of auto-documented RPCs (service and hierarchy descriptions)"
    ~deps:
      [
        data_encoding |> open_;
        mavkit_error_monad |> open_;
        resto;
        resto_directory;
        uri;
      ]
    ~js_compatible:true

let mavkit_risc_v_pvm =
  let base_name = "mavkit_risc_v_pvm" in
  let archive_file = Format.sprintf "lib%s.a" base_name in
  let archive_output_file =
    Format.sprintf "../target/release/%s" archive_file
  in
  let header_file = Format.sprintf "%s.h" base_name in
  let armerge =
    let open Dune in
    [
      S "subdir";
      S "helpers/bin";
      [
        S "rule";
        [S "target"; S "armerge"];
        [S "enabled_if"; of_atom_list ["="; "%{system}"; "macosx"]];
        [
          S "action";
          [
            S "chdir";
            S "../..";
            of_atom_list
              [
                "run";
                "cargo";
                "install";
                "--locked";
                "armerge";
                "--version";
                "2.0.0";
                "--bins";
                "--target-dir";
                "target";
                "--root";
                "helpers";
              ];
          ];
        ];
      ];
    ]
  in
  let make_rust_foreign_library_rule ?(extra_dep = Dune.E) ~enable_if ~transform
      () =
    let open Dune in
    [
      S "rule";
      [S "targets"; S archive_file; S header_file];
      [
        S "deps";
        [S "file"; S "Cargo.toml"];
        [S "file"; S "build.rs"];
        [S "source_tree"; S "src"];
        [S "file"; S "../Cargo.lock"];
        [S "file"; S "../Cargo.toml"];
        (* For the local dependent crates, these patterns only include files
         * directly contained in the crate's directory, as well as the [src]
         * directory, excluding all other directories in order to avoid
         * copying any build artifacts. *)
        [S "source_tree"; S "../kernel_loader"];
        [S "source_tree"; S "../interpreter"];
        (* We have to include all the locally mentioned Cargo.toml files
         * within the workspace (including transitively). *)
        [S "file"; S "../sandbox/Cargo.toml"];
        [S "file"; S "../../kernel_sdk/constants/Cargo.toml"];
        [S "file"; S "../../kernel_sdk/core/Cargo.toml"];
        [S "file"; S "../../kernel_sdk/host/Cargo.toml"];
        [S "file"; S "../../kernel_sdk/encoding/Cargo.toml"];
        extra_dep;
      ];
      [S "enabled_if"; enable_if];
      [
        S "action";
        [
          S "no-infer";
          [
            S "progn";
            of_atom_list ["run"; "chmod"; "u+w"; "Cargo.toml"];
            of_atom_list ["run"; "chmod"; "u+w"; "../Cargo.lock"];
            of_atom_list
              ["run"; "cargo"; "build"; "--release"; "-p"; "mavkit-risc-v-pvm"];
            transform archive_output_file archive_file;
          ];
        ];
      ];
    ]
  in
  let rust_foreign_library_darwin =
    let open Dune in
    make_rust_foreign_library_rule (* Make sure armerge is built beforehand *)
      ~extra_dep:(of_atom_list ["file"; "helpers/bin/armerge"])
      ~enable_if:(of_atom_list ["="; "%{system}"; "macosx"])
      ~transform:(fun input output ->
        (* We use armerge to keep only the essential symbols. This resolves
           issues on Mac where the linker can't resolve duplicate symbols
           when the resulting static library is linked with other static
           Rust libraries. *)
        of_atom_list
          [
            "run";
            "helpers/bin/armerge";
            "--keep-symbols=^_?mavkit_";
            input;
            "--output";
            output;
          ])
      ()
  in
  let rust_foreign_library =
    let open Dune in
    make_rust_foreign_library_rule
      ~enable_if:(of_atom_list ["<>"; "%{system}"; "macosx"])
      ~transform:(fun input output -> of_atom_list ["copy"; input; output])
      ()
  in
  public_lib
    "mavkit-risc-v-pvm"
    ~path:"src/risc_v/pvm"
    ~synopsis:"Bindings for RISC-V interpreter"
    ~deps:[ctypes; ctypes_foreign]
    ~flags:(Flags.standard ~disable_warnings:[9; 27] ())
    ~ctypes:
      Ctypes.
        {
          external_library_name = base_name;
          include_header = header_file;
          extra_search_dir = "%{env:INSIDE_DUNE=.}/src/risc_v/pvm";
          type_description = {instance = "Types"; functor_ = "Api_types_desc"};
          function_description =
            {instance = "Functions"; functor_ = "Api_funcs_desc"};
          generated_types = "Api_types";
          generated_entry_point = "Api";
          c_flags = [];
          c_library_flags = [];
          deps = [archive_file; header_file];
        }
    ~dune:Dune.[armerge; rust_foreign_library; rust_foreign_library_darwin]

let _mavkit_risc_v_pvm_test =
  tezt
    ["test_main"]
    ~path:"src/risc_v/pvm/test"
    ~opam:"mavkit-risc-v-pvm-test"
    ~synopsis:"Tests for RISC-V interpreter bindings"
    ~deps:[alcotezt; mavkit_risc_v_pvm]

let mavryk_bls12_381 =
  public_lib
    "mavryk-bls12-381"
    ~path:"src/lib_bls12_381"
    ~available:(N_ary_and [No_32; No_ppc; No_s390x])
    ~synopsis:
      "Implementation of the BLS12-381 curve (wrapper for the Blst library)"
    ~modules:
      [
        "mavryk_bls12_381";
        "ff_sig";
        "fr";
        "fq12";
        "g1";
        "g2";
        "gt";
        "pairing";
        "fq";
        "fq2";
      ]
    ~private_modules:["fq"; "fq2"]
    ~linkall:true
    ~c_library_flags:["-Wall"; "-Wextra"; ":standard"; "-lpthread"]
    ~deps:[integers; integers_stubs_js; zarith; zarith_stubs_js; hex]
    ~js_compatible:true
    ~js_of_ocaml:
      Dune.
        [
          [
            S "javascript_files";
            S "runtime_helper.js";
            S "blst_bindings_stubs.js";
          ];
        ]
    ~npm_deps:[Npm.make "ocaml-bls12-381" (Path "src/lib_bls12_381/blst.js")]
    ~foreign_archives:["blst"]
    ~foreign_stubs:
      {
        language = C;
        flags =
          [
            S "-Wall";
            S "-Wextra";
            S ":standard";
            [S ":include"; S "c_flags_blst.sexp"];
          ];
        names = ["blst_wrapper"; "blst_bindings_stubs"];
      }
    ~dune:
      Dune.
        [
          [S "copy_files"; S "libblst/bindings/blst.h"];
          [S "copy_files"; S "libblst/bindings/blst_extended.h"];
          [S "copy_files"; S "libblst/bindings/blst_aux.h"];
          [S "data_only_dirs"; S "libblst"];
          [
            S "rule";
            [
              S "deps";
              [S "source_tree"; S "libblst"];
              S "build_blst.sh";
              S "blst_extended.c";
              S "blst_extended.h";
            ];
            [S "targets"; S "libblst.a"; S "dllblst.so"; S "c_flags_blst.sexp"];
            [
              S "action";
              [
                S "no-infer";
                [
                  S "progn";
                  [
                    S "run";
                    S "cp";
                    S "blst_extended.c";
                    S "libblst/src/blst_extended.c";
                  ];
                  [
                    S "run";
                    S "cp";
                    S "blst_extended.h";
                    S "libblst/bindings/blst_extended.h";
                  ];
                  [S "run"; S "sh"; S "build_blst.sh"];
                  [S "run"; S "cp"; S "libblst/libblst.a"; S "libblst.a"];
                  [
                    S "ignore-stderr";
                    [
                      S "with-accepted-exit-codes";
                      [S "or"; S "0"; S "1"];
                      [S "run"; S "cp"; S "libblst/libblst.so"; S "dllblst.so"];
                    ];
                  ];
                  [
                    S "ignore-stderr";
                    [
                      S "with-accepted-exit-codes";
                      [S "or"; S "0"; S "1"];
                      [
                        S "run";
                        S "cp";
                        S "libblst/libblst.dylib";
                        S "dllblst.so";
                      ];
                    ];
                  ];
                ];
              ];
            ];
          ];
          [
            S "rule";
            [S "mode"; S "fallback"];
            [
              S "deps";
              [S "source_tree"; S "libblst"];
              S "needed-wasm-names";
              S "blst_extended.c";
              [S "glob_files"; S "*.h"];
            ];
            [S "targets"; S "blst.wasm"; S "blst.js"];
            [
              S "action";
              [
                S "progn";
                [S "run"; S "cp"; S "-f"; S "blst_extended.c"; S "libblst/src/"];
                [
                  S "run";
                  S "emcc";
                  S "-Os";
                  G [S "-o"; S "blst.js"];
                  G [S "-I"; S "libblst/src/"];
                  S "libblst/src/server.c";
                  S "%{dep:blst_wrapper.c}";
                  S "-DENABLE_EMSCRIPTEN_STUBS";
                  S "-DENABLE_MODULE_RECOVERY";
                  G [S "-s"; S "ALLOW_MEMORY_GROWTH=1"];
                  G [S "-s"; S "WASM=1"];
                  G [S "-s"; S "MALLOC=emmalloc"];
                  G [S "-s"; S "EXPORT_ES6=0"];
                  G [S "-s"; S "FILESYSTEM=0"];
                  G [S "-s"; S "MODULARIZE=1"];
                  G [S "-s"; S "EXPORT_NAME='_BLS12381'"];
                  G [S "-s"; S "EXPORTED_FUNCTIONS=@needed-wasm-names"];
                  S "--no-entry";
                ];
              ];
            ];
          ];
          [
            S "executable";
            [S "name"; S "gen_wasm_needed_names"];
            [S "modules"; S "gen_wasm_needed_names"];
            [S "libraries"; S "re"];
          ];
          targets_rule
            ["needed-wasm-names"]
            ~promote:true
            ~action:
              [
                S "with-outputs-to";
                S "%{targets}";
                [S "run"; S "./gen_wasm_needed_names.exe"; S "%{files}"];
              ]
            ~deps:[[S ":files"; S "blst_bindings_stubs.js"]];
          [
            S "install";
            [
              S "files";
              S "libblst/bindings/blst.h";
              S "libblst/bindings/blst_aux.h";
              S "blst_extended.h";
              S "blst_misc.h";
              S "caml_bls12_381_stubs.h";
            ];
            [S "section"; S "lib"];
            [S "package"; S "mavryk-bls12-381"];
          ];
        ]

let _bls12_381_tests =
  tezt
    [
      "test_fr";
      "test_g1";
      "test_g2";
      "test_pairing";
      "test_hash_to_curve";
      "test_random_state";
      "test_fq12";
      "test_gt";
      "utils";
      "ff_pbt";
      "test_ec_make";
    ]
    ~path:"src/lib_bls12_381/test"
    ~opam:"mavryk-bls12-381"
    ~deps:[alcotezt; qcheck_alcotest; mavryk_bls12_381]
    ~modes:[Native; JS]
    ~js_compatible:true
    ~dep_globs_rec:["test_vectors/*"]

let _mavkit_bls12_381_utils =
  let names =
    [
      "generate_pairing_vectors";
      "generate_miller_loop_vectors";
      "generate_final_exponentiation_vectors";
      "generate_g1_test_vectors";
      "generate_g2_test_vectors";
      "generate_fr_test_vectors";
      "generate_hash_to_curve_vectors";
    ]
  in
  private_exes
    names
    ~path:"src/lib_bls12_381/utils"
    ~opam:"mavryk-bls12-381"
    ~bisect_ppx:No
    ~modules:names
    ~deps:[hex; mavryk_bls12_381]

let mavkit_bls12_381_signature =
  mavkit_lib
    "bls12-381-signature"
    ~path:"src/lib_bls12_381_signature"
    ~internal_name:"bls12_381_signature"
    ~deps:[mavryk_bls12_381]
    ~modules:["bls12_381_signature"]
    ~js_compatible:true
    ~foreign_stubs:
      {
        language = C;
        flags = [S "-Wall"; S "-Wextra"; S ":standard"];
        names = ["blst_bindings_stubs"];
      }
    ~c_library_flags:["-Wall"; "-Wextra"; ":standard"; "-lpthread"]
    ~js_of_ocaml:[[S "javascript_files"; S "blst_bindings_stubs.js"]]
    ~linkall:true
    ~dune:
      Dune.
        [
          targets_rule
            ["needed-wasm-names"]
            ~promote:true
            ~action:
              [
                S "with-outputs-to";
                S "%{targets}";
                [S "run"; S "./gen_wasm_needed_names.exe"; S "%{files}"];
              ]
            ~deps:[[S ":files"; S "blst_bindings_stubs.js"]];
        ]

(* TODO: dep_globs aren't added to the rules for JS tests *)
let _mavkit_bls12_381_signature_tests =
  tezt
    ["test_aggregated_signature"; "test_signature"; "utils"]
    ~path:"src/lib_bls12_381_signature/test"
    ~opam:"mavkit-libs"
      (* TODO: https://gitlab.com/tezos/tezos/-/issues/5377
         This test is affected by the [FinalizationRegistry] hangs in JS,
         so although JS compatible, we only test in [Native] mode *)
    ~modes:[Native]
    ~deps:
      [
        mavryk_bls12_381; mavkit_bls12_381_signature; alcotezt; integers_stubs_js;
      ]
    ~dep_globs_rec:["test_vectors/*"] (* See above *)
    ~js_compatible:false

let _mavkit_bls12_381_signature_gen_wasm_needed_names =
  private_exe
    "gen_wasm_needed_names"
    ~path:"src/lib_bls12_381_signature"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~modules:["gen_wasm_needed_names"]
    ~deps:[re]

let mavkit_crypto =
  mavkit_lib
    "crypto"
    ~internal_name:"mavryk_crypto"
    ~path:"src/lib_crypto"
    ~synopsis:"Library with all the cryptographic primitives used by Mavryk"
    ~deps:
      [
        mavkit_stdlib |> open_;
        data_encoding |> open_;
        mavkit_lwt_result_stdlib;
        lwt;
        mavkit_hacl;
        secp256k1_internal;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_rpc;
        aches;
        zarith;
        zarith_stubs_js;
        mavryk_bls12_381;
        mavkit_bls12_381_signature;
      ]
    ~js_compatible:true

let _mavkit_crypto_tests =
  tezt
    [
      "test_run";
      "test_prop_signature";
      "roundtrips";
      "key_encoding_vectors";
      "test_base58";
      "test_blake2b";
      "test_crypto_box";
      "test_deterministic_nonce";
      "test_merkle";
      "test_signature";
      "test_signature_encodings";
      "test_timelock_legacy";
      "test_timelock";
      "test_context_hash";
      "vectors_secp256k1_keccak256";
    ]
    ~path:"src/lib_crypto/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_crypto |> open_;
        mavkit_error_monad |> open_ ~m:"TzLwtreslib";
        zarith;
        zarith_stubs_js;
        mavkit_hacl;
        data_encoding |> open_;
        alcotezt;
        qcheck_alcotest;
        mavkit_test_helpers |> open_;
      ]
    ~modes:[Native; JS]
    ~js_compatible:true

let _mavkit_crypto_tests_unix =
  tezt
    ["test_crypto_box"]
    ~path:"src/lib_crypto/test-unix"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_crypto |> open_;
        mavkit_error_monad |> open_ ~m:"TzLwtreslib";
        zarith;
        zarith_stubs_js;
        mavkit_hacl;
        data_encoding |> open_;
        alcotezt;
        lwt_unix;
        qcheck_alcotest;
        mavkit_test_helpers |> open_;
      ]

let mavkit_bls12_381_hash =
  mavkit_lib
    "bls12-381-hash"
    ~path:"src/lib_bls12_381_hash"
    ~internal_name:"bls12_381_hash"
    ~c_library_flags:["-Wall"; "-Wextra"; ":standard"; "-lpthread"]
    ~deps:[mavryk_bls12_381]
    ~js_compatible:false
    ~foreign_stubs:
      {
        language = C;
        flags = [];
        names =
          [
            "caml_rescue_stubs";
            "caml_anemoi_stubs";
            "caml_poseidon_stubs";
            "caml_griffin_stubs";
            "rescue";
            "anemoi";
            "poseidon";
            "griffin";
          ];
      }
    ~linkall:true

let _mavkit_bls12_381_hash_tests =
  tezt
    ["test_poseidon"; "test_rescue"; "test_anemoi"; "test_griffin"; "test_jive"]
    ~path:"src/lib_bls12_381_hash/test"
    ~opam:"mavkit-libs"
    ~deps:[alcotezt; mavryk_bls12_381; mavkit_bls12_381_hash]
    ~flags:(Flags.standard ~disable_warnings:[3] ())

let mavkit_mec =
  mavkit_lib
    "mec"
    ~path:"src/lib_mec"
    ~internal_name:"mec"
    ~deps:[alcotest; mavryk_bls12_381; bigarray_compat; eqaf]

let _mavkit_mec_tests =
  tezt
    [
      "ark_poseidon128";
      "ark_pobls";
      "mds_pobls";
      "mds_poseidon128";
      "poseidon128_linear_trick_expected_output";
      "test_vector_pedersen_hash";
      "test_neptunus";
      "test_orchard";
      "test_pedersen_hash";
      "test_poseidon128";
      "test_poseidon252";
      "test_sinsemilla";
      "test_babyjubjub";
      "test_babyjubjub_reduced";
      "test_bandersnatch_affine_montgomery";
      "test_bandersnatch_affine_weierstrass";
      "test_bandersnatch_affine_edwards";
      (* FIXME: test_bandersnatch_all has been removed from the repository, see
         https://gitlab.com/tezos/tezos/-/issues/5147 *)
      "test_bls12_381_affine";
      "test_bls12_381_projective";
      "test_bn254_affine";
      "test_bn254_jacobian";
      "test_bn254_projective";
      "test_curve25519_affine_edwards";
      "test_curve25519_conversions_between_forms";
      "test_curve25519_montgomery";
      "test_curve448";
      "test_ec_functor";
      "test_iso_pallas_affine";
      "test_jubjub";
      "test_jubjub_conversions_between_forms";
      "test_jubjub_weierstrass";
      "test_pallas_affine";
      "test_pallas_jacobian";
      "test_pallas_projective";
      "test_secp256k1_affine";
      "test_secp256k1_jacobian";
      "test_secp256k1_projective";
      "test_secp256r1_affine";
      "test_secp256r1_jacobian";
      "test_secp256r1_projective";
      "test_tweedledee_affine";
      "test_tweedledee_jacobian";
      "test_tweedledee_projective";
      "test_tweedledum_affine";
      "test_tweedledum_jacobian";
      "test_tweedledum_projective";
      "test_vesta_affine";
      "test_vesta_jacobian";
      "test_vesta_projective";
      "test_digestif";
      "test_linear_trick";
      "test_marvellous";
      "test_redjubjub";
      "test_find_group_hash";
      "test_iterator";
    ]
    ~path:"src/lib_mec/test"
    ~opam:"mavkit-libs"
    ~deps:[alcotezt; mavkit_mec |> open_]

let mavkit_polynomial =
  mavkit_lib
    "polynomial"
    ~path:"src/lib_polynomial"
    ~internal_name:"polynomial"
    ~synopsis:"Polynomials over finite fields"
    ~deps:[mavryk_bls12_381; zarith]

let _mavkit_polynomial_tests =
  tezt
    ["test_with_finite_field"; "test_utils"; "polynomial_pbt"]
    ~path:"src/lib_polynomial/test"
    ~opam:"mavkit-libs"
    ~deps:[mavryk_bls12_381; mavkit_mec; alcotezt; mavkit_polynomial]

let mavkit_bls12_381_polynomial =
  mavkit_lib
    "bls12-381-polynomial"
    ~internal_name:"mavkit_bls12_381_polynomial"
    ~path:"src/lib_bls12_381_polynomial"
    ~synopsis:
      "Polynomials over BLS12-381 finite field - Temporary vendored version of \
       Mavkit"
    ~c_library_flags:["-Wall"; "-Wextra"; ":standard"]
    ~preprocess:[pps ppx_repr]
    ~deps:[mavryk_bls12_381; ppx_repr; bigstringaf]
    ~js_compatible:false
    ~foreign_stubs:
      {
        language = C;
        flags = [];
        names =
          [
            "caml_bls12_381_polynomial_polynomial_stubs";
            "caml_bls12_381_polynomial_srs_stubs";
            "caml_bls12_381_polynomial_ec_array_stubs";
            "caml_bls12_381_polynomial_fft_stubs";
            "bls12_381_polynomial_polynomial";
            "bls12_381_polynomial_fft";
          ];
      }

let _mavkit_bls12_381_polynomial_tests =
  tezt
    [
      "test_main";
      "helpers";
      "test_coefficients";
      "test_domains";
      "test_evaluations";
      "test_pbt";
      "test_polynomial";
      "test_srs";
    ]
    ~path:"src/lib_bls12_381_polynomial/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        alcotezt;
        qcheck_alcotest;
        mavkit_polynomial;
        mavryk_bls12_381;
        mavkit_bls12_381_polynomial;
      ]
    ~dep_files:["srs_zcash_g1_5"]

let mavkit_srs_extraction =
  mavkit_lib
    "srs-extraction"
    ~internal_name:"mavkit_srs_extraction"
    ~path:"src/lib_srs_extraction"
    ~modules:["libsrs"]
    ~bisect_ppx:No
    ~deps:[mavryk_bls12_381; mavkit_bls12_381_polynomial |> open_]

let _mavkit_srs_extraction_main =
  private_exe
    "srs_extraction_main"
    ~path:"src/lib_srs_extraction"
    ~opam:"mavkit-libs"
    ~modules:["srs_extraction_main"]
    ~bisect_ppx:No
    ~deps:
      [
        mavkit_srs_extraction |> open_;
        cmdliner;
        unix;
        mavryk_bls12_381;
        mavkit_bls12_381_polynomial |> open_;
      ]

let _mavkit_srs_extraction_tests =
  tezt
    ["test_main"]
    ~path:"src/lib_srs_extraction/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_srs_extraction |> open_; alcotezt]
    ~dep_files:["phase1radix2m5"]
    ~dune:
      Dune.(
        let extract curve srs_file =
          let generated_srs_file = srs_file ^ ".generated" in
          [
            S "rule";
            [S "alias"; S "runtest"];
            [S "package"; S "mavkit-libs"];
            [S "deps"; S srs_file; S "phase1radix2m5"];
            [
              S "action";
              [
                S "progn";
                [
                  S "run";
                  S "%{exe:../srs_extraction_main.exe}";
                  S "extract";
                  S "zcash";
                  S curve;
                  S "phase1radix2m5";
                  S "-o";
                  S generated_srs_file;
                ];
                [S "diff"; S generated_srs_file; S srs_file];
              ];
            ];
          ]
        in
        [
          extract "g1" "srs_zcash_g1_5";
          extract "g2" "srs_zcash_g2_5";
          alias_rule
            "runtest"
            ~package:"mavkit-libs"
            ~deps:["srs_zcash_g1_5"; "srs_zcash_g2_5"]
            ~action:
              (run
                 "../srs_extraction_main.exe"
                 ["check"; "srs_zcash_g1_5"; "srs_zcash_g2_5"]);
          alias_rule
            "runtest"
            ~package:"mavkit-libs"
            ~deps:["srs_filecoin_g1_6"; "srs_filecoin_g2_6"]
            ~action:
              (run
                 "../srs_extraction_main.exe"
                 ["check"; "srs_filecoin_g1_6"; "srs_filecoin_g2_6"]);
        ])

let mavkit_plompiler =
  mavkit_lib
    "plompiler"
    ~internal_name:"plompiler"
    ~path:"src/lib_plompiler"
    ~deps:
      [
        repr;
        stdint;
        hacl_star;
        mavkit_bls12_381_hash;
        mavkit_polynomial;
        mavkit_mec;
      ]
    ~preprocess:[staged_pps [ppx_repr; ppx_deriving_show]]

(* Deactivating z3 tests. z3 is not installed in the CI *)
(* ~dune: *)
(*   Dune. *)
(*     [ *)
(*       alias_rule *)
(*         "runtest" *)
(*         ~deps_dune:[S "z3/run_z3_tests.sh"; [S "glob_files"; S "z3/*.z3"]] *)
(*         ~action:[S "chdir"; S "z3"; [S "run"; S "sh"; S "run_z3_tests.sh"]]; *)
(*     ] *)

(* Tests of this form are run in multiple PlonK-related packages. *)
let make_plonk_runtest_invocation ~package =
  Dune.
    [
      alias_rule
        "runtest"
        ~package
        ~action:
          (G
             [
               setenv
                 "RANDOM_SEED"
                 "42"
                 (progn
                    [
                      run_exe "main" ["-q"];
                      [S "diff?"; S "test-quick.expected"; S "test.output"];
                    ]);
             ]);
      alias_rule "runtest_slow" ~package ~action:(run_exe "main" []);
      alias_rule
        "runtest_slow_with_regression"
        ~package
        ~action:
          (G
             [
               setenv
                 "RANDOM_SEED"
                 "42"
                 (progn
                    [
                      run_exe "main" [];
                      [S "diff?"; S "test-slow.expected"; S "test.output"];
                    ]);
             ]);
    ]

let mavkit_kzg =
  mavkit_lib
    "kzg"
    ~path:"src/lib_kzg"
    ~synopsis:"Toolbox for KZG polynomial commitment"
    ~deps:
      [
        repr;
        data_encoding |> open_;
        mavkit_bls12_381_polynomial |> open_;
        mavkit_crypto;
      ]
    ~preprocess:[pps ppx_repr]

let mavkit_plonk =
  mavkit_lib
    "plonk"
    ~path:"src/lib_plonk"
    ~synopsis:"Plonk zero-knowledge proving system"
    ~deps:[mavkit_kzg; mavkit_plompiler |> open_; str]
    ~preprocess:[pps ppx_repr]

let mavkit_plonk_aggregation =
  mavkit_lib
    "plonk.aggregation"
    ~path:"src/lib_aplonk/plonk-aggregation"
    ~internal_name:"aggregation"
    ~preprocess:[pps ppx_repr]
    ~deps:[mavkit_plonk; mavkit_bls12_381_polynomial |> open_]

let mavkit_aplonk =
  mavkit_lib
    "aplonk"
    ~internal_name:"aplonk"
    ~path:"src/lib_aplonk"
    ~preprocess:[pps ppx_repr]
    ~deps:[mavkit_plonk_aggregation]

let mavkit_plonk_distribution =
  mavkit_lib
    "plonk.distribution"
    ~internal_name:"distribution"
    ~path:"src/lib_distributed_plonk/distribution"
    ~deps:[mavkit_plonk; mavkit_plonk_aggregation]
    ~preprocess:[pps ppx_repr]

let mavkit_plonk_communication =
  mavkit_lib
    "plonk.communication"
    ~internal_name:"communication"
    ~path:"src/lib_distributed_plonk/communication"
    ~deps:[logs; distributed_internal_lwt; mavkit_plonk_distribution |> open_]
    ~preprocess:[pps ppx_repr]

let mavkit_plonk_test_helpers =
  mavkit_lib
    "plonk.plonk-test"
    ~path:"src/lib_plonk/test"
    ~internal_name:"plonk_test"
    ~deps:[mavkit_plonk; mavkit_plonk_aggregation; mavkit_plonk_distribution]
    ~modules:["helpers"; "cases"]
    ~preprocess:[pps ppx_repr]
    ~dune:(make_plonk_runtest_invocation ~package:"mavkit-libs")

let _mavkit_plonk_test_helpers_main =
  private_exe
    "main"
    ~path:"src/lib_plonk/test"
    ~opam:"mavkit-libs"
    ~modules:
      [
        "main";
        "test_circuit";
        "test_cq";
        "test_evaluations";
        "test_main_protocol";
        "test_pack";
        "test_permutations";
        "test_plookup";
        "test_polynomial_commitment";
        "test_polynomial_protocol";
        "test_range_checks";
        "test_utils";
      ]
    ~bisect_ppx:No
    ~deps:
      [
        mavkit_plonk_test_helpers;
        qcheck_alcotest;
        mavkit_bls12_381_polynomial |> open_;
      ]

let _mavkit_plonk_distribution_test =
  private_exe
    "main"
    ~path:"src/lib_distributed_plonk/distribution/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_plonk_aggregation; mavkit_plonk_test_helpers]
    ~modules:["main"; "test_polynomial_commitment"]
    ~dune:(make_plonk_runtest_invocation ~package:"mavkit-libs")

let _mavkit_plonk_test_helpers_bench =
  private_exe
    "bench"
    ~path:"src/lib_plonk/test"
    ~opam:"mavkit-libs"
    ~modules:["bench"]
    ~bisect_ppx:No
    ~deps:[mavkit_plonk_test_helpers]

let _mavkit_plonk_test_plompiler_afl =
  private_exe
    "afl"
    ~path:"src/lib_plonk/test_plompiler"
    ~opam:"mavkit-libs"
    ~modules:["afl"]
    ~bisect_ppx:No
    ~deps:[mavkit_plompiler; mavkit_plonk; mavryk_bls12_381]

let _mavkit_plonk_test_plompiler_main =
  private_exe
    "main"
    ~path:"src/lib_plonk/test_plompiler"
    ~opam:"mavkit-libs"
    ~modules:
      [
        "bench_poseidon";
        "benchmark";
        "main";
        "test_anemoi";
        "test_blake";
        "test_sha2";
        "test_core";
        "test_edwards";
        "test_encoding";
        "test_enum";
        "test_input_com";
        "test_linear_algebra";
        "test_lookup";
        "test_merkle";
        "test_merkle_narity";
        "test_mod_arith";
        "test_optimizer";
        "test_poseidon";
        "test_range_checks";
        "test_schnorr";
        "test_ed25519";
        "test_edwards25519";
        "test_serialization";
        "test_weierstrass";
        "test_utils";
      ]
    ~bisect_ppx:No
    ~deps:[mavkit_plonk_test_helpers]
    ~dune:(make_plonk_runtest_invocation ~package:"mavkit-libs")

let mavkit_distributed_plonk =
  mavkit_lib
    "distributed-plonk"
    ~internal_name:"distributed_plonk"
    ~path:"src/lib_distributed_plonk"
    ~deps:
      [
        mavkit_aplonk;
        mavkit_plonk_communication;
        mavkit_plonk |> open_;
        mavkit_plonk_test_helpers;
      ]
    ~modules:
      [
        "distributed_prover";
        "filenames";
        "master_runner";
        "distribution_helpers";
        "worker";
      ]
    ~preprocess:[pps ppx_repr]
    ~bisect_ppx:Yes

let _mavkit_distributed_plonk_test_main =
  test
    "test_distribution"
    (* This test is disabled in the CI since the test is flaky and
       development of distributed plonk is on hiatus. As the
       dependencies of distributed plonk have significant load-time,
       we do not integrate it in the main tezt entrypoint using the
       [tezt] function. *)
    ~enabled_if:Dune.[S "="; S "false"; S "%{env:CI=false}"]
    ~opam:"mavkit-libs"
    ~path:"src/lib_distributed_plonk/test"
    ~deps:
      [
        mavkit_distributed_plonk;
        mavkit_plonk;
        mavkit_plonk_aggregation;
        mavkit_plonk_distribution;
        mavkit_aplonk;
        mavkit_plonk_test_helpers;
        mavkit_test_helpers |> open_;
        tezt_lib |> open_ |> open_ ~m:"Base";
      ]

let _mavkit_distributed_plonk_worker_runner =
  private_exe
    "worker_runner"
    ~path:"src/lib_distributed_plonk"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[mavkit_distributed_plonk; mavkit_plonk_distribution]
    ~modules:["worker_runner"]

let _mavkit_aplonk_test_main =
  private_exe
    "main"
    ~path:"src/lib_aplonk/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_plonk_test_helpers; mavkit_aplonk]
    ~modules:["main"; "test_aplonk"; "test_main_protocol"]
    ~dune:(make_plonk_runtest_invocation ~package:"mavkit-libs")

let _mavkit_distributed_plonk_executable =
  private_exe
    "distribution"
    ~path:"src/lib_distributed_plonk"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[mavkit_distributed_plonk |> open_]
    ~modules:["distribution"]

let _mavkit_distributed_plonk_executable_meta =
  private_exe
    "distribution_meta"
    ~path:"src/lib_distributed_plonk"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[mavkit_distributed_plonk |> open_]
    ~modules:["distribution_meta"]

let _mavkit_aplonk_test_helpers_bench =
  private_exe
    "bench"
    ~path:"src/lib_aplonk/test"
    ~opam:"mavkit-libs"
    ~modules:["bench"]
    ~bisect_ppx:No
    ~deps:[mavkit_plonk_test_helpers; mavkit_aplonk]

let mavkit_epoxy_tx =
  mavkit_lib
    "epoxy-tx"
    ~path:"src/lib_epoxy_tx"
    ~internal_name:"epoxy_tx"
    ~deps:[mavkit_plompiler; hex; stdint; mavkit_plonk; mavkit_mec]

let _mavkit_epoxy_tx_tests =
  private_exe
    "main"
    ~path:"src/lib_epoxy_tx/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_epoxy_tx; mavkit_plonk_test_helpers; mavkit_aplonk]
    ~dune:(make_plonk_runtest_invocation ~package:"mavkit-libs")

let mavkit_dal_config =
  mavkit_lib
    "crypto-dal.dal-config"
    ~internal_name:"mavryk_crypto_dal_mavkit_dal_config"
    ~path:"src/lib_crypto_dal/dal_config"
    ~deps:[data_encoding |> open_]
    ~js_compatible:true

let mavkit_crypto_dal =
  mavkit_lib
    "crypto-dal"
    ~internal_name:"mavryk_crypto_dal"
    ~path:"src/lib_crypto_dal"
    ~synopsis:"DAL cryptographic primitives"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_error_monad |> open_;
        data_encoding |> open_;
        mavkit_dal_config |> open_;
        mavkit_bls12_381_polynomial;
        lwt_unix;
        mavkit_kzg;
      ]

let _mavkit_crypto_dal_tests =
  tezt
    ["test_dal_cryptobox"]
    ~path:"src/lib_crypto_dal/test"
    ~opam:"mavkit-libs"
    ~dep_files:["srs_zcash_g1_5"; "srs_zcash_g2_5"]
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_crypto_dal |> open_;
        mavkit_dal_config |> open_;
        mavkit_error_monad |> open_;
        data_encoding |> open_;
        alcotezt;
        qcheck_alcotest;
        mavkit_bls12_381_polynomial;
        mavkit_test_helpers;
      ]

let mavkit_event_logging =
  mavkit_lib
    "event-logging"
    ~internal_name:"mavryk_event_logging"
    ~path:"src/lib_event_logging"
    ~synopsis:"Mavkit event logging library"
    ~deps:
      [
        mavkit_stdlib |> open_;
        data_encoding |> open_;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_lwt_result_stdlib;
        uri;
      ]
    ~js_compatible:true

let mavkit_event_logging_test_helpers =
  mavkit_lib
    "event-logging-test-helpers"
    ~internal_name:"mavryk_event_logging_test_helpers"
    ~path:"src/lib_event_logging/test_helpers"
    ~synopsis:"Test helpers for the event logging library"
    ~deps:
      [
        mavkit_stdlib;
        mavkit_lwt_result_stdlib |> open_;
        data_encoding;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_event_logging |> open_;
        mavkit_test_helpers |> open_;
        tezt_core_lib |> open_;
        alcotezt;
      ]
    ~js_compatible:true
    ~linkall:true
    ~bisect_ppx:No

let mavkit_stdlib_unix =
  mavkit_lib
    "stdlib-unix"
    ~internal_name:"mavryk_stdlib_unix"
    ~path:"src/lib_stdlib_unix"
    ~synopsis:
      "Yet-another local-extension of the OCaml standard library \
       (unix-specific fragment)"
    ~deps:
      [
        unix;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_lwt_result_stdlib;
        mavkit_event_logging |> open_;
        mavkit_stdlib |> open_;
        data_encoding |> open_;
        aches_lwt;
        lwt_unix;
        ipaddr_unix;
        re;
        ezjsonm;
        ptime;
        ptime_clock_os;
        mtime;
        mtime_clock_os;
        conf_libev;
        uri;
      ]

let _mavkit_stdlib_unix_test =
  tezt
    [
      "test_key_value_store";
      "test_key_value_store_fuzzy";
      "test_log_config_rules";
    ]
    ~path:"src/lib_stdlib_unix/test/"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_stdlib_unix |> open_;
        mavkit_event_logging |> open_;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
      ]

let ppx_irmin =
  mavkit_internal_lib
    "ppx_irmin"
    ~path:"irmin/lib_ppx_irmin"
    ~deps:[ppx_repr_lib]
    ~ppx_kind:Ppx_deriver

let ppx_irmin_internal_lib =
  mavkit_internal_lib
    "ppx_irmin.internal_lib"
    ~path:"irmin/lib_ppx_irmin/internal"
    ~modules:["ppx_irmin_internal_lib"]
    ~deps:[logs]

let ppx_irmin_internal =
  mavkit_internal_lib
    "ppx_irmin.internal"
    ~path:"irmin/lib_ppx_irmin/internal"
    ~modules:["ppx_irmin_internal"]
    ~deps:[ppxlib; ppx_irmin_internal_lib; ppx_irmin]
    ~ppx_kind:Ppx_rewriter
    ~ppx_runtime_libraries:[logs; ppx_irmin_internal_lib]
    ~preprocess:[pps ppxlib_metaquot]

let irmin_data =
  mavkit_internal_lib
    "irmin.data"
    ~path:"irmin/lib_irmin/data"
    ~deps:[bigstringaf; fmt]

let irmin =
  mavkit_internal_lib
    "irmin"
    ~path:"irmin/lib_irmin"
    ~deps:
      [
        irmin_data;
        astring;
        bheap;
        digestif;
        fmt;
        jsonm;
        logs;
        logs_fmt;
        lwt;
        mtime;
        ocamlgraph;
        uri;
        uutf;
        re_export repr;
      ]
    ~preprocess:[pps ~args:["--"; "--lib"; "Type"] ppx_irmin_internal]

let irmin_mem =
  mavkit_internal_lib
    "irmin.mem"
    ~path:"irmin/lib_irmin/mem"
    ~deps:[irmin; logs; lwt]
    ~preprocess:[pps ppx_irmin_internal]
    ~flags:(Flags.standard ~disable_warnings:[68] ())

let irmin_pack =
  mavkit_internal_lib
    "irmin_pack"
    ~path:"irmin/lib_irmin_pack"
    ~deps:[fmt; irmin; irmin_data; logs; lwt; optint]
    ~preprocess:[pps ppx_irmin_internal]
    ~flags:(Flags.standard ~disable_warnings:[66] ())

let irmin_pack_mem =
  mavkit_internal_lib
    "irmin_pack.mem"
    ~path:"irmin/lib_irmin_pack/mem"
    ~deps:[irmin_pack; irmin_mem]
    ~preprocess:[pps ppx_irmin_internal]

let irmin_pack_unix =
  mavkit_internal_lib
    "irmin_pack.unix"
    ~path:"irmin/lib_irmin_pack/unix"
    ~deps:
      [
        fmt;
        index;
        index_unix;
        irmin;
        irmin_pack;
        logs;
        lwt;
        lwt_unix;
        mtime;
        cmdliner;
        optint;
        checkseum;
        checkseum_ocaml;
        rusage;
      ]
    ~preprocess:[pps ppx_irmin_internal]
    ~flags:(Flags.standard ~disable_warnings:[66; 68] ())

let irmin_test_helpers =
  mavkit_internal_lib
    "irmin_test_helpers"
    ~path:"irmin/test/helpers"
    ~deps:
      [alcotezt; astring; fmt; irmin; jsonm; logs; lwt; mtime; mtime_clock_os]
    ~preprocess:[pps ppx_irmin_internal]
    ~flags:(Flags.standard ~disable_warnings:[66; 68] ())

let mavkit_clic =
  mavkit_lib
    "clic"
    ~internal_name:"mavryk_clic"
    ~path:"src/lib_clic"
    ~deps:
      [
        mavkit_stdlib |> open_;
        lwt;
        re;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_lwt_result_stdlib;
      ]
    ~js_compatible:true

let mavkit_clic_unix =
  mavkit_lib
    "clic.unix"
    ~internal_name:"mavryk_clic_unix"
    ~path:"src/lib_clic/unix"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_clic |> open_;
        mavkit_stdlib_unix;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_lwt_result_stdlib;
      ]

let _mavkit_clic_tests =
  tezt
    ["test_clic"]
    ~path:"src/lib_clic/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_stdlib |> open_; mavkit_clic |> open_; lwt_unix; alcotezt]

let _mavkit_clic_example =
  private_exe
    "clic_example"
    ~path:"src/lib_clic/examples"
    ~opam:""
    ~deps:[mavkit_clic; lwt_unix]
    ~bisect_ppx:No
    ~static:false

let mavkit_micheline =
  mavkit_lib
    "micheline"
    ~internal_name:"mavryk_micheline"
    ~path:"src/lib_micheline"
    ~synopsis:"Internal AST and parser for the Michelson language"
    ~deps:
      [
        uutf;
        zarith;
        zarith_stubs_js;
        mavkit_stdlib |> open_;
        mavkit_error_monad |> open_;
        data_encoding |> open_;
      ]
    ~js_compatible:true
    ~inline_tests:ppx_expect

let _mavkit_micheline_tests =
  private_lib
    "test_parser"
    ~path:"src/lib_micheline/test"
    ~opam:"mavkit-libs"
    ~inline_tests:ppx_expect
    ~modules:["test_parser"]
    ~deps:[mavkit_micheline |> open_]
    ~js_compatible:true

let _mavkit_micheline_tests =
  private_lib
    "test_diff"
    ~path:"src/lib_micheline/test"
    ~opam:"mavkit-libs"
    ~inline_tests:ppx_expect
    ~modules:["test_diff"]
    ~deps:[mavkit_micheline |> open_]
    ~js_compatible:true

let mavkit_base =
  mavkit_lib
    "base"
    ~internal_name:"mavryk_base"
    ~path:"src/lib_base"
    ~synopsis:"Meta-package and pervasive type definitions for Mavryk"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_crypto;
        data_encoding |> open_;
        mavkit_error_monad_legacy |> open_;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_rpc;
        mavkit_micheline |> open_;
        mavkit_event_logging |> open_;
        ptime;
        ptime_clock_os;
        mtime;
        ezjsonm;
        lwt;
        ipaddr;
        uri;
      ]
    ~js_compatible:true
    ~documentation:[Dune.[S "package"; S "mavkit-libs"]]
    ~dune:Dune.[ocamllex "point_parser"]
    ~ocaml:
      V.(
        (* TODO: https://gitlab.com/tezos/tezos/-/issues/6112
           Should be in sync with scripts/version.sh *)
        at_least "4.14.1" && less_than "4.15")
    ~license:"Apache-2.0"

let mavkit_base_unix =
  mavkit_lib
    "base.unix"
    ~internal_name:"mavryk_base_unix"
    ~path:"src/lib_base/unix"
    ~deps:
      [
        mavkit_error_monad |> open_;
        mavkit_crypto;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_hacl;
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix |> open_;
        data_encoding |> open_;
        uri;
        mavkit_event_logging |> open_;
      ]
    ~inline_tests:ppx_expect

let mavkit_base_p2p_identity_file =
  mavkit_lib
    "base.p2p-identity-file"
    ~internal_name:"mavryk_base_p2p_identity_file"
    ~path:"src/lib_base/p2p_identity_file"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_stdlib_unix |> open_]

let _mavkit_base_tests =
  tezt
    [
      "test_bounded";
      "test_time";
      "test_protocol";
      "test_p2p_addr";
      "test_sized";
      "test_skip_list";
    ]
    ~path:"src/lib_base/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_base |> open_;
        mavkit_error_monad |> open_;
        data_encoding;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
      ]
    ~dep_files:
      [
        (* Note: those files are only actually needed by test_p2p_addr. *)
        "points.ok";
        "points.ko";
      ]
    ~modes:[Native; JS]
    ~js_compatible:true

let _mavkit_base_unix_tests =
  tezt
    ["test_unix_error"; "test_syslog"; "test_simple_profiler"]
    ~path:"src/lib_base/unix/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-libs"
    ~modes:[Native]
    ~deps:
      [
        mavkit_base |> open_;
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_error_monad |> open_;
        data_encoding;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
        tezt_lib;
      ]

let mavkit_base_test_helpers =
  mavkit_lib
    "base-test-helpers"
    ~internal_name:"mavryk_base_test_helpers"
    ~path:"src/lib_base/test_helpers"
    ~synopsis:"Mavkit base test helpers"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix;
        mavkit_event_logging_test_helpers;
        mavkit_test_helpers |> open_;
        alcotezt;
        qcheck_alcotest;
      ]
    ~linkall:true
    ~bisect_ppx:No
    ~release_status:Released

let mavkit_context_sigs =
  mavkit_lib
    "context.sigs"
    ~internal_name:"mavryk_context_sigs"
    ~path:"src/lib_context/sigs"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_stdlib |> open_]
    ~js_compatible:true

let tree_encoding =
  mavkit_lib
    "tree-encoding"
    ~internal_name:"mavryk_tree_encoding"
    ~path:"src/lib_tree_encoding"
    ~synopsis:
      "A general-purpose library to encode arbitrary data in Merkle trees"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_context_sigs;
        mavkit_lwt_result_stdlib;
        data_encoding;
      ]

let lazy_containers =
  mavkit_lib
    "lazy-containers"
    ~internal_name:"mavryk_lazy_containers"
    ~path:"src/lib_lazy_containers"
    ~synopsis:
      "A collection of lazy containers whose contents is fetched from \
       arbitrary backend on-demand"
    ~deps:[zarith; tree_encoding]

let _lazy_containers_tests =
  tezt
    ["chunked_byte_vector_tests"; "lazy_vector_tests"]
    ~path:"src/lib_lazy_containers/test"
    ~opam:"mavryk-lazy-containers-tests"
    ~synopsis:"Various tests for the lazy containers library"
    ~deps:
      [
        lazy_containers |> open_;
        qcheck_core;
        qcheck_alcotest;
        lwt_unix;
        alcotezt;
      ]

let mavkit_webassembly_interpreter =
  mavkit_l2_lib
    "webassembly-interpreter"
    ~internal_name:"mavryk_webassembly_interpreter"
    ~path:"src/lib_webassembly"
    ~dune:Dune.[[S "include_subdirs"; S "unqualified"]]
    ~deps:
      [
        mavkit_lwt_result_stdlib;
        mavkit_stdlib;
        mavkit_error_monad;
        zarith;
        lazy_containers |> open_;
      ]
    ~preprocess:[pps ppx_deriving_show]

let mavkit_webassembly_interpreter_extra =
  mavkit_l2_lib
    "webassembly-interpreter-extra"
    ~internal_name:"mavryk_webassembly_interpreter_extra"
    ~path:"src/lib_webassembly/extra"
    ~license:"Apache-2.0"
    ~extra_authors:["WebAssembly Authors"]
    ~synopsis:"Additional modules from the WebAssembly REPL used in testing"
    ~dune:
      Dune.[[S "include_subdirs"; S "unqualified"]; [S "include"; S "dune.inc"]]
    ~deps:
      [
        mavkit_webassembly_interpreter |> open_;
        lwt_unix;
        lazy_containers |> open_;
      ]

let _mavkit_webassembly_repl =
  private_exe
    "main"
    ~path:"src/lib_webassembly/bin"
    ~opam:""
    ~dune:Dune.[[S "include"; S "dune.inc"]]
    ~deps:
      [
        mavkit_webassembly_interpreter |> open_;
        mavkit_webassembly_interpreter_extra |> open_;
        lwt_unix;
        tree_encoding |> open_;
        lazy_containers |> open_;
      ]

let _mavkit_webassembly_test =
  tezt
    ["smallint"]
    ~path:"src/lib_webassembly/tests"
    ~opam:"mavkit-l2-libs"
    ~dune:Dune.[[S "include_subdirs"; S "no"]]
    ~deps:[mavkit_webassembly_interpreter |> open_; alcotezt]

let mavkit_version_parser =
  mavkit_lib
    "version.parser"
    ~internal_name:"mavryk_version_parser"
    ~path:"src/lib_version/parser"
    ~dune:Dune.[ocamllex "mavryk_version_parser"]
    ~js_compatible:true
    ~preprocess:[pps ppx_deriving_show]

let mavkit_version =
  mavkit_lib
    "version"
    ~internal_name:"mavryk_version"
    ~path:"src/lib_version"
    ~synopsis:"Version information generated from Git"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_version_parser]
    ~js_compatible:true

let mavkit_version_value =
  public_lib
    "mavkit-version.value"
    ~internal_name:"mavryk_version_value"
    ~path:"src/lib_version/value/"
    ~synopsis:"Mavryk: version value generated from Git"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_version;
        mavkit_version_parser;
      ]
    ~js_compatible:true
      (* We want generated_git_info.cmi to be compiled with -opaque so
         that a change in the implementation doesn't force rebuilding all
         the reverse dependencies. *)
    ~flags:(Flags.standard ~opaque:true ())
    ~dune:
      Dune.
        [
          (* Ensures the hash updates whenever a source file is modified. *)
          targets_rule
            ["generated_git_info.ml"]
            ~deps:[[S "universe"]]
            ~action:[S "run"; S "../exe/get_git_info.exe"];
        ]

let _mavkit_version_get_git_info =
  private_exe
    "get_git_info"
    ~path:"src/lib_version/exe"
    ~opam:"mavkit-version"
    ~deps:[dune_configurator; mavkit_version_parser]
    ~modules:["get_git_info"]
    ~bisect_ppx:No

let mavkit_print_version =
  public_lib
    "mavkit-version.print"
    ~path:"src/lib_version/print"
    ~deps:[mavkit_version |> open_; mavkit_version_value |> open_]

let _mavkit_print_version_exe =
  public_exe
    "mavkit-version"
    ~internal_name:"mavkit_print_version"
    ~path:"src/lib_version/exe"
    ~opam:"mavkit-version"
    ~deps:
      [
        mavkit_version_value |> open_;
        mavkit_version |> open_;
        mavkit_base_unix;
        mavkit_print_version |> open_;
      ]
    ~modules:["mavkit_print_version"]
    ~bisect_ppx:No

let _etherlink_print_version_exe =
  public_exe
    "etherlink-version"
    ~internal_name:"etherlink_print_version"
    ~path:"src/lib_version/exe"
    ~opam:"mavkit-version"
    ~deps:
      [
        mavkit_version_value |> open_;
        mavkit_version |> open_;
        mavkit_base_unix;
        mavkit_print_version |> open_;
      ]
    ~modules:["etherlink_print_version"]
    ~bisect_ppx:No

let _mavkit_version_tests =
  tezt
    ["test_parser"]
    ~path:"src/lib_version/test"
    ~opam:"mavkit-libs"
    ~js_compatible:true
    ~modes:[Native; JS]
    ~deps:[mavkit_version |> open_; mavkit_version_parser]

let mavkit_p2p_services =
  mavkit_lib
    "mavryk-p2p-services"
    ~path:"src/lib_p2p_services"
    ~synopsis:"Descriptions of RPCs exported by [mavryk-p2p]"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_rpc]
    ~linkall:true
    ~js_compatible:true

let mavkit_workers =
  mavkit_lib
    "mavryk-workers"
    ~path:"src/lib_workers"
    ~synopsis:"Worker library"
    ~documentation:
      Dune.[[S "package"; S "mavkit-libs"]; [S "mld_files"; S "mavryk_workers"]]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_stdlib_unix |> open_;
      ]

let _mavkit_workers_tests =
  tezt
    ["mocked_worker"; "test_workers_unit"]
    ~path:"src/lib_workers/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives"
        |> open_ ~m:"Worker_types";
        mavkit_workers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        alcotezt;
      ]

let mavkit_merkle_proof_encoding =
  mavkit_lib
    "mavryk-context.merkle_proof_encoding"
    ~path:"src/lib_context/merkle_proof_encoding"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib |> open_;
        mavkit_context_sigs;
      ]
    ~js_compatible:true

let mavkit_shell_services =
  mavkit_shell_lib
    "shell-services"
    ~internal_name:"mavryk_shell_services"
    ~path:"src/lib_shell_services"
    ~synopsis:"Descriptions of RPCs exported by [mavryk-shell]"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_rpc;
        mavkit_p2p_services |> open_;
        mavkit_version |> open_;
        mavkit_context_sigs;
        mavkit_merkle_proof_encoding;
        mavkit_dal_config |> open_;
      ]
    ~linkall:true
    ~js_compatible:true

let _mavkit_shell_services_tests =
  tezt
    ["test_block_services"]
    ~path:"src/lib_shell_services/test"
    ~opam:"mavkit-shell-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_shell_services |> open_;
        alcotezt;
      ]
    ~modes:[Native; JS]
    ~js_compatible:true

let mavkit_p2p =
  mavkit_shell_lib
    "p2p"
    ~internal_name:"mavryk_p2p"
    ~path:"src/lib_p2p"
    ~synopsis:"Library for a pool of P2P connections"
    ~deps:
      [
        lwt_watcher;
        lwt_canceler;
        ringo;
        aches;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_p2p_services |> open_;
        mavkit_version;
        prometheus;
        mavkit_base_p2p_identity_file |> open_;
      ]

let tezt_performance_regression =
  public_lib
    "tezt-mavryk.tezt-performance-regression"
    ~path:"tezt/lib_performance_regression"
    ~opam:"tezt-mavryk"
    ~bisect_ppx:No
    ~deps:[tezt_wrapper |> open_ |> open_ ~m:"Base"; uri; cohttp_lwt_unix]

let tezt_mavryk =
  public_lib
    "tezt-mavryk"
    ~path:"tezt/lib_tezos"
    ~opam:"tezt-mavryk"
    ~synopsis:"Mavkit test framework based on Tezt"
    ~bisect_ppx:No
    ~deps:
      [
        tezt_wrapper |> open_ |> open_ ~m:"Base";
        tezt_performance_regression |> open_;
        uri;
        hex;
        mavkit_crypto_dal;
        mavkit_base;
        mavkit_base_unix;
        cohttp_lwt_unix;
      ]
    ~conflicts:[Conflicts.stdcompat]
    ~cram:true
    ~release_status:Released

let mavkit_p2p_test_common =
  mavkit_shell_lib
    "p2p_test_common"
    ~internal_name:"mavryk_p2p_test_common"
    ~path:"src/lib_p2p/test/common"
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_p2p |> open_;
        mavkit_p2p_services |> open_;
      ]

let _mavkit_p2p_tezt =
  tezt
    [
      "test_p2p_fd";
      "test_p2p_socket";
      "test_p2p_conn";
      "test_p2p_node";
      "test_p2p_pool";
    ]
    ~path:"src/lib_p2p/tezt"
    ~opam:"mavkit-shell-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_p2p |> open_;
        mavkit_p2p_services |> open_;
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_event_logging_test_helpers |> open_;
        mavkit_p2p_test_common |> open_;
      ]

let _mavkit_p2p_tests =
  tests
    [
      "test_p2p_socket";
      "test_p2p_broadcast";
      "test_p2p_io_scheduler";
      "test_p2p_peerset";
      "test_p2p_buffer_reader";
      "test_p2p_banned_peers";
      "test_p2p_connect_handler";
      "test_p2p_maintenance";
    ]
    ~bisect_ppx:With_sigterm
    ~path:"src/lib_p2p/test"
    ~opam:"mavkit-shell-libs"
    ~locks:"/locks/p2p"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_p2p |> open_;
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_event_logging_test_helpers |> open_;
        mavkit_p2p_test_common |> open_;
        mavkit_p2p_services |> open_;
        tezt_mavryk;
        tezt_lib;
        alcotezt;
        astring;
      ]

let _tezt_self_tests =
  tezt
    ["test_michelson_script"; "test_daemon"]
    ~opam:"tezt-mavryk"
    ~path:"tezt/self_tests"
    ~deps:[tezt_lib |> open_ |> open_ ~m:"Base"; tezt_mavryk |> open_]

let mavkit_gossipsub =
  mavkit_lib
    "mavryk-gossipsub"
    ~path:"src/lib_gossipsub"
    ~deps:
      [
        ringo;
        aches;
        fmt;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_version;
      ]

let _mavkit_gossipsub_test =
  test
    "test_gossipsub"
    ~path:"src/lib_gossipsub/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        fmt;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_gossipsub |> open_;
        tezt_lib;
        qcheck_core;
        mavkit_test_helpers |> open_;
      ]

let mavkit_wasmer =
  mavkit_l2_lib
    "wasmer"
    ~internal_name:"mavryk_wasmer"
    ~path:"src/lib_wasmer"
    ~synopsis:"Wasmer bindings for SCORU WASM"
    ~deps:[ctypes; ctypes_foreign; lwt; lwt_unix; tezos_rust_lib]
    ~preprocess:[pps ppx_deriving_show]
    ~flags:(Flags.standard ~disable_warnings:[9; 27] ())
    ~ctypes:
      Ctypes.
        {
          external_library_name = "wasmer";
          include_header = "wasmer.h";
          extra_search_dir = "%{env:OPAM_SWITCH_PREFIX=}/lib/tezos-rust-libs";
          type_description = {instance = "Types"; functor_ = "Api_types_desc"};
          function_description =
            {instance = "Functions"; functor_ = "Api_funcs_desc"};
          generated_types = "Api_types";
          generated_entry_point = "Api";
          c_flags = ["-Wno-incompatible-pointer-types"];
          c_library_flags = [];
          deps = [];
        }

let _mavkit_wasmer_test =
  tezt
    ["test_wasmer"]
    ~path:"src/lib_wasmer/test"
    ~opam:"mavkit-l2-libs"
    ~deps:[mavkit_wasmer; alcotezt]

let mavkit_context_encoding =
  mavkit_lib
    "mavryk-context.encoding"
    ~path:"src/lib_context/encoding"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib |> open_;
        irmin;
        irmin_pack;
      ]
    ~conflicts:[Conflicts.checkseum]

let mavkit_context_helpers =
  mavkit_lib
    "mavryk-context.helpers"
    ~path:"src/lib_context/helpers"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib |> open_;
        mavkit_context_encoding;
        mavkit_context_sigs;
        mavkit_merkle_proof_encoding;
        irmin;
        irmin_pack;
      ]
    ~conflicts:[Conflicts.checkseum]

let mavkit_context_memory =
  mavkit_lib
    "mavryk-context.memory"
    ~path:"src/lib_context/memory"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib |> open_;
        irmin_pack;
        irmin_pack_mem;
        mavkit_context_sigs;
        mavkit_context_encoding;
        mavkit_context_helpers;
      ]
    ~conflicts:[Conflicts.checkseum]

let mavkit_scoru_wasm =
  mavkit_l2_lib
    "scoru-wasm"
    ~internal_name:"mavryk_scoru_wasm"
    ~path:"src/lib_scoru_wasm"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        lazy_containers;
        mavkit_webassembly_interpreter;
        mavkit_context_sigs;
        mavkit_context_memory;
        mavkit_lwt_result_stdlib;
        data_encoding;
      ]

let mavkit_scoru_wasm_fast =
  mavkit_l2_lib
    "scoru-wasm-fast"
    ~internal_name:"mavryk_scoru_wasm_fast"
    ~path:"src/lib_scoru_wasm/fast"
    ~synopsis:"WASM functionality for SCORU Fast Execution"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_webassembly_interpreter;
        lazy_containers;
        mavkit_scoru_wasm;
        mavkit_wasmer;
      ]

let mavkit_context_dump =
  mavkit_lib
    "mavryk-context.dump"
    ~path:"src/lib_context/dump"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavkit_stdlib_unix |> open_; fmt]

let mavkit_context_disk =
  mavkit_lib
    "mavryk-context.disk"
    ~path:"src/lib_context/disk"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        bigstringaf;
        fmt;
        irmin;
        irmin_pack;
        irmin_pack_unix;
        logs_fmt;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_context_sigs;
        mavkit_context_helpers;
        mavkit_context_encoding;
        mavkit_context_memory;
        mavkit_context_dump;
      ]
    ~conflicts:[Conflicts.checkseum]

let _tree_encoding_tests =
  tezt
    ["test_proofs"; "test_encoding"]
    ~path:"src/lib_tree_encoding/test"
    ~opam:"mavryk-tree-encoding-test"
    ~synopsis:"Tests for the tree encoding library"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_webassembly_interpreter;
        qcheck_alcotest;
        alcotezt;
      ]

let mavkit_context =
  mavkit_lib
    "mavryk-context"
    ~path:"src/lib_context"
    ~synopsis:"On-disk context abstraction for [mavkit-node]"
    ~deps:[mavkit_context_disk; mavkit_context_memory]

let _mavkit_context_tests =
  tezt
    ["test_context"; "test_merkle_proof"]
    ~path:"src/lib_context/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_context_sigs;
        mavkit_context_disk;
        mavkit_context_memory;
        mavkit_context_encoding;
        mavkit_stdlib_unix |> open_;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
      ]

let _mavkit_context_memory_tests =
  tezt
    ["test"]
    ~path:"src/lib_context/memory/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_context_memory;
        mavkit_stdlib_unix |> open_;
        alcotezt;
      ]

let _irmin_tests =
  tezt
    ["tezt_main"; "test_lib_irmin_store"; "test_utils"]
    ~path:"irmin/test"
    ~opam:"mavryk_internal_irmin_tests"
    ~synopsis:"Mavryk internal irmin tests"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_context_sigs;
        mavkit_context_disk;
        mavkit_context_memory;
        mavkit_context_encoding;
        irmin_test_helpers;
        mavkit_stdlib_unix |> open_;
        mavkit_test_helpers |> open_;
        tezt_lib |> open_ |> open_ ~m:"Base";
      ]

(* This binding assumes that librustzcash.a is installed in the system default
   directories or in: $OPAM_SWITCH_PREFIX/lib

   Tests are disabled in the .opam because the tests require zcash parameter files. *)
let mavkit_sapling =
  mavkit_lib
    "mavryk-sapling"
    ~path:"src/lib_sapling"
    ~deps:
      [
        conf_rust;
        integers;
        integers_stubs_js;
        ctypes;
        ctypes_stubs_js;
        data_encoding;
        mavkit_stdlib |> open_;
        mavkit_crypto;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        tezos_rust_lib;
        tezos_sapling_parameters;
        mavkit_lwt_result_stdlib;
      ]
    ~js_of_ocaml:[[S "javascript_files"; S "runtime.js"]]
    ~foreign_stubs:
      {
        language = C;
        flags =
          [S ":standard"; S "-I%{env:OPAM_SWITCH_PREFIX=}/lib/tezos-rust-libs"];
        names = ["rustzcash_ctypes_c_stubs"];
      }
    ~c_library_flags:
      [
        "-L%{env:OPAM_SWITCH_PREFIX=}/lib/tezos-rust-libs";
        "-lrustzcash";
        "-lpthread";
      ]
    ~dune:
      Dune.
        [
          [S "copy_files"; S "bindings/rustzcash_ctypes_bindings.ml"];
          [
            S "rule";
            [S "target"; S "runtime.js"];
            [S "deps"; [S ":gen"; S "./bindings/gen_runtime_js.exe"]];
            [
              S "action";
              [S "with-stdout-to"; S "%{target}"; run "%{gen}" ["%{target}"]];
            ];
          ];
          [
            S "rule";
            [
              S "targets";
              S "rustzcash_ctypes_stubs.ml";
              S "rustzcash_ctypes_c_stubs.c";
            ];
            [S "deps"; [S ":gen"; S "./bindings/rustzcash_ctypes_gen.exe"]];
            [S "action"; run "%{gen}" ["%{targets}"]];
          ];
        ]

let _mavkit_sapling_tests =
  tezt
    [
      "test_rustzcash";
      "test_keys";
      "test_merkle";
      "test_roots";
      "test_sapling";
      "keys";
      "example";
    ]
    ~path:"src/lib_sapling/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-libs"
    ~dep_files:["vectors.csv"; "vectors-zip32.csv"]
    ~deps:
      [
        mavkit_sapling |> open_;
        mavkit_crypto;
        str;
        mavkit_base;
        mavkit_base_unix;
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix;
        data_encoding |> open_;
        mavkit_base_test_helpers |> open_;
        alcotezt;
      ]
    ~dune_with_test:Never

let _mavkit_sapling_js_tests =
  test
    "test_js"
    ~path:"src/lib_sapling/test"
    ~opam:"mavkit-libs"
    ~deps:[mavkit_sapling; mavkit_hacl]
    ~modules:["test_js"]
    ~linkall:true
    ~modes:[JS]
    ~js_compatible:true
    ~dune_with_test:Never

let _mavkit_sapling_ctypes_gen =
  private_exes
    ["rustzcash_ctypes_gen"; "gen_runtime_js"]
    ~path:"src/lib_sapling/bindings"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[ctypes_stubs; ctypes]
    ~modules:
      ["rustzcash_ctypes_gen"; "rustzcash_ctypes_bindings"; "gen_runtime_js"]

let mavryk_protocol_environment_sigs_internals =
  mavkit_proto_lib
    "protocol-environment.sigs-internals"
    ~internal_name:"mavryk_protocol_environment_sigs_internals"
    ~path:"src/lib_protocol_environment/sigs-internals"

let mavryk_protocol_environment_sigs =
  mavkit_proto_lib
    "protocol-environment.sigs"
    ~internal_name:"mavryk_protocol_environment_sigs"
    ~path:"src/lib_protocol_environment/sigs"
    ~deps:[mavryk_protocol_environment_sigs_internals]
    ~flags:(Flags.standard ~nopervasives:true ~nostdlib:true ())
    ~dune:
      (let gen n =
         Dune.(
           targets_rule
             [sf "v%d.ml" n]
             ~deps:
               [
                 Dune.(S (sf "v%d.in.ml" n));
                 Dune.(H [[S "glob_files"; S (sf "v%n/*.mli" n)]]);
               ]
             ~promote:true
             ~action:
               [
                 S "with-stdout-to";
                 S "%{targets}";
                 [
                   S "run";
                   S "%{dep:../ppinclude/ppinclude.exe}";
                   S (sf "v%d.in.ml" n);
                 ];
               ])
       in
       let latest_environment_number = 12 in
       List.init (latest_environment_number + 1) gen |> Dune.of_list)

let mavkit_protocol_environment_structs =
  mavkit_proto_lib
    "protocol-environment.structs"
    ~internal_name:"mavryk_protocol_environment_structs"
    ~path:"src/lib_protocol_environment/structs"
    ~deps:
      [
        mavkit_stdlib;
        mavkit_crypto;
        mavkit_lwt_result_stdlib;
        mavkit_scoru_wasm;
        data_encoding;
        mavryk_bls12_381;
        mavkit_plonk |> open_;
      ]

let mavkit_protocol_environment =
  mavkit_proto_lib
    "protocol-environment"
    ~internal_name:"mavryk_protocol_environment"
    ~path:"src/lib_protocol_environment"
    ~documentation:[Dune.[S "package"; S "mavkit-proto-libs"]]
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        zarith;
        zarith_stubs_js;
        mavryk_bls12_381;
        mavkit_plonk |> open_;
        mavkit_crypto_dal;
        vdf;
        aches;
        aches_lwt;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_sapling;
        mavryk_protocol_environment_sigs;
        mavkit_protocol_environment_structs;
        mavkit_micheline |> open_;
        mavkit_context_memory;
        mavkit_scoru_wasm;
        mavkit_event_logging;
      ]

let mavkit_shell_context =
  mavkit_shell_lib
    "shell-context"
    ~internal_name:"mavryk_shell_context"
    ~path:"src/lib_protocol_environment/shell_context"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_protocol_environment;
        mavkit_context;
      ]

let _mavkit_protocol_environment_tests =
  tezt
    [
      "test_mem_context";
      "test_mem_context_array_theory";
      "test_mem_context_common";
      "test_cache";
      "test_data_encoding";
    ]
    ~path:"src/lib_protocol_environment/test"
    ~opam:"mavkit-proto-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_protocol_environment |> open_;
        alcotezt;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        lwt_unix;
      ]

let mavkit_context_ops =
  mavkit_shell_lib
    "context-ops"
    ~internal_name:"mavryk_context_ops"
    ~path:"src/lib_protocol_environment/context_ops"
    ~synopsis:"Backend-agnostic operations on contexts"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_error_monad |> open_;
        mavkit_protocol_environment;
        mavkit_context |> open_;
        mavkit_shell_context |> open_;
      ]

let _mavkit_protocol_shell_context_tests =
  tezt
    ["test_proxy_context"]
    ~path:"src/lib_protocol_environment/test_shell_context"
    ~opam:"mavkit-shell-libs"
    ~deps:
      [
        mavkit_shell_context;
        alcotezt;
        mavkit_test_helpers |> open_;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_protocol_environment |> open_;
      ]

let mavkit_protocol_compiler_registerer =
  public_lib
    "mavkit-protocol-compiler.registerer"
    ~path:"src/lib_protocol_compiler/registerer"
    ~internal_name:"mavryk_protocol_registerer"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavryk_protocol_environment_sigs]
    ~flags:(Flags.standard ~opaque:true ())

let _mavkit_protocol_compiler_cmis_of_cma =
  private_exe
    "cmis_of_cma"
    ~path:"src/lib_protocol_compiler/bin"
    ~opam:"mavkit-protocol-compiler"
    ~deps:[compiler_libs_common]
    ~modules:["cmis_of_cma"]

let mavkit_protocol_compiler_lib =
  public_lib
    "mavkit-protocol-compiler"
    ~path:"src/lib_protocol_compiler"
    ~synopsis:"Mavryk: economic-protocol compiler"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix |> open_;
        mavryk_protocol_environment_sigs;
        mavkit_stdlib_unix |> open_;
        compiler_libs_common;
        lwt_unix;
        ocplib_ocamlres;
        unix;
      ]
    ~conflicts:[Conflicts.stdcompat]
    ~opam_only_deps:[mavkit_protocol_environment]
    ~modules:
      [
        "Embedded_cmis_env";
        "Embedded_cmis_register";
        "Packer";
        "Compiler";
        "Defaults";
        "Protocol_compiler_env";
      ]
    ~dune:
      Dune.
        [
          target_rule
            "protocol_compiler_env.ml"
            ~action:
              [
                S "copy";
                S "compat_files/protocol_compiler_env_ocaml4.ml";
                S "%{target}";
              ]
            ~enabled_if:[S "<"; S "%{ocaml_version}"; S "5"];
          target_rule
            "protocol_compiler_env.ml"
            ~action:
              [
                S "copy";
                S "compat_files/protocol_compiler_env_ocaml5.ml";
                S "%{target}";
              ]
            ~enabled_if:[S ">="; S "%{ocaml_version}"; S "5"];
          targets_rule
            ["embedded-interfaces-env"]
            ~deps:[Dune.(H [[S "package"; S "mavkit-proto-libs"]])]
            ~action:
              [
                S "with-stdout-to";
                S "%{targets}";
                [
                  S "run";
                  S "bin/cmis_of_cma.exe";
                  V
                    [
                      S
                        "%{lib:mavkit-proto-libs.protocol-environment.sigs:mavryk_protocol_environment_sigs.cmxa}";
                    ];
                ];
              ];
          targets_rule
            ["embedded_cmis_env.ml"]
            ~deps:[Dune.(H [[S "package"; S "mavkit-proto-libs"]])]
            ~action:
              [
                S "run";
                G
                  [
                    S "%{bin:ocp-ocamlres}";
                    S "-format";
                    S "variants";
                    S "-o";
                    S "%{targets}";
                  ];
                S "%{read-strings:embedded-interfaces-env}";
              ];
          targets_rule
            ["embedded_cmis_register.ml"]
            ~action:
              [
                S "run";
                G
                  [
                    S "%{bin:ocp-ocamlres}";
                    S "-format";
                    S "variants";
                    S "-o";
                    S "%{targets}";
                  ];
                S "%{cmi:registerer/mavryk_protocol_registerer}";
              ];
          targets_rule
            ["defaults.ml"]
            ~action:
              [
                S "write-file";
                S "%{targets}";
                S
                  (sf
                     "let warnings = %S"
                     ("+a"
                     ^ Flags.disabled_warnings_to_string
                         warnings_disabled_by_default));
              ];
        ]

let mavkit_protocol_compiler_native =
  public_lib
    "mavkit-protocol-compiler.native"
    ~path:"src/lib_protocol_compiler"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_protocol_compiler_lib |> open_;
        compiler_libs_optcomp;
      ]
    ~modules:["Native"]
    ~dune:
      Dune.
        [
          install
            [V [S "final_protocol_versions"]]
            ~package:"mavkit-protocol-compiler"
            ~section:"libexec";
        ]

let mavkit_protocol_updater =
  mavkit_shell_lib
    "protocol-updater"
    ~internal_name:"mavryk_protocol_updater"
    ~path:"src/lib_protocol_updater"
    ~synopsis:"Economic-protocol dynamic loading for `mavkit-node`"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        mavkit_micheline |> open_;
        mavkit_shell_services |> open_;
        mavkit_protocol_environment;
        mavkit_shell_context;
        mavkit_protocol_compiler_registerer;
        mavkit_protocol_compiler_native;
        mavkit_context |> open_;
        lwt_exit;
        dynlink;
      ]

let mavkit_validation =
  mavkit_shell_lib
    "validation"
    ~internal_name:"mavryk_validation"
    ~path:"src/lib_validation"
    ~synopsis:"Library for block validation"
    ~time_measurement_ppx:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_crypto |> open_;
        mavkit_rpc;
        mavkit_context |> open_;
        mavkit_context_ops |> open_;
        mavkit_shell_context |> open_;
        mavkit_shell_services |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_version_value;
      ]

let mavkit_store_shared =
  mavkit_shell_lib
    "store.shared"
    ~internal_name:"mavryk_store_shared"
    ~path:"src/lib_store/shared"
    ~deps:
      [
        mavkit_stdlib_unix |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_crypto |> open_;
        mavkit_shell_services |> open_;
        aches;
        aches_lwt;
        mavkit_validation |> open_;
      ]
    ~modules:
      [
        "naming";
        "block_repr";
        "store_types";
        "store_events";
        "block_key";
        "block_level";
      ]

let mavkit_store_unix =
  mavkit_shell_lib
    "store.unix"
    ~internal_name:"mavryk_store_unix"
    ~path:"src/lib_store/unix"
    ~deps:
      [
        mavkit_shell_services |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_version;
        index;
        irmin_pack;
        mavkit_store_shared |> open_;
        mavkit_protocol_environment |> open_;
        mavkit_context |> open_;
        mavkit_context_ops |> open_;
        mavkit_shell_context;
        mavkit_validation |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_crypto |> open_;
        lwt_watcher;
        aches;
        aches_lwt;
        camlzip;
        tar;
        tar_unix;
        prometheus;
      ]
    ~modules:
      [
        "block_repr_unix";
        "block_store";
        "cemented_block_store";
        "consistency";
        "floating_block_index";
        "floating_block_store";
        "protocol_store";
        "store_metrics";
        "store";
      ]
    ~conflicts:[Conflicts.checkseum]

let mavkit_store_unix_reconstruction =
  mavkit_shell_lib
    "store.unix-reconstruction"
    ~internal_name:"mavryk_store_unix_reconstruction"
    ~path:"src/lib_store/unix"
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        mavkit_crypto |> open_;
        mavkit_shell_services |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_validation |> open_;
        mavkit_context_ops |> open_;
        mavkit_store_shared |> open_;
        mavkit_store_unix |> open_;
      ]
    ~modules:["reconstruction"; "reconstruction_events"]

let mavkit_store_unix_snapshots =
  mavkit_shell_lib
    "store.unix-snapshots"
    ~internal_name:"mavryk_store_unix_snapshots"
    ~path:"src/lib_store/unix"
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        mavkit_crypto |> open_;
        mavkit_shell_services |> open_;
        mavkit_context |> open_;
        mavkit_validation |> open_;
        mavkit_store_shared |> open_;
        mavkit_store_unix |> open_;
      ]
    ~modules:["snapshots"; "snapshots_events"]

let mavkit_store =
  mavkit_shell_lib
    "store"
    ~internal_name:"mavryk_store"
    ~path:"src/lib_store"
    ~synopsis:"Store for `mavkit-node`"
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_crypto |> open_;
        mavkit_rpc;
        lwt_watcher;
        mavkit_shell_services |> open_;
        mavkit_validation |> open_;
        mavkit_context_ops |> open_;
        mavkit_store_shared |> open_;
      ]
    ~virtual_modules:["store"]
    ~default_implementation:"mavkit-shell-libs.store.real"

let _mavkit_store_real =
  mavkit_shell_lib
    "store.real"
    ~internal_name:"mavryk_store_real"
    ~path:"src/lib_store/real"
    ~deps:[mavkit_store_unix |> open_]
    ~implements:mavkit_store

let _mavkit_store_mocked =
  mavkit_shell_lib
    "mocked"
    ~path:"src/lib_store/mocked"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_crypto |> open_;
        mavkit_shell_services |> open_;
        mavkit_context_memory |> open_;
        mavkit_context_ops |> open_;
        mavkit_validation |> open_;
        mavkit_protocol_environment;
        mavkit_store_shared |> open_;
      ]
    ~private_modules:["block_store"; "protocol_store"; "stored_data"]
    ~implements:mavkit_store

let mavkit_requester =
  mavkit_lib
    "requester"
    ~internal_name:"mavryk_requester"
    ~path:"src/lib_requester"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        lwt_watcher;
      ]

let mavkit_requester_tests =
  tezt
    ["requester_impl"; "test_requester"; "test_fuzzing_requester"; "shared"]
    ~path:"src/lib_requester/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix;
        mavkit_requester |> open_;
        alcotezt;
        qcheck_alcotest;
      ]

let mavkit_shell =
  mavkit_shell_lib
    "shell"
    ~internal_name:"mavryk_shell"
    ~path:"src/lib_shell"
    ~synopsis:
      "Core of `mavkit-node` (gossip, validation scheduling, mempool, ...)"
    ~documentation:
      Dune.
        [
          [S "package"; S "mavkit-shell-libs"]; [S "mld_files"; S "mavkit_shell"];
        ]
    ~inline_tests:ppx_expect
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        lwt_watcher;
        lwt_canceler;
        prometheus;
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_base_unix |> open_;
        mavkit_rpc;
        mavkit_context |> open_;
        mavkit_store |> open_;
        mavkit_store_shared |> open_;
        mavkit_protocol_environment |> open_;
        mavkit_context_ops |> open_;
        mavkit_shell_context |> open_;
        mavkit_p2p |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_shell_services |> open_;
        mavkit_p2p_services |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_requester |> open_;
        mavkit_workers |> open_;
        mavkit_validation |> open_;
        mavkit_version |> open_;
        mavkit_dal_config |> open_;
        lwt_exit;
      ]

let mavkit_rpc_http =
  mavkit_lib
    "rpc-http"
    ~internal_name:"mavryk-rpc-http"
    ~path:"src/lib_rpc_http"
    ~synopsis:"Library of auto-documented RPCs (http server and client)"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavkit_rpc; resto_cohttp; uri]
    ~modules:["RPC_client_errors"; "media_type"]

let mavkit_rpc_http_client =
  mavkit_lib
    "rpc-http-client"
    ~internal_name:"mavryk-rpc-http-client"
    ~path:"src/lib_rpc_http"
    ~synopsis:"Library of auto-documented RPCs (http client)"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        resto_cohttp_client;
        mavkit_rpc;
        mavkit_rpc_http |> open_;
      ]
    ~modules:["RPC_client"]

let mavkit_rpc_http_client_unix =
  mavkit_lib
    "rpc-http-client-unix"
    ~internal_name:"mavryk_rpc_http_client_unix"
    ~path:"src/lib_rpc_http"
    ~synopsis:"Unix implementation of the RPC client"
    ~deps:
      [
        mavkit_stdlib_unix;
        mavkit_base |> open_ ~m:"TzPervasives";
        cohttp_lwt_unix;
        resto_cohttp_client;
        mavkit_rpc;
        mavkit_rpc_http_client |> open_;
      ]
    ~modules:["RPC_client_unix"]

let mavkit_rpc_http_server =
  mavkit_lib
    "rpc-http-server"
    ~internal_name:"mavryk_rpc_http_server"
    ~path:"src/lib_rpc_http"
    ~synopsis:"Library of auto-documented RPCs (http server)"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        cohttp_lwt_unix;
        resto_cohttp_server;
        resto_acl;
        mavkit_rpc;
        mavkit_rpc_http |> open_;
      ]
    ~modules:["RPC_server"; "RPC_middleware"]

let _mavkit_rpc_http_server_tests =
  tezt
    ["test_rpc_http"]
    ~path:"src/lib_rpc_http/test"
    ~opam:"mavkit-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix;
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_rpc_http_server |> open_;
        qcheck_alcotest;
        alcotezt;
      ]

let mavkit_client_base =
  mavkit_shell_lib
    "client-base"
    ~internal_name:"mavryk_client_base"
    ~path:"src/lib_client_base"
    ~synopsis:"Mavryk: common helpers for `mavkit-client`"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_clic;
        mavkit_rpc;
        mavkit_shell_services |> open_;
        mavkit_sapling;
        uri;
      ]
    ~modules:[":standard"; "bip39_english"]
    ~linkall:true
    ~js_compatible:true
    ~dune:
      Dune.
        [
          targets_rule
            ["bip39_english.ml"]
            ~deps:
              [
                [S ":exe"; S "gen/bip39_generator.exe"];
                S "gen/bip39_english.txt";
              ]
            ~action:[S "run"; S "%{exe}"; S "%{targets}"];
        ]

let _mavkit_client_base_tests =
  tezt
    ["bip39_tests"; "pbkdf_tests"]
    ~path:"src/lib_client_base/test"
    ~opam:"mavkit-shell-libs"
    ~with_macos_security_framework:true
    ~deps:[mavkit_base; mavkit_client_base |> open_; alcotezt]
    ~js_compatible:true
    ~modes:[Native; JS]

let _bip39_generator =
  private_exe
    "bip39_generator"
    ~path:"src/lib_client_base/gen"
    ~opam:"mavkit-shell-libs"
    ~bisect_ppx:No

let mavkit_signer_services =
  mavkit_shell_lib
    "signer-services"
    ~internal_name:"mavryk_signer_services"
    ~path:"src/lib_signer_services"
    ~synopsis:"Mavryk: descriptions of RPCs exported by `mavryk-signer`"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_rpc;
        mavkit_client_base |> open_;
      ]
    ~linkall:true
    ~js_compatible:true

let mavkit_signer_backends =
  mavkit_shell_lib
    "signer-backends"
    ~internal_name:"mavryk_signer_backends"
    ~path:"src/lib_signer_backends"
    ~synopsis:"Mavryk: remote-signature backends for `mavkit-client`"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib |> open_;
        mavkit_client_base |> open_;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_client |> open_;
        mavkit_signer_services |> open_;
        mavkit_shell_services |> open_;
        uri;
      ]

let _mavkit_signer_backends_tests =
  tezt
    ["test_encrypted"]
    ~path:"src/lib_signer_backends/test"
    ~opam:"mavkit-shell-libs"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base;
        mavkit_base_unix;
        mavkit_stdlib |> open_;
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_crypto;
        mavkit_client_base |> open_;
        mavkit_signer_backends |> open_;
        alcotezt;
        uri;
      ]

let mavkit_signer_backends_unix =
  mavkit_shell_lib
    "signer-backends.unix"
    ~internal_name:"mavryk_signer_backends_unix"
    ~path:"src/lib_signer_backends/unix"
    ~deps:
      [
        ocplib_endian_bigstring;
        fmt;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_clic;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_client_base |> open_;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_client |> open_;
        mavkit_rpc_http_client_unix |> open_;
        mavkit_signer_services |> open_;
        mavkit_signer_backends |> open_;
        mavkit_shell_services |> open_;
        uri;
        select
          ~package:ledgerwallet_tezos
          ~source_if_present:"ledger.available.ml"
          ~source_if_absent:"ledger.none.ml"
          ~target:"ledger.ml";
      ]

let _mavkit_signer_backends_unix_tests =
  tezt
    ["test_crouching"]
    ~path:"src/lib_signer_backends/unix/test"
    ~opam:"mavkit-shell-libs"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_error_monad |> open_;
        mavkit_stdlib |> open_;
        mavkit_crypto;
        mavkit_client_base |> open_;
        mavkit_signer_backends_unix |> open_;
        alcotezt;
      ]

let mavkit_client_commands =
  mavkit_shell_lib
    "client-commands"
    ~internal_name:"mavryk_client_commands"
    ~path:"src/lib_client_commands"
    ~synopsis:"Mavryk: protocol agnostic commands for `mavkit-client`"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_rpc;
        mavkit_clic;
        mavkit_clic_unix |> open_;
        mavkit_client_base |> open_;
        mavkit_shell_services |> open_;
        mavkit_p2p_services |> open_;
        mavkit_stdlib_unix;
        mavkit_base_unix |> open_;
        mavkit_signer_backends;
        data_encoding |> open_;
        uri;
      ]
    ~linkall:true

let mavkit_mockup_registration =
  mavkit_shell_lib
    "mockup-registration"
    ~internal_name:"mavryk_mockup_registration"
    ~path:"src/lib_mockup"
    ~synopsis:"Mavryk: protocol registration for the mockup mode"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_client_base;
        mavkit_shell_services;
        mavkit_protocol_environment;
        uri;
      ]
    ~modules:["registration"; "registration_intf"; "mockup_args"]

let mavkit_mockup_proxy =
  mavkit_shell_lib
    "mockup-proxy"
    ~internal_name:"mavryk_mockup_proxy"
    ~path:"src/lib_mockup_proxy"
    ~synopsis:"Mavryk: local RPCs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_client_base;
        mavkit_protocol_environment;
        mavkit_rpc_http;
        resto_cohttp_self_serving_client;
        mavkit_rpc_http_client;
        mavkit_shell_services;
        uri;
      ]

(* Depends on mavryk_p2p to register the relevant RPCs. *)
let mavkit_mockup =
  mavkit_shell_lib
    "mockup"
    ~internal_name:"mavryk_mockup"
    ~path:"src/lib_mockup"
    ~synopsis:"Mavryk: library of auto-documented RPCs (mockup mode)"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_client_base;
        mavkit_mockup_proxy;
        resto_cohttp_self_serving_client;
        mavkit_rpc;
        mavkit_p2p_services;
        mavkit_p2p;
        mavkit_protocol_environment;
        mavkit_stdlib_unix;
        mavkit_rpc_http;
        mavkit_rpc_http_client;
        mavkit_mockup_registration |> open_;
      ]
    ~modules:
      [
        "files";
        "local_services";
        "persistence";
        "persistence_intf";
        "RPC_client";
        "migration";
      ]

let mavkit_mockup_commands =
  mavkit_shell_lib
    "mockup-commands"
    ~internal_name:"mavryk_mockup_commands"
    ~path:"src/lib_mockup"
    ~synopsis:"Mavryk: library of auto-documented RPCs (commands)"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_clic;
        mavkit_client_commands;
        mavkit_client_base;
        mavkit_mockup |> open_;
        mavkit_mockup_registration |> open_;
      ]
    ~modules:["mockup_wallet"; "mockup_commands"]

let _mavkit_mockup_tests =
  tezt
    ["test_mockup_args"; "test_fuzzing_mockup_args"; "test_persistence"]
    ~path:"src/lib_mockup/test"
    ~opam:"mavkit-shell-libs"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_rpc;
        mavkit_mockup;
        mavkit_mockup_registration;
        mavkit_client_base;
        qcheck_alcotest;
        alcotezt;
      ]

let mavkit_proxy =
  mavkit_shell_lib
    "proxy"
    ~internal_name:"mavryk_proxy"
    ~path:"src/lib_proxy"
    ~synopsis:"Mavryk: proxy"
    ~deps:
      [
        aches;
        aches_lwt;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_clic;
        mavkit_client_base;
        mavkit_protocol_environment;
        mavkit_rpc;
        mavkit_shell_services;
        mavkit_context_memory;
        uri;
      ]

let mavkit_proxy_rpc =
  mavkit_shell_lib
    "proxy.rpc"
    ~internal_name:"mavryk_proxy_rpc"
    ~path:"src/lib_proxy/rpc"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_client_base;
        mavkit_mockup_proxy;
        mavkit_rpc;
        mavkit_proxy;
        uri;
      ]

let mavkit_proxy_test_helpers_shell_services =
  private_lib
    "mavryk_proxy_test_helpers_shell_services"
    ~path:"src/lib_proxy/test_helpers/shell_services"
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_shell_services;
        mavkit_test_helpers |> open_;
        qcheck_core;
        mavkit_context_memory;
        lwt_unix;
        alcotezt;
      ]
    ~bisect_ppx:No
    ~linkall:true
    ~release_status:Released

let _mavkit_shell_service_test_helpers_tests =
  tezt
    ["test_block_services"]
    ~path:"src/lib_proxy/test_helpers/shell_services/test"
    ~opam:"mavkit-shell-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_test_helpers |> open_;
        mavkit_shell_services;
        mavkit_proxy_test_helpers_shell_services;
        qcheck_alcotest;
        alcotezt;
      ]

let _mavkit_proxy_tests =
  tezt
    [
      "test_proxy";
      "test_fuzzing_proxy_getter";
      "test_light";
      "test_fuzzing_light";
      "light_lib";
    ]
    ~path:"src/lib_proxy/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-shell-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix;
        mavkit_proxy;
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_proxy_test_helpers_shell_services;
        qcheck_alcotest;
        alcotezt;
        uri;
      ]

let mavkit_proxy_server_config =
  public_lib
    "mavryk-proxy-server-config"
    ~path:"src/lib_proxy_server_config"
    ~synopsis:"Mavryk: proxy server configuration"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_stdlib_unix; uri]

let _mavkit_proxy_server_config_tests =
  tezt
    ["test_proxy_server_config"]
    ~path:"src/lib_proxy_server_config/test"
    ~opam:"mavryk-proxy-server-config"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_proxy_server_config;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
        uri;
      ]

let mavkit_client_base_unix =
  mavkit_shell_lib
    "client-base-unix"
    ~internal_name:"mavryk_client_base_unix"
    ~path:"src/lib_client_base_unix"
    ~synopsis:
      "Mavryk: common helpers for `mavkit-client` (unix-specific fragment)"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_clic;
        mavkit_rpc;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_client_unix |> open_;
        mavkit_shell_services |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_client_base |> open_;
        mavkit_client_commands |> open_;
        mavkit_mockup;
        mavkit_mockup_registration;
        mavkit_mockup_commands |> open_;
        mavkit_proxy;
        mavkit_proxy_rpc;
        mavkit_signer_backends_unix;
        mavkit_version_value;
        lwt_exit;
        uri;
      ]
    ~linkall:true

let _mavkit_client_base_unix_tests =
  tezt
    ["test_mockup_wallet"]
    ~path:"src/lib_client_base_unix/test"
    ~opam:"mavkit-shell-libs"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_mockup_commands;
        mavkit_client_base_unix;
        mavkit_base_test_helpers |> open_;
        alcotezt;
      ]

let mavkit_benchmark =
  public_lib
    "mavryk-benchmark"
    ~path:"src/lib_benchmark"
    ~synopsis:
      "Mavryk: library for writing benchmarks and performing simple parameter \
       inference"
    ~foreign_stubs:
      {language = C; flags = [S ":standard"]; names = ["snoop_stubs"]}
    ~private_modules:["builtin_models"; "builtin_benchmarks"]
    ~deps:
      [
        str;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        mavkit_crypto;
        mavkit_micheline;
        mavkit_clic;
        data_encoding;
        prbnmcn_linalg;
        prbnmcn_stats;
        pringo;
        pyml;
        ocamlgraph;
        ocaml_migrate_parsetree;
        opam_only "hashcons" V.True;
      ]
    ~inline_tests:ppx_expect
    ~inline_tests_deps:[S "%{workspace_root}/.ocamlformat"]
      (* We disable tests for this package as they require Python, which is not
           installed in the image of the opam jobs. *)
    ~opam_with_test:Never

let mavkit_benchmark_examples =
  public_lib
    "mavryk-benchmark-examples"
    ~path:"src/lib_benchmark/example"
    ~synopsis:"Mavryk: examples for lib-benchmarks"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix;
        mavkit_crypto;
        mavkit_benchmark;
      ]

let _mavkit_benchmark_tests =
  tezt
    [
      "test";
      "test_sparse_vec";
      "test_costlang";
      "test_model";
      "test_probe";
      "test_measure";
      "test_benchmark_helpers";
    ]
    ~path:"src/lib_benchmark/test"
    ~opam:"mavryk-benchmark-tests"
    ~synopsis:"Mavryk: tests for lib-benchmarks"
    ~deps:
      [
        alcotezt;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix;
        mavkit_micheline;
        mavkit_crypto;
        mavkit_benchmark;
        mavkit_benchmark_examples;
      ]

(* unused lib? *)
let mavkit_micheline_rewriting =
  public_lib
    "mavryk-micheline-rewriting"
    ~path:"src/lib_benchmark/lib_micheline_rewriting"
    ~synopsis:"Mavryk: library for rewriting Micheline expressions"
    ~deps:
      [
        zarith;
        zarith_stubs_js;
        mavkit_stdlib |> open_;
        mavkit_crypto;
        mavkit_error_monad |> open_;
        mavkit_micheline |> open_;
      ]

let mavkit_shell_benchmarks =
  mavkit_shell_lib
    "shell-benchmarks"
    ~internal_name:"mavryk_shell_benchmarks"
    ~path:"src/lib_shell_benchmarks"
    ~synopsis:"Mavryk: shell benchmarks"
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_error_monad |> open_;
        mavkit_benchmark |> open_;
        mavkit_crypto;
        mavkit_context;
        mavkit_shell_context;
        mavkit_store;
        mavkit_micheline;
      ]
    ~linkall:true
    ~foreign_stubs:{language = C; flags = []; names = ["alloc_mmap"]}

let octogram =
  public_lib
    "octogram"
    ~path:"src/lib_octogram"
    ~synopsis:"An Ansible-inspired environment to run scenarios and experiments"
    ~deps:
      [
        mavkit_shell_services |> open_;
        mavkit_rpc_http_client_unix |> open_;
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_ |> open_ ~m:"Runnable.Syntax";
        jingoo;
        dmap;
      ]

let _octogram_bin =
  public_exe
    "octogram"
    ~path:"src/bin_octogram"
    ~internal_name:"octogram_main"
    ~release_status:Unreleased
    ~opam:"octogram"
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_ |> open_ ~m:"Runnable.Syntax";
        octogram;
        yaml;
      ]

let mavkit_openapi =
  public_lib
    "mavryk-openapi"
    ~path:"src/lib_openapi"
    ~synopsis:
      "Mavryk: a library for querying RPCs and converting into the OpenAPI \
       format"
    ~deps:[ezjsonm; json_data_encoding; tezt_json_lib]

let _mavkit_protocol_compiler_bin =
  public_exe
    "mavkit-protocol-compiler"
    ~path:"src/lib_protocol_compiler/bin"
    ~opam:"mavkit-protocol-compiler"
    ~internal_name:"main_native"
    ~modes:[Native]
    ~deps:[mavkit_protocol_compiler_native; mavkit_version_value]
    ~linkall:true
    ~modules:["Main_native"]

let mavkit_protocol_compiler_mavryk_protocol_packer =
  public_exe
    "mavkit-protocol-compiler.mavkit-protocol-packer"
    ~path:"src/lib_protocol_compiler/bin"
    ~opam:"mavkit-protocol-compiler"
    ~internal_name:"main_packer"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_stdlib_unix |> open_;
        mavkit_protocol_compiler_lib |> open_;
      ]
    ~modules:["Main_packer"]

let _mavkit_embedded_protocol_packer =
  public_exe
    "mavkit-embedded-protocol-packer"
    ~path:"src/lib_protocol_compiler/bin"
    ~opam:"mavkit-protocol-compiler"
    ~internal_name:"main_embedded_packer"
    ~modes:[Native]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
      ]
    ~linkall:true
    ~modules:["Main_embedded_packer"]

let mavkit_layer2_store =
  mavkit_l2_lib
    "layer2_store"
    ~internal_name:"mavryk_layer2_store"
    ~path:"src/lib_layer2_store"
    ~synopsis:"layer2 storage utils"
    ~deps:
      [
        index;
        mavkit_base |> open_ ~m:"TzPervasives";
        irmin_pack;
        irmin_pack_unix;
        irmin;
        aches_lwt;
        mavkit_stdlib_unix |> open_;
        mavkit_context_encoding;
        mavkit_context_sigs;
        mavkit_context_helpers;
      ]
    ~linkall:true
    ~conflicts:[Conflicts.checkseum; Conflicts.stdcompat]

let _mavkit_layer2_indexed_store_test =
  tezt
    ["test_indexed_store"]
    ~path:"src/lib_layer2_store/test/"
    ~opam:"mavkit-l2-libs"
    ~deps:
      [
        mavkit_error_monad |> open_ |> open_ ~m:"TzLwtreslib";
        mavkit_layer2_store |> open_;
        qcheck_alcotest;
        alcotezt;
        tezt_lib;
      ]

let mavkit_dal_node_services =
  public_lib
    "mavryk-dal-node-services"
    ~path:"src/lib_dal_node_services"
    ~opam:"mavryk-dal-node-services"
    ~synopsis:"Mavryk: `mavryk-dal-node` RPC services"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_rpc;
        mavkit_crypto_dal;
      ]
    ~linkall:true

let mavkit_dal_node_lib =
  public_lib
    "mavryk-dal-node-lib"
    ~path:"src/lib_dal_node"
    ~opam:"mavryk-dal-node-lib"
    ~synopsis:"Mavryk: `mavryk-dal-node` library"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_dal_node_services;
        mavkit_client_base |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_client_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_crypto_dal |> open_;
        mavkit_p2p |> open_;
        mavkit_p2p_services |> open_;
      ]

let mavkit_dal_node_gossipsub_lib =
  public_lib
    "mavryk-dal-node-lib.gossipsub"
    ~path:"src/lib_dal_node/gossipsub"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_crypto_dal |> open_;
        mavkit_gossipsub |> open_;
        mavkit_p2p |> open_;
        mavkit_p2p_services |> open_;
        mavkit_dal_node_services |> open_;
        mavkit_crypto |> open_;
      ]

let mavkit_dac_lib =
  public_lib
    "mavryk-dac-lib"
    ~path:"src/lib_dac"
    ~opam:"mavryk-dac-lib"
    ~synopsis:"Mavryk: `mavryk-dac` library"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavkit_protocol_updater |> open_]

let mavkit_dac_client_lib =
  public_lib
    "mavryk-dac-client-lib"
    ~path:"src/lib_dac_client"
    ~opam:"mavryk-dac-client-lib"
    ~synopsis:"Mavryk: `mavryk-dac-client` library"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_dac_lib |> open_;
      ]

let mavkit_dac_node_lib =
  private_lib
    "mavryk_dac_node_lib"
    ~path:"src/lib_dac_node"
    ~opam:"mavryk-dac-node-lib"
    ~synopsis:"Mavryk: `mavryk-dac-node` library"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_layer2_store |> open_;
        mavkit_rpc_http_server;
        mavkit_dac_lib |> open_;
        mavkit_dac_client_lib |> open_;
      ]

let _mavkit_dac_node_lib_tests =
  tezt
    ["test_data_streamer"]
    ~path:"src/lib_dac_node/test"
    ~opam:"mavryk-dac-node-lib-test"
    ~synopsis:"Test for dac node lib"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_dac_node_lib |> open_;
        alcotezt;
      ]

let _mavkit_dac_lib_tests =
  tezt
    ["test_certificate"; "test_dac_plugin"; "test_dac_clic_helpers"]
    ~path:"src/lib_dac/test"
    ~opam:"mavryk-dac-lib-test"
    ~synopsis:"Test for dac lib"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_stdlib |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_test_helpers |> open_;
        mavkit_base_test_helpers |> open_;
        mavkit_dac_lib |> open_;
        alcotezt;
      ]

let mavkit_node_config =
  public_lib
    "mavkit-node-config"
    ~path:"src/lib_node_config"
    ~synopsis:"Mavkit: `mavkit-node-config` library"
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_base_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_shell_services |> open_;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server |> open_;
        mavkit_context |> open_;
        mavkit_store |> open_;
        mavkit_validation |> open_;
      ]

let mavkit_rpc_process =
  public_lib
    "mavkit-rpc-process"
    ~path:"src/lib_rpc_process"
    ~synopsis:"Mavryk: RPC process"
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_shell |> open_;
        mavkit_base_unix |> open_;
        mavkit_node_config |> open_;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server |> open_;
        lwt_unix;
        lwt_exit;
        prometheus_app;
      ]

let mavkit_crawler =
  public_lib
    "mavkit-crawler"
    ~internal_name:"mavkit_crawler"
    ~path:"src/lib_crawler"
    ~synopsis:"Mavkit: library to crawl blocks of the L1 chain"
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_rpc_http |> open_;
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_client_base |> open_;
        mavkit_shell;
      ]

let mavkit_injector_lib =
  public_lib
    "mavkit-injector"
    ~path:"src/lib_injector"
    ~synopsis:"Mavkit: library for building injectors"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        logs_lwt;
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_crypto;
        mavkit_micheline |> open_;
        mavkit_client_base |> open_;
        mavkit_workers |> open_;
        mavkit_shell;
        mavkit_crawler |> open_;
        mavkit_signer_backends;
      ]

let mavkit_smart_rollup_lib =
  mavkit_l2_lib
    "smart-rollup"
    ~internal_name:"mavkit_smart_rollup"
    ~path:"src/lib_smart_rollup"
    ~synopsis:"Library for Smart Rollups"
    ~documentation:[Dune.[S "package"; S "mavkit-l2-libs"]]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_crypto |> open_;
        mavkit_crypto_dal;
        yaml;
      ]

let mavkit_smart_rollup_node_lib =
  public_lib
    "mavkit-smart-rollup-node-lib"
    ~internal_name:"mavkit_smart_rollup_node"
    ~path:"src/lib_smart_rollup_node"
    ~synopsis:"Mavkit: library for Smart Rollup node"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives" |> open_;
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_crypto |> open_;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        cohttp_lwt_unix;
        mavkit_openapi;
        mavkit_node_config;
        prometheus_app;
        camlzip;
        tar;
        tar_unix;
        mavkit_dal_node_lib |> open_;
        mavkit_dac_lib |> open_;
        mavkit_dac_client_lib |> open_;
        mavkit_injector_lib |> open_;
        mavkit_version_value |> open_;
        mavkit_layer2_store |> open_;
        mavkit_crawler |> open_;
        mavkit_workers |> open_;
        mavkit_smart_rollup_lib |> open_;
      ]

let mavkit_scoru_wasm_helpers =
  mavkit_l2_lib
    "scoru-wasm-helpers"
    ~internal_name:"mavryk_scoru_wasm_helpers"
    ~path:"src/lib_scoru_wasm/helpers"
    ~synopsis:"Helpers for the smart rollup wasm functionality and debugger"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_fast;
        mavkit_webassembly_interpreter_extra |> open_;
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let mavkit_scoru_wasm_durable_snapshot =
  mavkit_l2_lib
    "scoru_wasm_durable_snapshot"
    ~internal_name:"mavryk_scoru_wasm_durable_snapshot"
    ~path:"src/lib_scoru_wasm/test/durable_snapshot"
    ~synopsis:"Durable storage reference implementation"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_webassembly_interpreter_extra |> open_;
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let mavkit_scoru_wasm_tests_helpers =
  mavkit_l2_lib
    "scoru_wasm_test_helpers"
    ~internal_name:"mavryk_scoru_wasm_test_helpers"
    ~path:"src/lib_scoru_wasm/test/helpers"
    ~synopsis:"Helpers for test of the smart rollup wasm functionality"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_durable_snapshot;
        mavkit_scoru_wasm_fast;
        mavkit_scoru_wasm_helpers;
        qcheck_alcotest;
        alcotezt;
        mavkit_webassembly_interpreter_extra |> open_;
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let mavkit_scoru_wasm_benchmark =
  mavkit_l2_lib
    "smart_rollup_wasm_benchmark_lib"
    ~internal_name:"mavkit_smart_rollup_wasm_benchmark_lib"
    ~path:"src/lib_scoru_wasm/bench"
    ~synopsis:"Smart Rollup WASM benchmark library"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tezt_lib;
        mavkit_webassembly_interpreter;
        mavkit_context_memory;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_helpers;
        lwt_unix;
      ]
    ~preprocess:[pps ppx_deriving_show]

let _mavkit_scoru_wasm_benchmark_exe =
  private_exe
    "mavkit_smart_rollup_wasm_benchmark"
    ~path:"src/lib_scoru_wasm/bench/executable"
    ~opam:"mavkit-l2-libs"
    ~preprocess:[pps ppx_deriving_show]
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; mavkit_scoru_wasm_benchmark]

let _mavkit_scoru_wasm_tests =
  tezt
    [
      "test_ast_generators";
      "test_debug";
      (* TODO: https://gitlab.com/tezos/tezos/-/issues/5028
         Beware: there is a weird test failure when
         Durable snapshot test doesn't go first *)
      "test_durable_shapshot";
      "test_durable_storage";
      "test_fixed_nb_ticks";
      "test_get_set";
      "test_hash_consistency";
      "test_host_functions_ticks";
      "test_init";
      "test_input";
      "test_output";
      "test_parser_encoding";
      "test_protocol_migration";
      "test_reveal";
      "test_wasm_encoding";
      "test_wasm_pvm_encodings";
      "test_wasm_pvm";
      "test_wasm_vm";
    ]
    ~path:"src/lib_scoru_wasm/test"
    ~opam:"mavkit-l2-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_scoru_wasm;
        qcheck_alcotest;
        alcotezt;
        mavkit_scoru_wasm_helpers |> open_;
        mavkit_scoru_wasm_tests_helpers |> open_;
        mavkit_webassembly_interpreter_extra |> open_;
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let _mavkit_scoru_wasm_fast_tests =
  tezt
    [
      "gen";
      "partial_memory";
      "qcheck_helpers";
      "test_fast_cache";
      "test_fast";
      "test_memory_access";
    ]
    ~path:"src/lib_scoru_wasm/fast/test"
    ~opam:"mavkit-l2-libs"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tree_encoding;
        mavkit_base_unix;
        mavkit_context_disk;
        mavkit_base_test_helpers |> open_;
        mavkit_scoru_wasm_helpers |> open_;
        mavkit_scoru_wasm_tests_helpers |> open_;
        mavkit_test_helpers |> open_;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_fast;
        qcheck_alcotest;
        alcotezt;
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

(* PROTOCOL PACKAGES *)

module Protocol : sig
  type number = Alpha | V of int | Other

  (** Status of the protocol on Mainnet.

      - [Active]: the protocol is the current protocol on Mainnet, is being proposed,
        or was active recently and was not deleted or frozen yet.
        Or, it is protocol Alpha.
      - [Frozen]: the protocol is an old protocol of Mainnet which was frozen
        (its tests, daemons etc. have been removed).
      - [Overridden]: the protocol has been replaced using a user-activated protocol override.
      - [Not_mainnet]: this protocol was never on Mainnet (e.g. demo protocols). *)
  type status = Active | Frozen | Overridden | Not_mainnet

  type t

  val number : t -> number

  val short_hash : t -> string

  val status : t -> status

  val name_dash : t -> string

  val name_underscore : t -> string

  val main : t -> target

  val embedded : t -> target

  (** [embedded] does not fail, it's just that the optional version
      composes better with [all_optionally]. *)
  val embedded_opt : t -> target option

  val client : t -> target option

  val client_exn : t -> target

  val client_commands_exn : t -> target

  val client_commands_registration : t -> target option

  val baking_commands_registration : t -> target option

  val plugin : t -> target option

  val plugin_exn : t -> target

  val plugin_registerer : t -> target option

  val dal : t -> target option

  val dac : t -> target option

  val parameters_exn : t -> target

  val benchmarks_proto_exn : t -> target

  val mavkit_sc_rollup : t -> target option

  val mavkit_sc_rollup_node : t -> target option

  val mavkit_injector : t -> target option

  val baking_exn : t -> target

  val test_helpers_exn : t -> target

  val genesis : t

  val demo_noops : t

  val alpha : t

  (** List of all protocols. *)
  val all : t list

  (** List of active protocols. *)
  val active : t list

  (** Get packages to link.

      This takes a function that selects packages from a protocol.
      For instance, the node wants the embedded protocol and the plugin registerer,
      while the client wants the client commands etc.

      The result is the list of all such packages that exist.
      All of them are optional dependencies. *)
  val all_optionally : (t -> target option) list -> target list
end = struct
  type number = Alpha | V of int | Other

  module Name : sig
    type t

    (** [alpha] is a protocol name with protocol number [Alpha] *)
    val alpha : t

    (** [v name num] constuct a protocol name with protocol number [V num] *)
    val v : string -> int -> t

    (** [other name] constuct a protocol name with protocol number [Other] *)
    val other : string -> t

    val number : t -> number

    val name_underscore : t -> string

    val name_dash : t -> string

    val base_path : t -> string

    val short_hash : t -> string
  end = struct
    type t = {
      short_hash : string;
      name_underscore : string;
      name_dash : string;
      number : number;
    }

    let make name number =
      if
        not
          (String.for_all
             (function
               | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' -> true | _ -> false)
             name)
      then
        invalid_arg
          (sf
             "Protocol.Name.make: %s is not a valid protocol name: should be \
              of the form [A-Za-z0-9-]+"
             name) ;
      let make_full_name sep name =
        match number with
        | Alpha | Other -> name
        | V number -> sf "%03d%c%s" number sep name
      in
      let name_dash = make_full_name '-' name in
      let name_underscore =
        make_full_name '_' (String.map (function '-' -> '_' | c -> c) name)
      in
      {short_hash = name; number; name_dash; name_underscore}

    let v name number = make name (V number)

    let alpha = make "alpha" Alpha

    let other name = make name Other

    let short_hash t = t.short_hash

    let number t = t.number

    let name_underscore t = t.name_underscore

    let name_dash t = t.name_dash

    let base_path t = Format.sprintf "src/proto_%s" (name_underscore t)
  end

  type status = Active | Frozen | Overridden | Not_mainnet

  type t = {
    status : status;
    name : Name.t;
    main : target;
    embedded : target;
    client : target option;
    client_commands : target option;
    client_commands_registration : target option;
    baking_commands_registration : target option;
    plugin : target option;
    plugin_registerer : target option;
    dal : target option;
    dac : target option;
    test_helpers : target option;
    parameters : target option;
    benchmarks_proto : target option;
    baking : target option;
    mavkit_sc_rollup : target option;
    mavkit_sc_rollup_node : target option;
    mavkit_injector : target option;
  }

  let make ?client ?client_commands ?client_commands_registration
      ?baking_commands_registration ?plugin ?plugin_registerer ?dal ?dac
      ?test_helpers ?parameters ?benchmarks_proto ?mavkit_sc_rollup
      ?mavkit_sc_rollup_node ?mavkit_injector ?baking ~status ~name ~main
      ~embedded () =
    {
      status;
      name;
      main;
      embedded;
      client;
      client_commands;
      client_commands_registration;
      baking_commands_registration;
      plugin;
      plugin_registerer;
      dal;
      dac;
      test_helpers;
      parameters;
      benchmarks_proto;
      baking;
      mavkit_sc_rollup;
      mavkit_sc_rollup_node;
      mavkit_injector;
    }

  let all_rev : t list ref = ref []

  (* Add to the [Protocol.add] list used to link in the node, client, etc.
     Returns the protocol for easier composability. *)
  let register protocol =
    all_rev := protocol :: !all_rev ;
    protocol

  let mandatory what {main; _} = function
    | None ->
        failwith
          ("protocol " ^ name_for_errors main ^ " has no " ^ what ^ " package")
    | Some x -> x

  let number p = Name.number p.name

  let short_hash p = Name.short_hash p.name

  let status p = p.status

  let name_dash p = Name.name_dash p.name

  let name_underscore p = Name.name_underscore p.name

  let main p = p.main

  let embedded p = p.embedded

  let embedded_opt p = Some p.embedded

  let client p = p.client

  let client_exn p = mandatory "client" p p.client

  let client_commands_exn p = mandatory "client-commands" p p.client_commands

  let client_commands_registration p = p.client_commands_registration

  let baking_commands_registration p = p.baking_commands_registration

  let plugin p = p.plugin

  let plugin_exn p = mandatory "plugin" p p.plugin

  let plugin_registerer p = p.plugin_registerer

  let dal p = p.dal

  let dac p = p.dac

  let parameters_exn p = mandatory "parameters" p p.parameters

  let benchmarks_proto_exn p = mandatory "benchmarks_proto" p p.benchmarks_proto

  let baking_exn p = mandatory "baking" p p.baking

  let mavkit_sc_rollup p = p.mavkit_sc_rollup

  let mavkit_sc_rollup_node p = p.mavkit_sc_rollup_node

  let mavkit_injector p = p.mavkit_injector

  let test_helpers_exn p = mandatory "test_helpers" p p.test_helpers

  (* N as in "protocol number in the Alpha family". *)
  module N = struct
    (* This function is asymmetrical on purpose: we don't want to compare
       numbers with [Alpha] because such comparisons would break when snapshotting.
       So the left-hand side is the number of the protocol being built,
       but the right-hand side is an integer.

       We could instead have defined functions with one argument [number_le], [number_ge],
       [version_ne] and [version_eq] in [register_alpha_family] directly.
       We chose to use a module instead because [number_le 001] is not as readable as
       [N.(number <= 001)]. Indeed, is [number_le 001] equivalent to [(<=) 001],
       meaning "greater than 001", or is [number_le 001] equivalent to [fun x -> x <= 001],
       meaning the opposite? *)
    let compare_asymmetric a b =
      match a with
      | Alpha -> 1
      | V a -> Int.compare a b
      | Other ->
          invalid_arg "cannot use N.compare_asymmetric on Other protocols"

    let ( <= ) a b = compare_asymmetric a b <= 0

    let ( >= ) a b = compare_asymmetric a b >= 0

    let ( == ) a b = compare_asymmetric a b == 0
  end

  let only_if condition make = if condition then Some (make ()) else None

  let conditional_list =
    List.filter_map (fun (x, b) -> if b then Some x else None)

  let error_monad_module should_use_infix =
    if should_use_infix then open_ ~m:"TzPervasives.Error_monad_legacy"
    else fun target -> target

  module Lib_protocol = struct
    type t = {main : target; lifted : target; embedded : target}

    let make_tests ?test_helpers ?parameters ?plugin ?client ?benchmark
        ?benchmark_type_inference ?mavkit_sc_rollup ~main ~name () =
      let name_dash = Name.name_dash name in
      let number = Name.number name in
      let path = Name.base_path name in
      let _integration_consensus =
        tezt
          [
            "test_baking";
            "test_consensus_key";
            "test_deactivation";
            "test_delegation";
            "test_double_baking";
            (if N.(number >= 001) then "test_double_attestation"
            else "test_double_endorsement");
            (if N.(number >= 001) then "test_double_preattestation"
            else "test_double_preendorsement");
            (if N.(number >= 001) then "test_attestation"
            else "test_endorsement");
            "test_frozen_deposits";
            "test_helpers_rpcs";
            "test_participation";
            (if N.(number >= 001) then "test_preattestation_functor"
            else "test_preendorsement_functor");
            (if N.(number >= 001) then "test_preattestation"
            else "test_preendorsement");
            "test_seed";
          ]
          ~path:(path // "lib_protocol/test/integration/consensus")
          ~with_macos_security_framework:true
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~deps:
            [
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
              parameters |> if_some |> open_;
              plugin |> if_some |> open_;
            ]
      in
      let _integration_gas =
        tezt
          ["test_gas_costs"; "test_gas_levels"]
          ~path:(path // "lib_protocol/test/integration/gas")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~deps:
            [
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
            ]
      in
      let _integration_michelson =
        let modules =
          [
            ("test_annotations", true);
            ("test_block_time_instructions", true);
            ("test_contract_event", true);
            ("test_global_constants_storage", true);
            ("test_interpretation", true);
            ("test_lazy_storage_diff", true);
            ("test_patched_contracts", true);
            ("test_sapling", true);
            ("test_script_cache", true);
            ("test_script_typed_ir_size", true);
            ("test_temp_big_maps", true);
            ("test_ticket_accounting", true);
            ("test_ticket_balance_key", true);
            ("test_ticket_balance", true);
            ("test_ticket_lazy_storage_diff", true);
            ("test_ticket_manager", true);
            ("test_ticket_operations_diff", true);
            ("test_ticket_scanner", true);
            ("test_ticket_storage", true);
            ("test_ticket_direct_spending", N.(number >= 002));
            ("test_typechecking", true);
            ("test_lambda_normalization", N.(number >= 001));
          ]
          |> conditional_list
        in
        tezt
          modules
          ~path:(path // "lib_protocol/test/integration/michelson")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~dep_globs:
            (conditional_list
               [
                 ("contracts/*", true);
                 ("patched_contracts/*", N.(number >= 001));
               ])
          ~dep_globs_rec:
            (conditional_list
               [
                 ( "../../../../../../michelson_test_scripts/*",
                   N.(number >= 001) );
               ])
          ~deps:
            [
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
              client |> if_some |> open_;
              mavkit_benchmark;
              mavkit_micheline |> open_;
              benchmark |> if_some |> open_;
              benchmark_type_inference |> if_some |> open_;
              plugin |> if_some |> open_;
              parameters |> if_some |> if_ N.(number >= 001);
            ]
      in
      let _integration_operations =
        let modules =
          [
            ("test_activation", true);
            ("test_combined_operations", true);
            ("test_failing_noop", true);
            ("test_origination", true);
            ("test_paid_storage_increase", true);
            ("test_reveal", true);
            ("test_sc_rollup_transfer", N.(number >= 001));
            ("test_sc_rollup", N.(number >= 001));
            ("test_transfer", true);
            ("test_voting", true);
            ("test_zk_rollup", true);
            ("test_transfer_ticket", N.(number >= 001));
          ]
          |> conditional_list
        in
        tezt
          modules
          ~path:(path // "lib_protocol/test/integration/operations")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~dep_globs:(conditional_list [("contracts/*", N.(number >= 001))])
          ~deps:
            [
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_;
              client |> if_some |> if_ N.(number >= 001) |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
              plugin |> if_some |> open_;
            ]
      in
      let _integration_validate =
        only_if N.(number >= 001) @@ fun () ->
        tezt
          [
            "generator_descriptors";
            "generators";
            "manager_operation_helpers";
            "test_1m_restriction";
            "test_covalidity";
            "test_manager_operation_validation";
            "test_mempool";
            "test_sanity";
            "test_validation_batch";
            "valid_operations_generators";
            "validate_helpers";
          ]
          ~path:(path // "lib_protocol/test/integration/validate")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~deps:
            [
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_;
              qcheck_alcotest;
              client |> if_some |> open_;
              mavkit_test_helpers |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
              parameters |> if_some |> if_ N.(number >= 002) |> open_;
              plugin |> if_some |> open_;
            ]
      in
      let _integration =
        let modules =
          [
            ("test_constants", true);
            ("test_frozen_bonds", true);
            ("test_adaptive_issuance_launch", N.(number >= 001));
            ( "test_adaptive_issuance_roundtrip",
              N.(number == 001 || number == 002) );
            ("test_scenario_base", N.(number >= 003));
            ("test_scenario_stake", N.(number >= 003));
            ("test_scenario_rewards", N.(number >= 003));
            ("test_scenario_autostaking", N.(number >= 003));
            ("test_scenario_slashing", N.(number >= 003));
            ("test_scenario_slashing_stakers", N.(number >= 003));
            ("test_scenario_deactivation", N.(number >= 003));
            ("test_liquidity_baking", false);
            ("test_storage_functions", true);
            ("test_storage", true);
            ("test_token", true);
          ]
          |> conditional_list
        in
        tezt
          modules
          ~path:(path // "lib_protocol/test/integration")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~deps:
            [
              (if N.(number >= 001) then Some tezt_lib else None) |> if_some;
              mavkit_context;
              alcotezt;
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              client |> if_some |> open_;
              main |> open_;
              parameters |> if_some |> open_;
              test_helpers |> if_some |> open_;
              mavkit_base_test_helpers |> open_;
            ]
          ~dep_globs:(if N.(number >= 001) then ["wasm_kernel/*.wasm"] else [])
      in
      let _pbt =
        let list =
          [
            ("liquidity_baking_pbt", false);
            ("saturation_fuzzing", true);
            ("test_merkle_list", N.(number >= 001));
            ("test_gas_properties", true);
            ("test_sampler", N.(number >= 001));
            ("test_script_comparison", true);
            ("test_script_roundtrip", N.(number >= 002));
            ("test_tez_repr", true);
            ("test_bitset", N.(number >= 001));
            ("test_sc_rollup_tick_repr", N.(number >= 001));
            ("test_sc_rollup_encoding", N.(number >= 001));
            ("test_sc_rollup_inbox", N.(number >= 001));
            ("test_refutation_game", N.(number >= 001));
            ("test_carbonated_map", N.(number >= 001));
            ("test_zk_rollup_encoding", N.(number >= 001));
            ("test_dal_slot_proof", N.(number >= 001));
            ("test_compare_operations", N.(number >= 001));
            ("test_operation_encoding", N.(number >= 001));
            ("test_balance_updates_encoding", N.(number >= 001));
            ("test_bytes_conversion", N.(number >= 001));
          ]
          |> conditional_list
        in
        tezt
          list
          ~synopsis:"Mavryk/Protocol: tests for economic-protocol definition"
          ~path:(path // "lib_protocol/test/pbt")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~deps:
            [
              mavkit_base |> if_ N.(number >= 001) |> open_ ~m:"TzPervasives";
              mavkit_micheline |> open_;
              client |> if_some |> open_;
              main |> open_;
              mavkit_merkle_proof_encoding;
              mavkit_test_helpers |> open_;
              test_helpers |> if_some |> open_;
              alcotezt;
              qcheck_alcotest;
              mavkit_benchmark;
              benchmark |> if_some |> open_;
              benchmark_type_inference |> if_some |> open_;
              mavkit_sc_rollup |> if_some |> if_ N.(number >= 001) |> open_;
              mavkit_crypto_dal |> if_ N.(number >= 001) |> open_;
              mavkit_base_test_helpers |> if_ N.(number >= 001) |> open_;
              parameters |> if_some |> if_ N.(number >= 001) |> open_;
            ]
      in
      let _unit =
        let modules =
          [
            ("test_bond_id_repr", true);
            ("test_consensus_key", true);
            ("test_contract_repr", true);
            ("test_destination_repr", true);
            ("test_fitness", true);
            ("test_fixed_point", true);
            ("test_gas_monad", true);
            ("test_global_constants_storage", true);
            ("test_level_module", true);
            ("test_liquidity_baking_repr", true);
            ("test_merkle_list", true);
            ("test_operation_repr", true);
            ("test_qty", true);
            ("test_receipt", true);
            ("test_round_repr", true);
            ("test_saturation", true);
            ("test_sc_rollup_arith", N.(number >= 001));
            ("test_sc_rollup_game", N.(number >= 001));
            ("test_sc_rollup_inbox", N.(number >= 001));
            ("test_sc_rollup_management_protocol", N.(number >= 001));
            ("test_sc_rollup_storage", N.(number >= 001));
            ("test_skip_list_repr", true);
            ("test_tez_repr", true);
            ("test_time_repr", true);
            ("test_zk_rollup_storage", true);
            ("test_sc_rollup_inbox_legacy", N.(number >= 001));
            ("test_sc_rollup_wasm", N.(number >= 001));
            ("test_local_contexts", N.(number >= 001));
            ("test_dal_slot_proof", N.(number >= 001));
            ("test_adaptive_issuance", N.(number >= 001));
            ("test_adaptive_issuance_ema", N.(number >= 001));
            ("test_percentage", N.(number >= 002));
            ("test_full_staking_balance_repr", N.(number >= 003));
            ("test_slashing_percentage", N.(number >= 003));
          ]
          |> conditional_list
        in
        tezt
          modules
          ~path:(path // "lib_protocol/test/unit")
          ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
          ~with_macos_security_framework:true
          ~deps:
            [
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              mavkit_base_test_helpers |> open_;
              mavkit_micheline |> open_;
              client |> if_some |> open_;
              mavkit_client_base;
              parameters |> if_some |> open_if N.(number >= 001);
              mavkit_protocol_environment;
              mavkit_stdlib_unix;
              main |> open_;
              mavkit_test_helpers |> open_;
              test_helpers |> if_some |> open_;
              alcotezt;
              mavkit_scoru_wasm_helpers |> if_ N.(number >= 001) |> open_;
              mavkit_stdlib |> if_ N.(number >= 001) |> open_;
              mavkit_crypto_dal |> if_ N.(number >= 001) |> open_;
              mavkit_scoru_wasm;
              mavkit_webassembly_interpreter_extra
              |> if_ N.(number >= 001)
              |> open_;
            ]
      in
      let _regresssion =
        if N.(number >= 001) then
          (* About [~dep_globs]: this is only needed so that dune re-runs the tests
             if those files are modified. Dune will also copy those files in [_build],
             but the test uses absolute paths to find those files
             (thanks to [DUNE_SOURCEROOT] and [Filename.dirname __FILE__]),
             so those copies are not actually used. This is needed so that the test
             can be run either with [dune build @runtest],
             with [dune exec src/proto_alpha/lib_protocol/test/regression/main.exe],
             or with [dune exec tezt/tests/main.exe -- -f test_logging.ml]. *)
          let _ =
            tezt
              ["test_logging"]
              ~path:(path // "lib_protocol/test/regression")
              ~with_macos_security_framework:true
              ~opam:(sf "mavryk-protocol-%s-tests" name_dash)
              ~deps:
                [
                  mavkit_base |> open_ ~m:"TzPervasives";
                  tezt_mavryk |> open_;
                  main |> open_;
                  client |> if_some |> open_;
                  plugin |> if_some |> open_;
                  test_helpers |> if_some |> open_;
                  mavkit_micheline |> open_;
                ]
              ~dep_globs:["contracts/*.mv"; "expected/test_logging.ml/*.out"]
          in
          ()
      in
      ()

    let make ~name ~status =
      let name_underscore = Name.name_underscore name in
      let name_dash = Name.name_dash name in
      let number = Name.number name in
      let path = Name.base_path name in
      let dirname = path // "lib_protocol" in
      let mavryk_protocol_filename = dirname // "MAVRYK_PROTOCOL" in
      let mavryk_protocol =
        Mavryk_protocol.of_file_exn mavryk_protocol_filename
      in
      (* Container of the registered sublibraries of [mavkit-protocol-libs] *)
      let registered_mavryk_protocol = Sub_lib.make_container () in
      let mavryk_protocol_sub_lib =
        Sub_lib.sub_lib
          ~package_synopsis:(sf "Mavryk protocol %s package" name_dash)
          ~container:registered_mavryk_protocol
          ~package:(sf "mavryk-protocol-%s" name_dash)
      in
      let modules_as_deps =
        let basenames_of_module module_ =
          [".ml"; ".mli"]
          |> List.filter_map (fun ext ->
                 let basename = String.uncapitalize_ascii module_ ^ ext in
                 if Sys.file_exists (dirname // basename) then Some basename
                 else None)
        in
        let s_expr =
          mavryk_protocol.Mavryk_protocol.modules
          |> List.map (fun module_ ->
                 match basenames_of_module module_ with
                 | _ :: _ as basenames -> Dune.(G (of_atom_list basenames))
                 | [] ->
                     failwith
                       (sf
                          "In %s a module %s was declared, but no \
                           corresponding .ml or .mli files were found in \
                           directory %s"
                          mavryk_protocol_filename
                          module_
                          dirname))
          |> Dune.of_list
        in
        Dune.V s_expr
      in
      let disable_warnings =
        match number with
        (* [Other] and [Alpha] protocols can be edited and should be
           fixed whenever a warning that we care about triggers. We
           only want to disable a limited set of warnings *)
        | Other | Alpha -> []
        (* [V _] protocols can't be edited to accomodate warnings, we need to disable warnings instead. *)
        | V _ as number ->
            if N.(number >= 001) then []
            else if N.(number >= 001) then [51]
            else [6; 7; 9; 16; 29; 32; 51; 68]
      in
      let environment =
        mavryk_protocol_sub_lib
          "protocol.environment"
          ~internal_name:(sf "mavryk_protocol_environment_%s" name_underscore)
          ~path:(path // "lib_protocol")
          ~modules:[sf "Mavryk_protocol_environment_%s" name_underscore]
          ~linkall:true
          ~deps:[mavkit_protocol_environment]
          ~dune:
            Dune.
              [
                targets_rule
                  [sf "mavryk_protocol_environment_%s.ml" name_underscore]
                  ~action:
                    [
                      S "write-file";
                      S "%{targets}";
                      S
                        (sf
                           {|module Name = struct let name = "%s" end
include Mavryk_protocol_environment.V%d.Make(Name)()
|}
                           name_dash
                           mavryk_protocol.expected_env_version);
                    ];
              ]
      in
      let raw_protocol =
        mavryk_protocol_sub_lib
          "protocol.raw"
          ~internal_name:(sf "mavryk_raw_protocol_%s" name_underscore)
          ~path:(path // "lib_protocol")
          ~linkall:true
          ~modules:mavryk_protocol.modules
          ~flags:
            (Flags.standard
               ~nopervasives:true
               ~nostdlib:true
               ~disable_warnings
               ())
          ~deps:
            [
              environment |> open_ |> open_ ~m:"Pervasives"
              |> open_ ~m:"Error_monad";
            ]
      in
      let main =
        mavryk_protocol_sub_lib
          "protocol"
          ~internal_name:(sf "mavryk_protocol-%s" name_dash)
          ~path:(path // "lib_protocol")
          ~synopsis:
            (match number with
            | Other ->
                sf
                  "Mavryk/Protocol: %s economic-protocol definition"
                  name_underscore
            | Alpha | V _ -> "Mavryk/Protocol: economic-protocol definition")
          ~modules:["Protocol"; sf "Mavryk_protocol_%s" name_underscore]
          ~flags:(Flags.standard ~nopervasives:true ~disable_warnings ())
          ~deps:
            [
              mavkit_protocol_environment;
              mavryk_protocol_environment_sigs;
              raw_protocol;
            ]
          ~conflicts:
            (match number with
            | Other -> []
            | Alpha | V _ -> [Conflicts.stdcompat])
          ~dune:
            Dune.
              [
                install
                  [as_ "MAVRYK_PROTOCOL" "protocol/raw/MAVRYK_PROTOCOL"]
                  ~package:(sf "mavryk-protocol-%s" name_dash)
                  ~section:"lib";
                targets_rule
                  ["protocol.ml"]
                  ~action:
                    [
                      S "write-file";
                      S "%{targets}";
                      S
                        (sf
                           {|
let hash = Mavryk_crypto.Hashed.Protocol_hash.of_b58check_exn "%s"
let name = Mavryk_protocol_environment_%s.Name.name
include Mavryk_raw_protocol_%s
include Mavryk_raw_protocol_%s.Main
|}
                           mavryk_protocol.hash
                           name_underscore
                           name_underscore
                           name_underscore);
                    ];
                targets_rule
                  [sf "mavryk_protocol_%s.ml" name_underscore]
                  ~action:
                    [
                      S "write-file";
                      S "%{targets}";
                      S
                        (sf
                           {|
module Environment = Mavryk_protocol_environment_%s
module Protocol = Protocol
|}
                           name_underscore);
                    ];
                alias_rule
                  "runtest_compile_protocol"
                  ~deps_dune:
                    [modules_as_deps; [S ":src_dir"; S "MAVRYK_PROTOCOL"]]
                  ~action:
                    [
                      S "run";
                      S "%{bin:mavkit-protocol-compiler}";
                      (if
                       String_set.mem
                         mavryk_protocol.Mavryk_protocol.hash
                         final_protocol_versions
                      then E
                      else S "-no-hash-check");
                      (match disable_warnings with
                      | [] -> E
                      | l ->
                          H
                            [
                              S "-warning";
                              S (Flags.disabled_warnings_to_string l);
                            ]);
                      H [S "-warn-error"; S "+a"];
                      S ".";
                    ];
              ]
      in
      let lifted =
        mavryk_protocol_sub_lib
          "protocol.lifted"
          ~internal_name:(sf "mavryk_protocol-%s.lifted" name_dash)
          ~path:(path // "lib_protocol")
          ~modules:["Lifted_protocol"]
          ~flags:(Flags.standard ~nopervasives:true ~disable_warnings ())
          ~deps:
            [
              mavkit_protocol_environment;
              mavryk_protocol_environment_sigs;
              main |> open_;
            ]
          ~dune:
            Dune.
              [
                targets_rule
                  ["lifted_protocol.ml"]
                  ~action:
                    [
                      S "write-file";
                      S "%{targets}";
                      S
                        {|
include Environment.Lift (Protocol)
let hash = Protocol.hash
|};
                    ];
              ]
      in
      let _functor =
        private_lib
          (sf "mavryk_protocol_%s_functor" name_underscore)
          ~path:(path // "lib_protocol")
          ~opam:""
          ~synopsis:
            (match number with
            | Other ->
                sf
                  "Mavryk/Protocol: %s (economic-protocol definition \
                   parameterized by its environment implementation)"
                  name_underscore
            | Alpha | V _ ->
                "Mavryk/Protocol: economic-protocol definition parameterized \
                 by its environment implementation")
          ~modules:["Functor"]
            (* The instrumentation is removed as it can lead to a stack overflow *)
            (* https://gitlab.com/tezos/tezos/-/issues/1927 *)
          ~bisect_ppx:No
          ~flags:(Flags.standard ~nopervasives:true ~disable_warnings ())
          ~opam_only_deps:[mavkit_protocol_compiler_mavryk_protocol_packer]
          ~deps:[mavkit_protocol_environment; mavryk_protocol_environment_sigs]
          ~dune:
            Dune.
              [
                targets_rule
                  ["functor.ml"]
                  ~deps:[modules_as_deps; [S ":src_dir"; S "MAVRYK_PROTOCOL"]]
                  ~action:
                    [
                      S "with-stdout-to";
                      S "%{targets}";
                      [
                        S "chdir";
                        S "%{workspace_root}";
                        [
                          S "run";
                          S
                            "%{bin:mavkit-protocol-compiler.mavkit-protocol-packer}";
                          S "%{src_dir}";
                        ];
                      ];
                    ];
              ]
      in
      let embedded =
        mavryk_protocol_sub_lib
          "embedded-protocol"
          ~internal_name:(sf "mavryk_embedded_protocol_%s" name_underscore)
          ~path:(path // "lib_protocol")
          ~synopsis:
            (match number with
            | Other ->
                sf
                  "Mavryk/Protocol: %s (economic-protocol definition, embedded \
                   in `mavkit-node`)"
                  name_underscore
            | Alpha | V _ ->
                "Mavryk/Protocol: economic-protocol definition, embedded in \
                 `mavkit-node`")
          ~modules:["Registerer"]
          ~linkall:true
          ~flags:(Flags.standard ~disable_warnings ())
          ~release_status:
            (match (number, status) with
            | V _, (Active | Frozen | Overridden) ->
                (* Contrary to client libs and protocol plugin registerers,
                   embedded protocols are useful even when the protocol was overridden. *)
                Released
            | V _, Not_mainnet | (Alpha | Other), _ ->
                (* Ideally we would not release the opam packages but this would require
                   removing the dependencies when releasing, both from .opam files
                   and dune files. *)
                Auto_opam)
          ~deps:[main; mavkit_protocol_updater; mavkit_protocol_environment]
          ~dune:
            Dune.
              [
                targets_rule
                  ["registerer.ml"]
                  ~deps:[modules_as_deps; [S ":src_dir"; S "MAVRYK_PROTOCOL"]]
                  ~action:
                    [
                      S "with-stdout-to";
                      S "%{targets}";
                      [
                        S "chdir";
                        S "%{workspace_root}";
                        [
                          S "run";
                          S "%{bin:mavkit-embedded-protocol-packer}";
                          S "%{src_dir}";
                          S name_underscore;
                        ];
                      ];
                    ];
              ]
      in
      {main; lifted; embedded}
  end

  let genesis =
    let name = Name.other "genesis" in
    let {Lib_protocol.main; lifted; embedded} =
      Lib_protocol.make ~name ~status:Not_mainnet
    in
    let client =
      public_lib
        (sf "mavryk-client-%s" (Name.name_dash name))
        ~path:(Name.base_path name // "lib_client")
        ~synopsis:
          "Mavryk/Protocol: protocol specific library for `mavkit-client`"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> open_ ~m:"TzPervasives.Error_monad";
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            mavkit_protocol_environment;
            main |> open_;
            lifted;
            mavkit_client_commands |> open_;
            mavkit_proxy;
            mavkit_stdlib_unix;
          ]
        ~linkall:true
    in
    register @@ make ~name ~status:Not_mainnet ~main ~embedded ~client ()

  let demo_noops =
    let name = Name.other "demo-noops" in
    let {Lib_protocol.main; lifted = _; embedded} =
      Lib_protocol.make ~name ~status:Not_mainnet
    in
    register @@ make ~name ~status:Not_mainnet ~main ~embedded ()

  let _demo_counter =
    let name = Name.other "demo-counter" in
    let {Lib_protocol.main; lifted; embedded} =
      Lib_protocol.make ~name ~status:Not_mainnet
    in
    let client =
      public_lib
        (sf "mavryk-client-%s" (Name.name_dash name))
        ~path:(Name.base_path name // "lib_client")
        ~synopsis:
          "Mavryk/Protocol: protocol specific library for `mavkit-client`"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> open_ ~m:"TzPervasives.Error_monad";
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            mavkit_client_commands |> open_;
            main |> open_;
            lifted;
          ]
        ~linkall:true
    in
    register @@ make ~name ~status:Not_mainnet ~main ~embedded ~client ()

  let register_alpha_family status name =
    let short_hash = Name.short_hash name in
    let name_dash = Name.name_dash name in
    let name_underscore = Name.name_underscore name in
    let number = Name.number name in
    let path = Name.base_path name in
    (* Container of the registered sublibraries of [mavkit-protocol-libs] *)
    let registered_mavkit_protocol_libs = Sub_lib.make_container () in
    let mavkit_protocol_lib =
      Sub_lib.sub_lib
        ~package_synopsis:(sf "Mavkit protocol %s libraries" name_dash)
        ~container:registered_mavkit_protocol_libs
        ~package:(sf "mavkit-protocol-%s-libs" name_dash)
    in
    let active =
      match status with
      | Frozen | Overridden | Not_mainnet -> false
      | Active -> true
    in
    let not_overridden =
      match status with
      | Frozen | Active | Not_mainnet -> true
      | Overridden -> false
    in
    let executable_release_status =
      match (number, status) with
      | V _, (Active | Frozen) -> Released
      | V _, (Overridden | Not_mainnet) -> Unreleased
      | Alpha, _ -> Experimental
      | Other, _ -> Unreleased
    in
    let optional_library_release_status =
      match (number, status) with
      | V _, (Active | Frozen) ->
          (* Put explicit dependency in meta-package mavkit.opam to force the optional
             dependency to be installed. *)
          Released
      | V _, (Overridden | Not_mainnet) | (Alpha | Other), _ ->
          (* Ideally we would not release the opam packages but this would require
             removing the dependencies when releasing, both from .opam files
             and dune files. *)
          Auto_opam
    in
    let opt_map l f = Option.map f l in
    let both o1 o2 =
      match (o1, o2) with Some x, Some y -> Some (x, y) | _, _ -> None
    in
    let {Lib_protocol.main; lifted; embedded} =
      Lib_protocol.make ~name ~status
    in
    let parameters =
      only_if (N.(number >= 001) && not_overridden) @@ fun () ->
      public_lib
        (sf "mavryk-protocol-%s.parameters" name_dash)
        ~path:(path // "lib_parameters")
        ~all_modules_except:["gen"]
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            mavkit_protocol_environment;
            main |> open_;
          ]
        ~linkall:true
    in
    let _parameters_exe =
      opt_map parameters @@ fun parameters ->
      private_exe
        "gen"
        ~path:(path // "lib_parameters")
        ~opam:(sf "mavryk-protocol-%s" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            parameters |> open_;
            main |> if_ N.(number >= 001) |> open_;
          ]
        ~modules:["gen"]
        ~linkall:true
        ~with_macos_security_framework:true
        ~dune:
          Dune.(
            let gen_json name =
              targets_rule
                [name ^ "-parameters.json"]
                ~deps:[S "gen.exe"]
                ~action:[S "run"; S "%{deps}"; S ("--" ^ name)]
            in
            let networks = List.["sandbox"; "test"; "mainnet"] in
            let networks =
              if N.(number >= 001) then
                networks @ List.["mainnet-with-chain-id"]
              else networks
            in
            of_list
              (List.map gen_json networks
              @ (* TODO: why do we install these files? *)
              List.
                [
                  install
                    (List.map (fun n -> S (n ^ "-parameters.json")) networks)
                    ~package:(sf "mavryk-protocol-%s" name_dash)
                    ~section:"lib";
                ]))
        ~bisect_ppx:No
    in
    let mavkit_sc_rollup =
      only_if N.(number >= 001) @@ fun () ->
      mavkit_protocol_lib
        "smart-rollup"
        ~internal_name:(sf "mavryk_smart_rollup_%s" name_dash)
        ~path:(path // "lib_sc_rollup")
        ~synopsis:
          "Protocol specific library of helpers for `mavryk-smart-rollup`"
        ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; main |> open_]
        ~inline_tests:ppx_expect
        ~linkall:true
    in
    let plugin =
      only_if (N.(number >= 001) && not_overridden) @@ fun () ->
      mavkit_protocol_lib
        "plugin"
        ~internal_name:(sf "mavryk_protocol_plugin_%s" name_dash)
        ~path:(path // "lib_plugin")
        ~synopsis:"Protocol plugin"
        ~documentation:
          [Dune.[S "package"; S (sf "mavkit-protocol-%s-libs" name_dash)]]
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            main |> open_;
            mavkit_sc_rollup |> if_some |> if_ N.(number >= 001) |> open_;
          ]
        ~all_modules_except:["Plugin_registerer"]
        ~bisect_ppx:(if N.(number >= 001) then Yes else No)
    in
    let plugin_registerer =
      opt_map plugin @@ fun plugin ->
      mavkit_protocol_lib
        "plugin-registerer"
        ~internal_name:(sf "mavryk_protocol_plugin_%s_registerer" name_dash)
        ~path:(path // "lib_plugin")
        ~synopsis:"Protocol plugin registerer"
        ~release_status:optional_library_release_status
        ~conflicts:[Conflicts.stdcompat]
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            embedded |> open_;
            plugin |> open_;
            mavkit_validation |> open_;
          ]
        ~modules:["Plugin_registerer"]
        ~bisect_ppx:(if N.(number >= 001) then Yes else No)
    in
    let client_name =
      if N.(number >= 001) then "`mavkit-client`" else "`mavryk-client`"
    in
    let client =
      only_if not_overridden @@ fun () ->
      mavkit_protocol_lib
        "client"
        ~internal_name:(sf "mavryk_client_%s" name_dash)
        ~path:(path // "lib_client")
        ~synopsis:("Protocol specific library for " ^ client_name)
        ~release_status:optional_library_release_status
        ~conflicts:[Conflicts.stdcompat]
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_clic;
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            main |> open_;
            lifted |> open_if N.(number >= 001);
            mavkit_mockup_registration |> if_ N.(number >= 001);
            mavkit_proxy |> if_ N.(number >= 001);
            mavkit_signer_backends |> if_ N.(number >= 001);
            plugin |> if_some |> open_if N.(number >= 001);
            parameters |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_rpc;
            mavkit_client_commands |> if_ N.(number == 000) |> open_;
            mavkit_stdlib_unix |> if_ N.(number == 000);
            mavkit_sc_rollup |> if_some |> if_ N.(number >= 001) |> open_;
            uri |> if_ N.(number >= 001);
          ]
        ~bisect_ppx:(if N.(number >= 001) then Yes else No)
        ?inline_tests:(if N.(number >= 001) then Some ppx_expect else None)
        ~linkall:true
    in
    let test_helpers =
      only_if active @@ fun () ->
      mavkit_protocol_lib
        "test-helpers"
        ~path:(path // "lib_protocol/test/helpers")
        ~internal_name:(sf "mavryk_%s_test_helpers" name_underscore)
        ~synopsis:"Protocol testing framework"
        ~opam_only_deps:[mavkit_protocol_environment; parameters |> if_some]
        ~deps:
          [
            tezt_core_lib |> if_ N.(number >= 002) |> open_ |> open_ ~m:"Base";
            tezt_mavryk |> if_ N.(number >= 003);
            tezt_lib |> if_ N.(number >= 002);
            qcheck_alcotest;
            mavkit_test_helpers;
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_micheline |> open_;
            mavkit_stdlib_unix |> open_;
            main |> open_;
            client |> if_some |> open_;
            parameters |> if_some |> open_;
            mavkit_protocol_environment;
            plugin |> if_some |> open_;
            mavkit_shell_services |> open_;
            mavkit_plompiler |> if_ N.(number >= 001);
            mavkit_crypto_dal |> if_ N.(number >= 001) |> open_;
            mavkit_sc_rollup |> if_some |> if_ N.(number >= 001) |> open_;
          ]
    in
    let _plugin_tests =
      opt_map (both plugin test_helpers) @@ fun (plugin, test_helpers) ->
      only_if active @@ fun () ->
      tezt
        [
          "helpers";
          "test_conflict_handler";
          "test_consensus_filter";
          "test_fee_needed_to_overtake";
          "test_fee_needed_to_replace_by_fee";
        ]
        ~path:(path // "lib_plugin/test")
        ~with_macos_security_framework:true
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_base_test_helpers |> open_;
            mavkit_base_unix |> if_ N.(number >= 001);
            alcotezt;
            mavkit_test_helpers |> open_;
            qcheck_alcotest;
            mavkit_stdlib_unix;
            mavkit_micheline |> open_;
            plugin |> open_;
            main |> open_ |> open_ ~m:"Protocol";
            parameters |> if_some |> open_;
            test_helpers |> open_;
          ]
    in
    let _client_tests =
      only_if active @@ fun () ->
      tezt
        [
          "test_michelson_v1_macros";
          "test_client_proto_contracts";
          "test_client_proto_context";
          "test_proxy";
        ]
        ~path:(path // "lib_client/test")
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~with_macos_security_framework:true
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_micheline |> open_;
            client |> if_some |> open_;
            main |> open_;
            mavkit_base_test_helpers |> open_;
            mavkit_test_helpers |> open_;
            alcotezt;
            qcheck_alcotest;
          ]
    in
    let client_commands =
      only_if (N.(number >= 001) && not_overridden) @@ fun () ->
      mavkit_protocol_lib
        "client.commands"
        ~internal_name:(sf "mavryk_client_%s_commands" name_dash)
        ~path:(path // "lib_client_commands")
        ~deps:
          [
            mavkit_base |> if_ N.(number >= 001) |> open_ ~m:"TzPervasives";
            mavkit_clic;
            main |> open_;
            parameters |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_protocol_environment;
            mavkit_shell_services |> open_;
            mavkit_mockup |> if_ N.(number >= 001);
            mavkit_mockup_registration |> if_ N.(number >= 001);
            mavkit_mockup_commands |> if_ N.(number >= 001);
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            mavkit_rpc;
            mavkit_client_base_unix |> if_ N.(number >= 001) |> open_;
            plugin |> if_some |> if_ N.(number >= 001) |> open_;
            (* uri used by the stresstest command introduced in 001 *)
            uri |> if_ N.(number >= 001);
          ]
        ~bisect_ppx:(if N.(number >= 001) then Yes else No)
        ~linkall:true
        ~all_modules_except:["alpha_commands_registration"]
    in
    let client_sapling =
      only_if (N.(number >= 001) && not_overridden) @@ fun () ->
      mavkit_protocol_lib
        "client.sapling"
        ~internal_name:(sf "mavryk_client_sapling_%s" name_underscore)
        ~path:(path // "lib_client_sapling")
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_clic;
            mavkit_crypto;
            mavkit_stdlib_unix |> open_;
            mavkit_client_base |> open_;
            mavkit_signer_backends;
            client |> if_some |> open_;
            client_commands |> if_some |> open_;
            main |> open_;
            plugin |> if_some |> if_ N.(number >= 001) |> open_;
          ]
        ~linkall:true
    in
    let client_commands_registration =
      only_if (N.(number >= 001) && not_overridden) @@ fun () ->
      mavkit_protocol_lib
        "client.commands-registration"
        ~internal_name:(sf "mavryk_client_%s_commands_registration" name_dash)
        ~path:(path // "lib_client_commands")
        ~deps:
          [
            mavkit_base |> if_ N.(number >= 001) |> open_ ~m:"TzPervasives";
            mavkit_clic;
            main |> open_;
            parameters |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_protocol_environment;
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            client_commands |> if_some |> open_;
            client_sapling |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_rpc;
            plugin |> if_some |> if_ N.(number >= 001) |> open_;
          ]
        ~bisect_ppx:(if N.(number >= 001) then Yes else No)
        ~linkall:true
        ~modules:["alpha_commands_registration"]
    in
    let baking =
      only_if active @@ fun () ->
      mavkit_protocol_lib
        "baking"
        ~internal_name:("mavryk_baking_" ^ name_dash)
        ~path:(path // "lib_delegate")
        ~synopsis:"Base library for `mavryk-baker/accuser`"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_clic;
            mavkit_version_value;
            main |> open_;
            lifted |> if_ N.(number >= 001) |> open_;
            plugin |> if_some |> open_;
            mavkit_protocol_environment;
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            mavkit_stdlib |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_shell_context |> open_;
            mavkit_context |> open_;
            mavkit_context_memory |> if_ N.(number >= 001);
            mavkit_rpc_http_client_unix |> if_ N.(number >= 001);
            mavkit_context_ops |> if_ N.(number >= 001) |> open_;
            mavkit_rpc;
            mavkit_rpc_http |> open_;
            mavkit_crypto_dal |> open_;
            mavkit_dal_node_services |> if_ N.(number >= 001);
            lwt_canceler;
            lwt_exit;
            uri;
          ]
        ~linkall:true
        ~all_modules_except:["Baking_commands"; "Baking_commands_registration"]
    in
    let tenderbrute =
      only_if (active && N.(number >= 001)) @@ fun () ->
      mavkit_protocol_lib
        "baking.tenderbrute"
        ~internal_name:(sf "tenderbrute_%s" name_underscore)
        ~path:(path // "lib_delegate/test/tenderbrute/lib")
        ~deps:
          [
            data_encoding |> open_;
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001)
            |> open_;
            mavkit_base_unix;
            main |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
          ]
        ~bisect_ppx:No
    in
    let _tenderbrute_exe =
      only_if (active && N.(number >= 001)) @@ fun () ->
      test
        "tenderbrute_main"
        ~alias:""
        ~path:(path // "lib_delegate/test/tenderbrute")
        ~with_macos_security_framework:true
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001)
            |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            main |> open_;
            tenderbrute |> if_some |> open_;
          ]
        ~linkall:true
    in
    let _baking_tests =
      opt_map (both baking test_helpers) @@ fun (baking, _test_helpers) ->
      only_if N.(number >= 001) @@ fun () ->
      let mockup_simulator =
        only_if N.(number >= 001) @@ fun () ->
        mavkit_protocol_lib
          "bakings.mockup-simulator"
          ~internal_name:(sf "mavryk_%s_mockup_simulator" name_underscore)
          ~path:(path // "lib_delegate/test/mockup_simulator")
          ~deps:
            [
              mavkit_base |> open_ ~m:"TzPervasives"
              |> error_monad_module N.(number <= 001);
              main |> open_ |> open_ ~m:"Protocol";
              client |> if_some |> open_;
              mavkit_client_commands |> open_;
              baking |> open_;
              mavkit_stdlib_unix |> open_;
              mavkit_client_base_unix |> open_;
              parameters |> if_some |> open_;
              mavkit_mockup;
              mavkit_mockup_proxy;
              mavkit_mockup_commands;
              tenderbrute |> if_some |> if_ N.(number >= 001) |> open_;
              tezt_core_lib |> open_;
            ]
          ~bisect_ppx:No
      in
      tezt
        ["test_scenario"]
        ~path:(path // "lib_delegate/test")
        ~with_macos_security_framework:true
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_test_helpers |> open_;
            mavkit_micheline |> open_;
            client |> if_some |> open_;
            main |> open_;
            mavkit_base_test_helpers |> open_;
            mockup_simulator |> if_some |> open_;
            baking |> open_;
            parameters |> if_some |> if_ N.(number >= 001);
            mavkit_crypto |> if_ N.(number >= 001);
            mavkit_event_logging_test_helpers |> open_;
            uri;
          ]
    in
    let baking_commands =
      only_if active @@ fun () ->
      mavkit_protocol_lib
        "baking-commands"
        ~internal_name:(sf "mavryk_baking_%s_commands" name_dash)
        ~path:(path // "lib_delegate")
        ~synopsis:"Protocol-specific commands for baking"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            main |> open_;
            parameters |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_protocol_environment;
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            baking |> if_some |> open_;
            mavkit_rpc;
            uri;
          ]
        ~linkall:true
        ~modules:["Baking_commands"]
    in
    let baking_commands_registration =
      only_if active @@ fun () ->
      mavkit_protocol_lib
        "baking-commands.registration"
        ~internal_name:(sf "mavryk_baking_%s_commands_registration" name_dash)
        ~path:(path // "lib_delegate")
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            main |> open_;
            mavkit_protocol_environment;
            mavkit_shell_services |> open_;
            mavkit_client_base |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            baking |> if_some |> open_;
            baking_commands |> if_some |> open_;
            mavkit_rpc;
          ]
        ~linkall:true
        ~modules:["Baking_commands_registration"]
    in
    let daemon daemon =
      only_if active @@ fun () ->
      public_exe
        (sf "mavkit-%s-%s" daemon short_hash)
        ~internal_name:(sf "main_%s_%s" daemon name_underscore)
        ~path:(path // sf "bin_%s" daemon)
        ~synopsis:(sf "Mavryk/Protocol: %s binary" daemon)
        ~release_status:executable_release_status
        ~with_macos_security_framework:true
        ~conflicts:[Conflicts.stdcompat]
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_clic;
            main |> open_;
            client |> if_some |> open_;
            mavkit_client_commands |> open_;
            baking_commands |> if_some |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_client_base_unix |> open_;
          ]
    in
    let _baker = daemon "baker" in
    let _accuser = daemon "accuser" in
    let layer2_utils =
      only_if N.(number >= 001) @@ fun () ->
      mavkit_protocol_lib
        "layer2-utils"
        ~internal_name:(sf "mavryk_layer2_utils_%s" name_dash)
        ~path:(path // "lib_layer2_utils")
        ~synopsis:"Protocol specific library for Layer 2 utils"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            main |> open_;
            client |> if_some |> open_;
          ]
        ~inline_tests:ppx_expect
        ~linkall:true
    in
    let dal =
      only_if (active && N.(number >= 001)) @@ fun () ->
      mavkit_protocol_lib
        "dal"
        ~internal_name:(sf "mavryk_dal_%s" name_dash)
        ~path:(path // "lib_dal")
        ~synopsis:"Protocol specific library for the Data availability Layer"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_protocol_compiler_registerer |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_dal_node_lib |> open_;
            client |> if_some |> open_;
            plugin |> if_some |> open_;
            embedded |> open_;
            layer2_utils |> if_some |> open_;
            main |> open_;
          ]
        ~inline_tests:ppx_expect
        ~linkall:true
    in
    let _dal_tests =
      only_if (active && N.(number >= 001)) @@ fun () ->
      tezt
        (* test [test_dac_pages_encoding] was removed after 001 *)
        ["test_dal_slot_frame_encoding"; "test_helpers"]
        ~path:(path // "lib_dal/test")
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~with_macos_security_framework:true
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            dal |> if_some |> open_;
            main |> open_;
            mavkit_base_test_helpers |> open_;
            test_helpers |> if_some |> open_;
            alcotezt;
          ]
    in
    let dac =
      (* [~link_all:true] is necessary to ensure that the dac plugin
         registration happens when running the dal node. Removing this
         option would cause DAL related tezts to fail because the DAC
         plugin cannot be resolved. *)
      only_if (active && N.(number >= 001)) @@ fun () ->
      mavkit_protocol_lib
        "dac"
        ~internal_name:(sf "mavryk_dac_%s" name_dash)
        ~path:(path // "lib_dac_plugin")
        ~synopsis:
          "Protocol specific library for the Data availability Committee"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_protocol_compiler_registerer |> open_;
            mavkit_stdlib_unix |> open_;
            mavkit_dac_lib |> open_;
            mavkit_dac_client_lib |> open_;
            client |> if_some |> open_;
            embedded |> open_;
            main |> open_;
          ]
        ~inline_tests:ppx_expect
        ~linkall:true
    in
    let _dac_tests =
      only_if (active && N.(number >= 001)) @@ fun () ->
      tezt
        [
          "test_dac_pages_encoding";
          "test_dac_plugin_registration";
          "test_helpers";
        ]
        ~path:(path // "lib_dac_plugin/test")
        ~with_macos_security_framework:true
        ~opam:(sf "mavkit-protocol-%s-libs" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            dac |> if_some |> open_;
            main |> open_;
            mavkit_base_test_helpers |> open_;
            test_helpers |> if_some |> open_;
            mavkit_dac_lib |> open_;
            mavkit_dac_node_lib |> open_;
            alcotezt;
          ]
    in
    let mavkit_injector =
      only_if N.(active && number >= 001) @@ fun () ->
      private_lib
        (sf "mavkit_injector_%s" short_hash)
        ~path:(path // "lib_injector")
        ~synopsis:
          "Mavryk/Protocol: protocol-specific library for the injector binary"
        ~opam:(sf "mavryk-injector-%s" name_dash)
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            main |> open_;
            mavkit_injector_lib |> open_;
            client |> if_some |> open_;
            mavkit_client_base |> open_;
            plugin |> if_some |> open_;
          ]
        ~linkall:true
    in
    let mavkit_sc_rollup_layer2 =
      only_if N.(number >= 001) @@ fun () ->
      mavkit_protocol_lib
        "smart-rollup-layer2"
        ~internal_name:(sf "mavryk_smart_rollup_layer2_%s" name_dash)
        ~path:(path // "lib_sc_rollup_layer2")
        ~synopsis:"Protocol specific library for `mavryk-smart-rollup`"
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives";
            main |> open_;
            mavkit_injector_lib |> open_;
            mavkit_smart_rollup_lib |> open_;
          ]
        ~inline_tests:ppx_expect
        ~linkall:true
    in
    let mavkit_sc_rollup_node =
      (* For now, we want to keep this for Nairobi and above because Etherlink
         Basenet requires it. *)
      only_if N.(number >= 001) @@ fun () ->
      private_lib
        (sf "mavkit_smart_rollup_node_%s" short_hash)
        ~path:(path // "lib_sc_rollup_node")
        ~opam:(sf "mavkit-smart-rollup-node-%s" short_hash)
        ~synopsis:
          (sf
             "Protocol specific (for %s) library for smart rollup node"
             name_dash)
        ~linkall:true
        ~deps:
          [
            mavkit_base |> open_ |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_stdlib_unix |> open_;
            mavkit_client_base |> open_;
            mavkit_client_base_unix |> open_;
            client |> if_some |> open_;
            dal |> if_some |> if_ N.(number >= 002) |> open_;
            mavkit_context_encoding;
            mavkit_context_helpers;
            main |> open_;
            plugin |> if_some |> open_;
            parameters |> if_some |> open_;
            mavkit_rpc;
            mavkit_rpc_http;
            mavkit_rpc_http_server;
            mavkit_workers |> open_;
            mavkit_dal_node_services;
            mavkit_dal_node_lib |> open_;
            (* [dac] is needed for the DAC observer client which is not
               available in Nairobi and earlier. *)
            dac |> if_some |> if_ N.(number >= 001) |> open_;
            mavkit_dac_lib |> open_;
            mavkit_dac_client_lib |> if_ N.(number >= 001) |> open_;
            mavkit_shell_services |> open_;
            mavkit_smart_rollup_lib |> open_;
            mavkit_sc_rollup |> if_some |> open_;
            mavkit_sc_rollup_layer2 |> if_some |> open_;
            layer2_utils |> if_some |> open_;
            mavkit_layer2_store |> open_;
            mavkit_crawler |> open_;
            tree_encoding;
            data_encoding;
            irmin_pack;
            irmin_pack_unix;
            irmin;
            aches;
            aches_lwt;
            mavkit_injector_lib |> open_;
            mavkit_smart_rollup_node_lib |> open_;
            mavkit_scoru_wasm;
            mavkit_scoru_wasm_fast;
            mavkit_crypto_dal |> if_ N.(number >= 001) |> open_;
            mavkit_version_value;
          ]
        ~conflicts:[Conflicts.checkseum; Conflicts.stdcompat]
    in
    let _mavkit_sc_rollup_node_test =
      only_if (active && N.(number >= 001)) @@ fun () ->
      tezt
        ["serialized_proofs"; "test_mavkit_conversions"]
        ~path:(path // "lib_sc_rollup_node/test")
        ~opam:"mavryk-sc-rollup-node-test"
        ~synopsis:"Tests for the smart rollup node library"
        ~with_macos_security_framework:true
        ~deps:
          [
            mavkit_base |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            main |> open_;
            mavkit_test_helpers |> open_;
            mavkit_sc_rollup_layer2 |> if_some |> open_;
            mavkit_sc_rollup_node |> if_some |> open_;
            alcotezt;
          ]
    in
    let benchmark_type_inference =
      only_if active @@ fun () ->
      public_lib
        (sf "mavryk-benchmark-type-inference-%s" name_dash)
        ~path:(path // "lib_benchmark/lib_benchmark_type_inference")
        ~synopsis:"Mavryk: type inference for partial Michelson expressions"
        ~deps:
          [
            mavkit_stdlib |> open_;
            mavkit_error_monad |> open_;
            mavkit_crypto |> open_;
            mavkit_micheline |> open_;
            mavkit_micheline_rewriting |> open_;
            main |> open_;
            hashcons;
          ]
    in
    let _benchmark_type_inference_tests =
      only_if active @@ fun () ->
      tests
        ["test_uf"; "test_inference"]
        ~path:(path // "lib_benchmark/lib_benchmark_type_inference/test")
        ~opam:(sf "mavryk-benchmark-type-inference-%s" name_dash)
        ~with_macos_security_framework:true
        ~deps:
          [
            mavkit_micheline |> open_;
            mavkit_micheline_rewriting;
            benchmark_type_inference |> if_some |> open_;
            main;
            mavkit_error_monad;
            client |> if_some;
          ]
    in
    let benchmark =
      opt_map test_helpers @@ fun test_helpers ->
      only_if active @@ fun () ->
      public_lib
        (sf "mavryk-benchmark-%s" name_dash)
        ~path:(path // "lib_benchmark")
        ~synopsis:
          "Mavryk/Protocol: library for writing benchmarks (protocol-specific \
           part)"
        ~deps:
          [
            mavkit_stdlib |> open_;
            mavkit_base |> open_ |> error_monad_module N.(number <= 001);
            mavkit_error_monad |> open_;
            mavkit_micheline |> open_;
            mavkit_micheline_rewriting |> open_;
            mavkit_benchmark |> open_;
            benchmark_type_inference |> if_some |> open_;
            main |> open_;
            mavkit_crypto;
            parameters |> if_some;
            hashcons;
            test_helpers |> open_;
            prbnmcn_stats;
          ]
        ~linkall:true
        ~private_modules:["kernel"; "rules"; "state_space"]
        ~bisect_ppx:No
    in
    let _benchmark_tests =
      opt_map (both benchmark test_helpers) @@ fun (benchmark, test_helpers) ->
      only_if active @@ fun () ->
      (* Note: to enable gprof profiling,
         manually add the following stanza to lib_benchmark/test/dune:
         (ocamlopt_flags (:standard -p -ccopt -no-pie)) *)
      tests
        [
          "test_sampling_data";
          "test_sampling_code";
          "test_autocompletion";
          "test_distribution";
        ]
        ~path:(path // "lib_benchmark/test")
        ~with_macos_security_framework:true
        ~opam:(sf "mavryk-benchmark-%s" name_dash)
        ~deps:
          [
            mavkit_base |> error_monad_module N.(number <= 001);
            mavkit_micheline |> open_;
            mavkit_micheline_rewriting;
            main |> open_;
            mavkit_benchmark |> open_;
            benchmark_type_inference |> if_some |> open_;
            benchmark |> if_some |> open_;
            test_helpers |> open_;
            mavkit_error_monad;
            prbnmcn_stats;
          ]
        ~alias:""
        ~dune:
          Dune.
            [
              alias_rule
                "runtest_micheline_rewriting_data"
                ~action:(run_exe "test_sampling_data" ["1234"]);
              alias_rule
                "runtest_micheline_rewriting_code"
                ~action:(run_exe "test_sampling_code" ["1234"]);
            ]
    in
    let benchmarks_proto : Manifest.target option =
      Option.bind (both benchmark test_helpers)
      @@ fun (benchmark, test_helpers) ->
      only_if active @@ fun () ->
      public_lib
        (sf "mavryk-benchmarks-proto-%s" name_dash)
        ~path:(path // "lib_benchmarks_proto")
        ~synopsis:"Mavryk/Protocol: protocol benchmarks"
        ~deps:
          [
            str;
            mavkit_stdlib |> open_;
            mavkit_base |> open_ |> open_ ~m:"TzPervasives"
            |> error_monad_module N.(number <= 001);
            mavkit_error_monad |> open_;
            parameters |> if_some |> open_;
            lazy_containers |> open_;
            mavkit_benchmark |> open_;
            benchmark |> if_some |> open_;
            benchmark_type_inference |> if_some |> open_;
            main |> open_ |> open_ ~m:"Protocol";
            mavkit_crypto;
            mavkit_shell_benchmarks;
            mavkit_micheline |> open_;
            test_helpers |> open_;
            mavkit_sapling;
            client |> if_some |> open_;
            plugin |> if_some |> open_;
            mavkit_protocol_environment;
          ]
        ~linkall:true
    in
    let _ =
      if active then
        Lib_protocol.make_tests
          ?test_helpers
          ?parameters
          ?plugin
          ?client
          ?benchmark:(Option.bind benchmark Fun.id)
          ?benchmark_type_inference
          ?mavkit_sc_rollup
          ~main
          ~name
          ()
    in
    (* Generate documentation index for [mavkit-protocol-%s-libs] *)
    let () =
      write (path // "lib_plugin/index.mld") @@ fun fmt ->
      let header =
        sf
          "{0 Mavkit-protocol-%s-libs: mavkit protocol %s libraries}\n\n\
           This is a package containing some libraries related to the Mavryk \
           %s protocol.\n\n\
           It contains the following libraries:\n\n"
          name_dash
          name_dash
          name_dash
      in
      Manifest.Sub_lib.pp_documentation_of_container
        ~header
        fmt
        registered_mavkit_protocol_libs
    in
    register
    @@ make
         ~status
         ~name
         ~main
         ~embedded
         ?client
         ?client_commands
         ?client_commands_registration
         ?baking_commands_registration
         ?plugin
         ?plugin_registerer
         ?dal
         ?dac
         ?test_helpers
         ?parameters
         ?benchmarks_proto
         ?baking
         ?mavkit_sc_rollup
         ?mavkit_sc_rollup_node
         ?mavkit_injector
         ()

  let active = register_alpha_family Active

  let frozen = register_alpha_family Frozen

  (* let overridden = register_alpha_family Overridden *)

  let _000_Ps9mPmXa = frozen (Name.v "Ps9mPmXa" 000)

  let _001_PtAtLas = active (Name.v "PtAtLas" 001)

  let _002_PtBoreas = active (Name.v "PtBoreas" 002)

  let alpha = active Name.alpha

  let all = List.rev !all_rev

  let active = List.filter (fun p -> p.baking_commands_registration <> None) all

  let all_optionally (get_packages : (t -> target option) list) =
    let get_targets_for_protocol protocol =
      List.filter_map (fun get_package -> get_package protocol) get_packages
    in
    List.map get_targets_for_protocol all |> List.flatten |> List.map optional
end

(* TESTS THAT USE PROTOCOLS *)

let _mavkit_micheline_rewriting_tests =
  tezt
    ["test_rewriting"]
    ~path:"src/lib_benchmark/lib_micheline_rewriting/test"
    ~with_macos_security_framework:true
    ~opam:"mavryk-micheline-rewriting"
    ~deps:
      [
        mavkit_micheline |> open_;
        mavkit_micheline_rewriting;
        Protocol.(main alpha);
        mavkit_error_monad;
        Protocol.(client_exn alpha);
      ]

let mavkit_store_tests =
  tezt
    [
      "test";
      "test_snapshots";
      "test_reconstruct";
      "test_history_mode_switch";
      "alpha_utils";
      "test_consistency";
      "test_locator";
      "test_cemented_store";
      "test_block_store";
      "test_protocol_store";
      "test_store";
      "test_testchain";
      "test_utils";
      "assert_lib";
    ]
    ~path:"src/lib_store/unix/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-store-tests"
    ~synopsis:"Store tests"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_crypto |> open_;
        mavkit_context_ops |> open_;
        mavkit_store_shared |> open_;
        mavkit_store_unix |> open_;
        mavkit_store_unix_reconstruction |> open_;
        mavkit_store_unix_snapshots |> open_;
        mavkit_shell_services |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_validation |> open_;
        mavkit_protocol_updater |> open_;
        Protocol.(embedded demo_noops);
        Protocol.(embedded genesis);
        Protocol.(embedded alpha);
        Protocol.(parameters_exn alpha |> open_);
        Protocol.(plugin_exn alpha) |> open_;
        alcotezt;
        tezt_lib;
        mavkit_test_helpers |> open_;
        mavkit_event_logging_test_helpers |> open_;
      ]

(* [_mavkit_bench_store_lib_tests_exe] is a bench for the store locator,
   We do not run these tests in the CI. *)
let _mavkit_bench_store_lib_tests_exe =
  private_exe
    "bench"
    ~path:"src/lib_store/unix/test/bench"
    ~synopsis:"Bench store lib tests"
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tezt_lib;
        alcotezt;
        mavkit_store_tests |> open_;
      ]

(* [_mavkit_slow_store_lib_tests_exe] is a very long test, running a huge
   combination of tests that are useful for local testing for a
   given test suite. In addition to that, there is a memory leak
   is the tests (that could be in alcotest) which makes the test
   to consumes like > 10Gb of ram. For these reasons, we do not
   run these tests in the CI. *)
let _mavkit_slow_store_lib_tests_exe =
  private_exe
    "test_slow"
    ~path:"src/lib_store/unix/test/slow"
    ~synopsis:"Slow store lib tests"
    ~modules:["test_slow"]
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        tezt_lib;
        alcotezt;
        mavkit_store_tests |> open_;
      ]

let _mavkit_shell_tests =
  tezt
    [
      "generators";
      "generators_tree";
      "shell_test_helpers";
      "test_consensus_heuristic";
      "test_node";
      "test_peer_validator";
      "test_prevalidator";
      "test_prevalidation";
      "test_prevalidator_bounding";
      "test_prevalidator_classification";
      "test_prevalidator_classification_operations";
      "test_prevalidator_pending_operations";
      "test_protocol_validator";
      "test_shell_operation";
      "test_synchronisation_heuristic";
      "test_synchronisation_heuristic_fuzzy";
      "test_validator";
    ]
    ~path:"src/lib_shell/test"
    ~with_macos_security_framework:true
    ~opam:"mavkit-shell-tests"
    ~synopsis:"Shell tests"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_test_helpers |> open_;
        mavkit_store |> open_;
        mavkit_store_shared |> open_;
        mavkit_context |> open_;
        mavkit_context_ops |> open_;
        mavkit_shell_context |> open_;
        mavkit_protocol_updater |> open_;
        mavkit_p2p |> open_;
        mavkit_p2p_services |> open_;
        mavkit_requester;
        mavkit_shell |> open_;
        mavkit_shell_services |> open_;
        Protocol.(embedded demo_noops);
        mavkit_stdlib_unix |> open_;
        mavkit_validation |> open_;
        mavkit_event_logging_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        alcotezt;
        mavkit_version_value;
        mavkit_requester_tests |> open_;
      ]

(* INTERNAL EXES *)

(* Not released, so no ~opam. *)
let remove_if_exists fname = if Sys.file_exists fname then Sys.remove fname

let get_contracts_lib =
  let get_contracts_module proto =
    "devtools" // "get_contracts"
    // (sf "get_contracts_%s.ml" @@ Protocol.name_underscore proto)
  in
  let protocols =
    List.filter_map
      (fun proto ->
        let get_contracts_ml = get_contracts_module proto in
        match (Protocol.status proto, Protocol.client proto) with
        | Active, Some client ->
            (if not @@ Sys.file_exists get_contracts_ml then
             let contents =
               file_content @@ get_contracts_module Protocol.alpha
             in
             let contents =
               Str.global_replace
                 (Str.regexp_string "open Mavryk_protocol_alpha")
                 ("open Mavryk_protocol_" ^ Protocol.name_underscore proto)
                 contents
             in
             let contents =
               Str.global_replace
                 (Str.regexp_string "open Mavryk_client_alpha")
                 ("open Mavryk_client_" ^ Protocol.name_underscore proto)
                 contents
             in
             write get_contracts_ml (fun fmt ->
                 Format.pp_print_string fmt contents)) ;
            Some [Protocol.main proto; client]
        | _ ->
            remove_if_exists get_contracts_ml ;
            None)
      Protocol.all
  in
  private_lib
    "get_contracts_lib"
    ~path:("devtools" // "get_contracts")
    ~release_status:Unreleased
    ~synopsis:"Generic tool to extract smart contracts from node's context."
    ~opam:""
    ~deps:
      ([
         mavkit_micheline |> open_;
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_store;
       ]
      @ List.flatten protocols)
    ~all_modules_except:["get_contracts"]
    ~bisect_ppx:No
    ~linkall:true

let _get_contracts =
  private_exe
    "get_contracts"
    ~path:("devtools" // "get_contracts")
    ~release_status:Unreleased
    ~with_macos_security_framework:true
    ~synopsis:"A script to extract smart contracts from a node."
    ~opam:""
    ~deps:
      [
        mavkit_micheline |> open_;
        mavkit_base |> open_ ~m:"TzPervasives";
        get_contracts_lib |> open_;
      ]
    ~modules:["get_contracts"]
    ~bisect_ppx:No

let _proto_context_du =
  public_exe
    "proto_context_du"
    ~internal_name:"main"
    ~path:("devtools" // "proto_context_du")
    ~release_status:Unreleased
    ~synopsis:"A script to print protocol context disk usage"
    ~opam:"internal-devtools_proto-context-du"
    ~deps:
      [
        mavkit_clic;
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_node_config;
        mavkit_store;
        Protocol.(main alpha);
        Protocol.(client_exn alpha);
      ]
    ~bisect_ppx:No

let yes_wallet_lib =
  let get_delegates_module proto =
    "devtools" // "yes_wallet"
    // (sf "get_delegates_%s.ml" @@ Protocol.name_underscore proto)
  in
  let protocols =
    List.filter_map
      (fun proto ->
        let get_delegates_ml = get_delegates_module proto in
        match Protocol.status proto with
        | Active ->
            (if not @@ Sys.file_exists get_delegates_ml then
             let contents =
               file_content @@ get_delegates_module Protocol.alpha
             in
             let contents =
               Str.global_replace
                 (Str.regexp_string "open Mavryk_protocol_alpha")
                 ("open Mavryk_protocol_" ^ Protocol.name_underscore proto)
                 contents
             in
             write get_delegates_ml (fun fmt ->
                 Format.pp_print_string fmt contents)) ;
            Some (Protocol.main proto)
        | _ ->
            remove_if_exists get_delegates_ml ;
            None)
      Protocol.all
  in
  private_lib
    "yes_wallet_lib"
    ~path:("devtools" // "yes_wallet")
    ~release_status:Unreleased
    ~synopsis:"A development tool for extracting baker keys from a context."
    ~opam:""
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         lwt_unix;
         ezjsonm;
         mavkit_node_config;
         mavkit_store;
         mavkit_shell_context;
         mavkit_context;
       ]
      @ protocols)
    ~all_modules_except:["yes_wallet"]
    ~bisect_ppx:No
    ~linkall:true

let _yes_wallet =
  private_exe
    "yes_wallet"
    ~path:("devtools" // "yes_wallet")
    ~release_status:Unreleased
    ~with_macos_security_framework:true
    ~synopsis:
      "A script extracting delegates' keys from a context into a wallet."
    ~opam:""
    ~deps:[yes_wallet_lib |> open_]
    ~modules:["yes_wallet"]
    ~bisect_ppx:No

let _yes_wallet_test =
  private_exe
    "bench_signature_perf"
    ~path:("devtools" // "yes_wallet" // "test")
    ~release_status:Unreleased
    ~synopsis:"Tests for yes_wallet tool"
    ~opam:""
    ~deps:
      [
        mavkit_error_monad |> open_ ~m:"TzLwtreslib";
        mavkit_crypto;
        zarith;
        zarith_stubs_js;
        data_encoding |> open_;
        lwt_unix;
        ptime;
      ]
    ~bisect_ppx:No

let _testnet_experiment_tools =
  private_exe
    "testnet_experiment_tools"
    ~path:("devtools" // "testnet_experiment_tools")
    ~release_status:Unreleased
    ~synopsis:
      "Suite of tools to support the execution of stresstests on testnets"
    ~bisect_ppx:No
    ~static:false
    ~with_macos_security_framework:true
    ~opam:""
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk;
        mavkit_client_base_unix |> open_;
        mavkit_node_config;
        mavkit_base;
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        Protocol.(client_exn alpha);
        Protocol.(main alpha);
      ]
    ~modules:["testnet_experiment_tools"; "format_baker_accounts"]

let simulation_scenario_lib =
  let proto_deps, proto_tools =
    let proto_tool proto = sf "tool_%s" @@ Protocol.name_underscore proto in
    let get_tool_module proto =
      "devtools" // "testnet_experiment_tools" // (proto_tool proto ^ ".ml")
    in
    let alpha_tool = get_tool_module Protocol.alpha in
    List.filter_map
      (fun proto ->
        let tool_path = get_tool_module proto in
        match (Protocol.status proto, Protocol.client proto) with
        | Active, Some _client ->
            (if not @@ Sys.file_exists tool_path then
             let contents = file_content @@ alpha_tool in
             let contents =
               List.fold_left
                 (fun contents (re, replace) ->
                   Str.global_replace re replace contents)
                 contents
                 [
                   ( Str.regexp_string "open Mavryk_client_alpha",
                     "open Mavryk_client_" ^ Protocol.name_underscore proto );
                   ( Str.regexp_string "open Mavryk_baking_alpha",
                     "open Mavryk_baking_" ^ Protocol.name_underscore proto );
                   ( Str.regexp_string "open Mavryk_protocol_alpha",
                     "open Mavryk_protocol_" ^ Protocol.name_underscore proto );
                 ]
             in
             write tool_path (fun fmt -> Format.pp_print_string fmt contents)) ;
            let proto_deps =
              Protocol.
                [
                  baking_exn proto;
                  client_exn proto;
                  client_commands_exn proto;
                  main proto;
                ]
            in
            Some (proto_deps, proto_tool proto)
        | _ ->
            remove_if_exists tool_path ;
            None)
      Protocol.all
    |> List.split
  in
  private_lib
    "simulation_scenario_lib"
    ~path:("devtools" // "testnet_experiment_tools")
    ~release_status:Unreleased
    ~synopsis:"Simulation scenario lib"
    ~opam:""
    ~deps:
      ([
         mavkit_stdlib_unix |> open_;
         mavkit_base |> open_ |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         mavkit_store |> open_;
         mavkit_store_shared |> open_;
         mavkit_context |> open_;
       ]
      @ List.flatten proto_deps)
    ~modules:("sigs" :: proto_tools)
    ~bisect_ppx:No
    ~linkall:true

let _simulation_scenario =
  private_exe
    "simulation_scenario"
    ~path:("devtools" // "testnet_experiment_tools")
    ~release_status:Unreleased
    ~with_macos_security_framework:true
    ~synopsis:
      "A script creating a simulation scenario from a mavryk node directory."
    ~opam:""
    ~deps:
      [
        mavkit_stdlib_unix |> open_;
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_store |> open_;
        mavkit_clic;
        mavkit_store_unix_snapshots |> open_;
        mavkit_store_shared |> open_;
        mavkit_node_config |> open_;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        simulation_scenario_lib |> open_;
      ]
    ~modules:["simulation_scenario"]
    ~bisect_ppx:No
    ~linkall:true

let _extract_data =
  private_exe
    "extract_data"
    ~path:("devtools" // "testnet_experiment_tools")
    ~release_status:Unreleased
    ~with_macos_security_framework:true
    ~synopsis:"A script to extract data from profiling."
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_store |> open_;
        mavkit_clic;
        mavkit_client_base_unix |> open_;
      ]
    ~modules:["extract_data"]
    ~bisect_ppx:No
    ~linkall:true

let _safety_checker =
  private_exe
    "safety_checker"
    ~path:("devtools" // "testnet_experiment_tools")
    ~with_macos_security_framework:true
    ~release_status:Unreleased
    ~synopsis:
      "A script for checking the safety of the reducing block time experiment."
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_store |> open_;
        mavkit_clic;
        mavkit_node_config |> open_;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
      ]
    ~modules:["safety_checker"]
    ~bisect_ppx:No
    ~linkall:true

let _get_teztale_data =
  private_exe
    "get_teztale_data"
    ~path:("devtools" // "testnet_experiment_tools")
    ~synopsis:"Script to obtain missed attestations from experiment"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~release_status:Unreleased
    ~opam:""
    ~deps:
      [
        mavkit_base |> open_ |> open_ ~m:"TzPervasives";
        mavkit_clic;
        caqti_lwt_unix;
        caqti_dynload;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
      ]
    ~modules:["get_teztale_data"; "teztale_sql_queries"]

let simdal_lib =
  private_lib
    "simdal"
    ~path:("devtools" // "simdal" // "lib")
    ~release_status:Unreleased
    ~synopsis:"P2P simulator library"
    ~opam:""
    ~deps:[ocamlgraph; prbnmcn_stats; unix]
    ~static:false
    ~bisect_ppx:No

let _simdal =
  private_exes
    ["sim"; "concat"]
    ~path:("devtools" // "simdal" // "bin")
    ~release_status:Unreleased
    ~synopsis:"DAL/P2P simulator"
    ~opam:""
    ~deps:[simdal_lib]
    ~static:false
    ~bisect_ppx:No

let tezt_tx_kernel =
  private_lib
    "tezt_tx_kernel"
    ~path:"tezt/lib_tx_kernel"
    ~opam:"tezt-tx-kernel"
    ~synopsis:"Tx kernel test framework based on Tezt"
    ~bisect_ppx:No
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_ |> open_ ~m:"Runnable.Syntax";
        Protocol.(main alpha);
        mavkit_crypto;
      ]
    ~release_status:Unreleased

let _ppinclude =
  private_exe
    "ppinclude"
    ~path:"src/lib_protocol_environment/ppinclude"
    ~opam:"mavkit-libs"
    ~bisect_ppx:No
    ~deps:[compiler_libs_common]

let _dal_throughput =
  private_exe
    "dal_throughput_gen"
    ~path:
      ("devtools" // "cloud-infrastructure" // "projects" // "nl-dal"
     // "octogram")
    ~synopsis:"DAL Throughput scenarii generator"
    ~release_status:Unreleased
    ~opam:""
    ~deps:[ezjsonm]
    ~static:false
    ~bisect_ppx:No

let _mavkit_node =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | _, V 000 ->
            (* The node always needs to be linked with this protocol for Mainnet. *)
            false
        | Active, V _ ->
            (* Active protocols cannot be optional because of a bug
               that results in inconsistent hashes. Once this bug is fixed,
               this exception can be removed. *)
            false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            (* Other protocols are optional. *)
            true
      in
      let targets =
        List.filter_map
          Fun.id
          [Protocol.embedded_opt protocol; Protocol.plugin_registerer protocol]
      in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exe
    "mavkit-node"
    ~path:"src/bin_node"
    ~internal_name:"main"
    ~synopsis:"Mavryk: `mavkit-node` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives" |> open_;
         mavkit_base_unix |> open_;
         mavkit_version;
         mavkit_version_value;
         mavkit_node_config |> open_;
         mavkit_stdlib_unix |> open_;
         mavkit_shell_services |> open_;
         mavkit_rpc_http |> open_;
         mavkit_rpc_http_server |> open_;
         mavkit_rpc_process |> open_;
         mavkit_p2p |> open_;
         mavkit_shell |> open_;
         mavkit_store |> open_;
         mavkit_store_unix_reconstruction |> open_;
         mavkit_store_unix_snapshots |> open_;
         mavkit_context;
         mavkit_validation |> open_;
         mavkit_shell_context |> open_;
         mavkit_workers |> open_;
         mavkit_protocol_updater |> open_;
         cmdliner;
         fmt_cli;
         fmt_tty;
         tls_lwt;
         prometheus_app_unix;
         lwt_exit;
         uri;
         mavkit_base_p2p_identity_file |> open_;
       ]
      @ protocol_deps)
    ~linkall:true
    ~dune:
      Dune.
        [
          install
            [as_ "mavkit-sandboxed-node.sh" "mavkit-sandboxed-node.sh"]
            ~package:"mavkit-node"
            ~section:"bin";
        ]

let _mavkit_client =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | Active, V _ -> false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            true
      in
      let targets =
        List.filter_map
          Fun.id
          [
            (match Protocol.client_commands_registration protocol with
            | None -> Protocol.client protocol
            | x -> x);
            Protocol.baking_commands_registration protocol;
            Protocol.plugin protocol;
          ]
      in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exes
    ["mavkit-client"; "mavkit-admin-client"]
    ~path:"src/bin_client"
    ~internal_names:["main_client"; "main_admin"]
    ~opam:"mavkit-client"
    ~synopsis:"Mavryk: `mavkit-client` binary"
    ~release_status:Released
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_clic;
         mavkit_rpc_http_client |> open_;
         mavkit_stdlib_unix |> open_;
         mavkit_shell_services |> open_;
         mavkit_client_base |> open_;
         mavkit_client_commands |> open_;
         mavkit_mockup_commands |> open_;
         mavkit_proxy;
         mavkit_client_base_unix |> open_;
         mavkit_signer_backends_unix;
         uri;
       ]
      @ protocol_deps)
    ~linkall:true
    ~with_macos_security_framework:true
    ~dune:
      Dune.
        [
          install
            [
              as_
                "mavkit-init-sandboxed-client.sh"
                "mavkit-init-sandboxed-client.sh";
            ]
            ~package:"mavkit-client"
            ~section:"bin";
          alias_rule
            "runtest_compile_protocol"
            ~deps_dune:[[S "source_tree"; S "test/proto_test_injection"]]
            ~action:
              [
                S "run";
                S "%{bin:mavkit-protocol-compiler}";
                S "-no-hash-check";
                H [S "-warn-error"; S "+a"];
                S "test/proto_test_injection/";
              ];
        ]

let _mavkit_codec =
  public_exe
    "mavkit-codec"
    ~path:"src/bin_codec"
    ~internal_name:"codec"
    ~synopsis:"Mavryk: `mavkit-codec` binary to encode and decode values"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      ([
         data_encoding |> open_;
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_client_base_unix |> open_;
         mavkit_client_base |> open_;
         mavkit_node_config;
         mavkit_clic;
         mavkit_stdlib_unix |> open_;
         mavkit_event_logging |> open_;
         mavkit_signer_services;
         mavkit_version_value;
       ]
      @ Protocol.all_optionally
      @@ [
           (fun protocol ->
             let link =
               match Protocol.number protocol with
               | Alpha -> true
               | V number -> number >= 001
               | Other -> false
             in
             if link then Protocol.client protocol else None);
         ])
    ~linkall:true

let _mavkit_proxy_server =
  public_exe
    "mavkit-proxy-server"
    ~path:"src/bin_proxy_server"
    ~internal_name:"main_proxy_server"
    ~synopsis:"Mavkit: `mavkit-proxy-server` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives" |> open_;
         mavkit_base_unix;
         mavkit_stdlib_unix |> open_;
         mavkit_rpc;
         cmdliner;
         lwt_exit;
         lwt_unix;
         mavkit_proxy;
         mavkit_proxy_server_config;
         mavkit_rpc_http_client_unix;
         mavkit_rpc_http_server;
         mavkit_shell_services;
         mavkit_shell_context;
         mavkit_version_value;
         uri;
       ]
      @ Protocol.all_optionally [Protocol.client; Protocol.plugin])
    ~linkall:true

let _mavkit_snoop =
  public_exe
    "mavkit-snoop"
    ~path:"src/bin_snoop"
    ~internal_name:"main_snoop"
    ~synopsis:"Mavryk: `mavkit-snoop` binary"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_clic;
        mavkit_benchmark |> open_;
        mavkit_benchmark_examples;
        mavkit_shell_benchmarks;
        Protocol.(benchmarks_proto_exn alpha);
        str;
        pyml;
        prbnmcn_stats;
        mavkit_version_value;
      ]
    ~linkall:true
    ~dune:
      Dune.
        [
          S "cram"
          :: G [S "deps" :: [S "main_snoop.exe"]]
          :: [S "package" :: [S "mavkit-snoop"]];
        ]

let _mavkit_injector_server =
  public_exe
    "mavkit-injector-server"
    ~internal_name:"mavkit_injector_server"
    ~path:"contrib/mavkit_injector_server"
    ~synopsis:"Mavkit injector"
    ~release_status:Unreleased
    ~with_macos_security_framework:true
    ~linkall:true
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_injector_lib |> open_;
         mavkit_stdlib_unix |> open_;
         mavkit_rpc_http_server |> open_;
         mavkit_rpc_http |> open_;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         data_encoding;
       ]
      (* No code from mavkit_injector_alpha is used, but it's imported in order to *)
      (* run the protocol registration code *)
      @ Protocol.(all_optionally [mavkit_injector]))

(* We use Dune's select statement and keep uTop optional *)
(* Keeping uTop optional lets `make build` succeed, *)
(* which uses mavryk-network/opam-repository to resolve dependencies, *)
(* on the CI. This prevents having to add dev-dependency to *)
(* mavryk-network/opam-repository unnecessarily *)
(* We set [~static] to false because we don't release this as a static binary. *)
let _tztop =
  public_exe
    "tztop"
    ~path:"devtools/tztop"
    ~release_status:Unreleased
    ~internal_name:"tztop_main"
    ~synopsis:"Internal dev tools"
    ~opam:"internal-devtools"
    ~modes:[Byte]
    ~bisect_ppx:No
    ~static:false
    ~profile:"mavkit-dev-deps"
    ~deps:
      [
        (* The following deps come from the original dune file. *)
        mavkit_protocol_compiler_lib;
        mavkit_base;
        compiler_libs_toplevel;
        select
          ~package:utop
          ~source_if_present:"tztop.utop.ml"
          ~source_if_absent:"tztop.vanilla.ml"
          ~target:"tztop.ml";
      ]

let _mavkit_signer =
  public_exe
    "mavkit-signer"
    ~path:"src/bin_signer"
    ~internal_name:"main_signer"
    ~synopsis:"Mavryk: `mavkit-signer` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~conflicts:[Conflicts.stdcompat]
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_clic;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        mavkit_client_commands |> open_;
        mavkit_signer_services |> open_;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server |> open_;
        mavkit_rpc_http_client_unix |> open_;
        mavkit_stdlib_unix |> open_;
        mavkit_stdlib |> open_;
        mavkit_signer_backends_unix;
      ]

let _rpc_openapi =
  private_exe
    "rpc_openapi"
    ~path:"src/bin_openapi"
    ~opam:""
    ~deps:[mavkit_openapi]

let _mavkit_tps_evaluation =
  public_exe
    "mavryk-tps-evaluation"
    ~internal_name:"main_tps_evaluation"
    ~path:"src/bin_tps_evaluation"
    ~synopsis:"Mavryk TPS evaluation tool"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        caqti;
        caqti_dynload;
        caqti_lwt_unix;
        data_encoding;
        lwt;
        Protocol.(baking_exn alpha);
        Protocol.(client_commands_exn alpha);
        mavkit_client_base_unix;
        Protocol.(main alpha);
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_;
        tezt_performance_regression |> open_;
        uri;
      ]
    ~static:false
    ~dune:
      Dune.
        [
          targets_rule
            ["sql.ml"]
            ~action:
              [
                S "run";
                G
                  [
                    S "%{bin:ocp-ocamlres}";
                    S "-format";
                    S "ocaml";
                    S "-o";
                    S "%{targets}";
                  ];
                S "%{dep:sql/get_all_operations.sql}";
              ];
        ]

let _mavkit_dal_node =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | _, V 000 ->
            (* The node always needs to be linked with this protocol for Mainnet. *)
            false
        | Active, V _ ->
            (* Active protocols cannot be optional because of a bug
               that results in inconsistent hashes. Once this bug is fixed,
               this exception can be removed. *)
            false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            (* Other protocols are optional. *)
            true
      in
      let targets = List.filter_map Fun.id [Protocol.dal protocol] in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exe
    "mavkit-dal-node"
    ~path:"src/bin_dal_node"
    ~internal_name:"main"
    ~synopsis:"Mavryk: `mavkit-dal-node` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_version;
         cmdliner;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         mavkit_client_commands |> open_;
         mavkit_rpc_http |> open_;
         mavkit_rpc_http_server;
         mavkit_protocol_updater;
         mavkit_rpc_http_client_unix;
         mavkit_stdlib_unix |> open_;
         mavkit_stdlib |> open_;
         mavkit_dal_node_lib |> open_;
         mavkit_dal_node_services |> open_;
         mavkit_layer2_store |> open_;
         mavkit_crypto_dal |> open_;
         mavkit_store_unix;
         mavkit_store_shared |> open_;
         mavkit_gossipsub |> open_;
         mavkit_dal_node_gossipsub_lib |> open_;
         mavkit_p2p |> open_;
         mavkit_p2p_services |> open_;
         mavkit_crypto |> open_;
         mavkit_base_p2p_identity_file |> open_;
         mavkit_shell_services |> open_;
         irmin_pack;
         irmin_pack_unix;
         irmin;
         prometheus_app;
         prometheus;
       ]
      @ protocol_deps)
    ~conflicts:[Conflicts.checkseum; Conflicts.stdcompat]

let _mavkit_dac_node =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | _, V 000 ->
            (* The node always needs to be linked with this protocol for Mainnet. *)
            false
        | Active, V _ ->
            (* Active protocols cannot be optional because of a bug
               that results in inconsistent hashes. Once this bug is fixed,
               this exception can be removed. *)
            false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            (* Other protocols are optional. *)
            true
      in
      let targets = List.filter_map Fun.id [Protocol.dac protocol] in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exe
    "mavkit-dac-node"
    ~path:"src/bin_dac_node"
    ~internal_name:"main_dac"
    ~synopsis:"Mavryk: `mavkit-dac-node` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_clic;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         mavkit_client_commands |> open_;
         mavkit_rpc_http |> open_;
         mavkit_rpc_http_server;
         mavkit_protocol_updater;
         mavkit_rpc_http_client_unix;
         mavkit_stdlib_unix |> open_;
         mavkit_stdlib |> open_;
         mavkit_dac_lib |> open_;
         mavkit_dac_node_lib |> open_;
         mavkit_layer2_store |> open_;
         irmin_pack;
         irmin_pack_unix;
         irmin;
       ]
      @ protocol_deps)
    ~conflicts:[Conflicts.checkseum; Conflicts.stdcompat]

let _mavkit_dac_client =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | _, V 000 ->
            (* The node always needs to be linked with this protocol for Mainnet. *)
            false
        | Active, V _ ->
            (* Active protocols cannot be optional because of a bug
               that results in inconsistent hashes. Once this bug is fixed,
               this exception can be removed. *)
            false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            (* Other protocols are optional. *)
            true
      in
      let targets = List.filter_map Fun.id [Protocol.dac protocol] in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exe
    "mavkit-dac-client"
    ~path:"src/bin_dac_client"
    ~internal_name:"main_dac_client"
    ~synopsis:"Mavryk: `mavkit-dac-client` binary"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_base_unix;
         mavkit_clic;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         mavkit_client_commands |> open_;
         mavkit_stdlib_unix |> open_;
         mavkit_stdlib |> open_;
         mavkit_dac_lib |> open_;
         mavkit_dac_client_lib |> open_;
       ]
      @ protocol_deps)

let _mavkit_smart_rollup_node =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | Active, V _ -> false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            true
      in
      let targets =
        List.filter_map Fun.id [Protocol.mavkit_sc_rollup_node protocol]
      in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  public_exe
    "mavkit-smart-rollup-node"
    ~internal_name:"main_smart_rollup_node"
    ~path:"src/bin_smart_rollup_node"
    ~synopsis:"Mavkit: Smart rollup node"
    ~release_status:Released
    ~linkall:true
    ~with_macos_security_framework:true
    ~deps:
      ([
         mavkit_base |> open_ |> open_ ~m:"TzPervasives"
         |> open_ ~m:"TzPervasives.Error_monad";
         mavkit_clic;
         mavkit_shell_services |> open_;
         mavkit_client_base |> open_;
         mavkit_client_base_unix |> open_;
         mavkit_client_commands |> open_;
         mavkit_smart_rollup_lib |> open_;
         mavkit_smart_rollup_node_lib |> open_;
       ]
      @ protocol_deps)

let _mavkit_smart_rollup_node_lib_tests =
  let protocol_deps =
    let deps_for_protocol protocol =
      let is_optional =
        match (Protocol.status protocol, Protocol.number protocol) with
        | Active, V _ -> false
        | (Frozen | Overridden | Not_mainnet), _ | Active, (Alpha | Other) ->
            true
      in
      let targets =
        List.filter_map Fun.id [Protocol.mavkit_sc_rollup_node protocol]
      in
      if is_optional then List.map optional targets else targets
    in
    List.map deps_for_protocol Protocol.all |> List.flatten
  in
  let helpers =
    private_lib
      "mavkit_smart_rollup_node_test_helpers"
      ~path:"src/lib_smart_rollup_node/test/helpers"
      ~opam:""
      ~deps:
        ([
           mavkit_base |> open_ ~m:"TzPervasives"
           |> open_ ~m:"TzPervasives.Error_monad";
           mavkit_test_helpers |> open_;
           qcheck_alcotest;
           qcheck_core;
           logs_lwt;
           alcotezt;
           tezt_lib;
           mavkit_client_base_unix |> open_;
           mavkit_smart_rollup_lib |> open_;
           mavkit_smart_rollup_node_lib |> open_;
           mavkit_layer2_store |> open_;
         ]
        @ protocol_deps)
  in
  tezt
    ["canary"; "test_context_gc"; "test_store_gc"]
    ~path:"src/lib_smart_rollup_node/test/"
    ~opam:"mavryk-smart-rollup-node-lib-test"
    ~synopsis:"Tests for the smart rollup node library"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives"
        |> open_ ~m:"TzPervasives.Error_monad";
        mavkit_stdlib_unix |> open_;
        mavkit_test_helpers |> open_;
        mavkit_layer2_store |> open_;
        mavkit_smart_rollup_lib |> open_;
        mavkit_smart_rollup_node_lib |> open_;
        helpers |> open_;
        alcotezt;
      ]

let mavkit_scoru_wasm_debugger_plugin =
  public_lib
    "mavkit-smart-rollup-wasm-debugger-plugin"
    ~path:"src/bin_wasm_debugger/plugin"
    ~release_status:Released
    ~deps:[]
    ~synopsis:"Plugin interface for the Mavkit Smart Rollup WASM Debugger"

let mavkit_scoru_wasm_debugger_lib =
  public_lib
    "mavkit-smart-rollup-wasm-debugger-lib"
    ~path:"src/lib_wasm_debugger"
    ~synopsis:"Mavryk: Library used for the Smart Rollups' WASM debugger"
    ~release_status:Released
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_clic;
        tree_encoding;
        mavkit_base_unix;
        (* The debugger always rely on proto_alpha, as such the client is always
           available. *)
        Protocol.(client_exn alpha);
        cohttp_lwt_unix;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_helpers |> open_;
        mavkit_smart_rollup_lib;
        mavkit_webassembly_interpreter |> open_;
        mavkit_webassembly_interpreter_extra |> open_;
        mavkit_version_value;
        mavkit_scoru_wasm_debugger_plugin;
        dynlink;
        lambda_term;
      ]

let _mavkit_scoru_wasm_debugger =
  public_exe
    (sf "mavkit-smart-rollup-wasm-debugger")
    ~internal_name:(sf "main_wasm_debugger")
    ~path:"src/bin_wasm_debugger"
    ~opam:"mavkit-smart-rollup-wasm-debugger"
    ~synopsis:"Mavryk: Debugger for the smart rollups’ WASM kernels"
    ~release_status:Released
    ~with_macos_security_framework:true
    ~deps:[mavkit_scoru_wasm_debugger_lib |> open_]

let _mavkit_scoru_wasm_regressions =
  tezt
    ["mavryk_scoru_wasm_regressions"]
    ~path:"src/lib_scoru_wasm/regressions"
    ~opam:"mavryk-scoru-wasm-regressions"
    ~synopsis:"WASM PVM regressions"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_scoru_wasm |> open_;
        mavkit_scoru_wasm_helpers;
        mavkit_test_helpers;
        Protocol.(main alpha);
        Protocol.(mavkit_sc_rollup alpha) |> if_some |> open_;
        Protocol.(parameters_exn alpha);
        tezt_lib |> open_ |> open_ ~m:"Base";
      ]
    ~dep_files:
      [
        "../../proto_alpha/lib_protocol/test/integration/wasm_kernel/echo.wast";
        "../test/wasm_kernels/tx-kernel-no-verif.wasm";
        "../test/messages/deposit.out";
        "../test/messages/withdrawal.out";
      ]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let mavryk_time_measurement =
  external_lib ~opam:"" "mavryk-time-measurement" V.True

let tezt_risc_v_sandbox =
  private_lib
    "tezt_risc_v_sandbox"
    ~path:"tezt/lib_risc_v_sandbox"
    ~opam:"tezt-risc-v-sandbox"
    ~synopsis:"Test framework for RISC-V sandbox"
    ~bisect_ppx:No
    ~deps:[tezt_wrapper |> open_ |> open_ ~m:"Base"; tezt_mavryk]
    ~release_status:Unreleased

let _tezt_long_tests =
  private_exe
    "main"
    ~opam:""
    ~path:"tezt/long_tests"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_ |> open_ ~m:"Runnable.Syntax";
        tezt_performance_regression |> open_;
        mavkit_lwt_result_stdlib |> open_;
        Protocol.(test_helpers_exn alpha);
        mavkit_micheline;
        mavkit_openapi;
        Protocol.(main alpha);
        qcheck_core;
        mavryk_time_measurement;
        data_encoding;
        mavkit_event_logging |> open_;
        mavkit_test_helpers |> open_;
      ]

let _tezt_manual_tests =
  private_exe
    "main"
    ~opam:""
    ~path:"tezt/manual_tests"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_test_helpers |> open_;
        tezt_wrapper |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_;
        yes_wallet_lib;
      ]

let _tezt_remote_tests =
  private_exe
    "main"
    ~opam:""
    ~path:"tezt/remote_tests"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~deps:[tezt_lib |> open_ |> open_ ~m:"Base"; tezt_mavryk |> open_]

let _tezt_snoop =
  private_exe
    "main"
    ~opam:""
    ~path:"tezt/snoop"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~deps:[tezt_lib |> open_ |> open_ ~m:"Base"; tezt_mavryk |> open_]

let _tezt_vesting_contract_test =
  private_exe
    "main"
    ~opam:""
    ~path:"tezt/vesting_contract_test"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~deps:
      [
        tezt_lib |> open_ |> open_ ~m:"Base";
        tezt_mavryk |> open_;
        mavkit_stdlib;
        mavkit_test_helpers;
        mavkit_micheline;
        Protocol.(main alpha);
        ptime;
      ]

let _docs_doc_gen =
  private_exes
    ["rpc_doc"; "p2p_doc"]
    ~opam:""
    ~path:"docs/doc_gen"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~release_status:Unreleased
    ~deps:
      ([
         mavkit_base |> open_ ~m:"TzPervasives";
         mavkit_rpc;
         mavkit_stdlib_unix |> open_;
         mavkit_shell |> open_;
         mavkit_rpc_http_server;
         mavkit_store |> open_;
         mavkit_protocol_updater |> open_;
         mavkit_node_config |> open_;
         data_encoding;
         re;
       ]
      @ List.map Protocol.embedded (Protocol.genesis :: Protocol.active))

let _docs_doc_gen_errors =
  private_exe
    "error_doc"
    ~opam:""
    ~path:"docs/doc_gen/errors"
    ~bisect_ppx:No
    ~with_macos_security_framework:true
    ~release_status:Unreleased
    ~linkall:true
    ~deps:
      [
        mavkit_base |> open_;
        mavkit_error_monad |> open_;
        data_encoding |> open_;
        Protocol.(client_exn alpha) |> open_;
      ]
