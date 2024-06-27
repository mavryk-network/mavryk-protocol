(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2021-2023 Nomadic Labs <contact@nomadic-labs.com>           *)
(* Copyright (c) 2022-2023 Trili Tech <contact@trili.tech>                   *)
(* Copyright (c) 2023 Marigold <contact@marigold.dev>                        *)
(*                                                                           *)
(*****************************************************************************)

open Manifest
open Externals
open Internals
open Product_mavkit

include Product (struct
  let name = "etherlink"
end)

let tezt_etherlink =
  private_lib
    "tezt_etherlink"
    ~path:"etherlink/tezt/lib"
    ~opam:"tezt-etherlink"
    ~bisect_ppx:No
    ~deps:
      [
        tezt_wrapper |> open_ |> open_ ~m:"Base";
        tezt_performance_regression |> open_;
        mavkit_crypto;
        tezt_tezos |> open_;
      ]
    ~release_status:Unreleased

(* Container of the registered sublibraries of [mavkit-evm-node] *)
let registered_mavkit_evm_node_libs = Sub_lib.make_container ()

(* Registers a sub-library in the [mavkit-evm-node] package. *)
let mavkit_evm_node_lib =
  Sub_lib.sub_lib
    ~package_synopsis:"Octez EVM node libraries"
    ~container:registered_mavkit_evm_node_libs
    ~package:"mavkit-evm-node-libs"

let evm_node_config =
  mavkit_evm_node_lib
    "evm_node_config"
    ~path:"etherlink/bin_node/config"
    ~synopsis:"Configuration for the EVM node"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server;
        mavkit_stdlib_unix |> open_;
      ]

let evm_node_lib_prod_encoding =
  mavkit_evm_node_lib
    "evm_node_lib_prod_encoding"
    ~path:"etherlink/bin_node/lib_prod/encodings"
    ~synopsis:
      "EVM encodings for the EVM node and plugin for the WASM Debugger [prod \
       version]"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavkit_scoru_wasm_debugger_plugin]

let _evm_node_sequencer_protobuf =
  let protobuf_rules =
    Dune.[protobuf_rule "narwhal"; protobuf_rule "exporter"]
  in
  mavkit_evm_node_lib
    "evm_node_sequencer_protobuf"
    ~path:"etherlink/bin_node/lib_sequencer_protobuf"
    ~synopsis:
      "gRPC libraries for interacting with a consensus node, generated from \
       protobuf definitions"
    ~deps:[ocaml_protoc_compiler]
    ~dune:protobuf_rules

let evm_node_migrations =
  mavkit_evm_node_lib
    "evm_node_migrations"
    ~path:"etherlink/bin_node/migrations"
    ~synopsis:"SQL migrations for the EVM node store"
    ~deps:[mavkit_base |> open_ ~m:"TzPervasives"; caqti_lwt; crunch; re]
    ~dune:
      Dune.
        [
          [
            S "rule";
            [S "target"; S "migrations.ml"];
            [S "deps"; [S "glob_files"; S "*.sql"]];
            [
              S "action";
              [
                S "run";
                S "ocaml-crunch";
                S "-e";
                S "sql";
                S "-m";
                S "plain";
                S "-o";
                S "%{target}";
                S "-s";
                S ".";
              ];
            ];
          ];
        ]

let evm_node_lib_prod =
  mavkit_evm_node_lib
    "evm_node_lib_prod"
    ~path:"etherlink/bin_node/lib_prod"
    ~synopsis:
      "An implementation of a subset of Ethereum JSON-RPC API for the EVM \
       rollup [prod version]"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server;
        mavkit_workers |> open_;
        mavkit_rpc_http_client_unix;
        mavkit_version_value;
        mavkit_stdlib_unix |> open_;
        evm_node_lib_prod_encoding |> open_;
        lwt_watcher;
        lwt_exit;
        caqti;
        caqti_lwt;
        caqti_lwt_unix;
        caqti_sqlite;
        mavkit_client_base |> open_;
        evm_node_config |> open_;
        mavkit_context_sigs;
        mavkit_context_disk;
        mavkit_context_encoding;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_helpers |> open_;
        mavkit_scoru_wasm_debugger_lib |> open_;
        mavkit_layer2_store |> open_;
        mavkit_smart_rollup_lib |> open_;
        evm_node_migrations;
      ]

let evm_node_lib_dev_encoding =
  mavkit_evm_node_lib
    "evm_node_lib_dev_encoding"
    ~path:"etherlink/bin_node/lib_dev/encodings"
    ~synopsis:
      "EVM encodings for the EVM node and plugin for the WASM Debugger [dev \
       version]"
    ~deps:
      [mavkit_base |> open_ ~m:"TzPervasives"; mavkit_scoru_wasm_debugger_plugin]

let evm_node_lib_dev =
  mavkit_evm_node_lib
    "evm_node_lib_dev"
    ~path:"etherlink/bin_node/lib_dev"
    ~synopsis:
      "An implementation of a subset of Ethereum JSON-RPC API for the EVM \
       rollup [dev version]"
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server;
        mavkit_workers |> open_;
        mavkit_rpc_http_client_unix;
        mavkit_version_value;
        mavkit_stdlib_unix |> open_;
        evm_node_lib_dev_encoding |> open_;
        lwt_watcher;
        lwt_exit;
        caqti;
        caqti_lwt;
        caqti_lwt_unix;
        caqti_sqlite;
        mavkit_client_base |> open_;
        evm_node_config |> open_;
        mavkit_context_sigs;
        mavkit_context_disk;
        mavkit_context_encoding;
        mavkit_scoru_wasm;
        mavkit_scoru_wasm_helpers |> open_;
        mavkit_scoru_wasm_debugger_lib |> open_;
        mavkit_layer2_store |> open_;
        mavkit_smart_rollup_lib |> open_;
        evm_node_migrations;
      ]

let _mavkit_evm_node_tests =
  tezt
    ["test_rlp"; "test_ethbloom"]
    ~path:"etherlink/bin_node/test"
    ~opam:"mavkit-evm-node-tests"
    ~synopsis:"Tests for the EVM Node"
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_base_test_helpers |> open_;
        mavkit_test_helpers |> open_;
        qcheck_alcotest;
        alcotezt;
        evm_node_lib_prod;
        evm_node_lib_dev;
      ]

let _tezt_etherlink =
  tezt
    ["evm_rollup"; "evm_sequencer"]
    ~path:"etherlink/tezt/tests"
    ~opam:"tezt-etherlink"
    ~synopsis:"Tezt integration tests for Etherlink"
    ~deps:
      [
        mavkit_test_helpers |> open_;
        tezt_wrapper |> open_ |> open_ ~m:"Base";
        tezt_tezos |> open_ |> open_ ~m:"Runnable.Syntax";
        tezt_etherlink |> open_;
        Protocol.(main alpha);
      ]
    ~with_macos_security_framework:true
    ~dep_globs:
      ["evm_kernel_inputs/*"; "../../tezos_contracts/*"; "../../config/*"]
    ~dep_globs_rec:["../../kernel_evm/*"]
    ~preprocess:[staged_pps [ppx_import; ppx_deriving_show]]

let _evm_node =
  public_exe
    (sf "mavkit-evm-node")
    ~internal_name:(sf "main")
    ~path:"etherlink/bin_node"
    ~opam:"mavkit-evm-node"
    ~synopsis:
      "An implementation of a subset of Ethereum JSON-RPC API for the EVM \
       rollup"
    ~release_status:Experimental
    ~with_macos_security_framework:true
    ~deps:
      [
        mavkit_base |> open_ ~m:"TzPervasives";
        mavkit_base_unix;
        mavkit_stdlib_unix |> open_;
        mavkit_clic;
        mavkit_rpc_http |> open_;
        mavkit_rpc_http_server;
        mavkit_version_value;
        mavkit_client_base |> open_;
        mavkit_client_base_unix |> open_;
        evm_node_lib_prod;
        evm_node_lib_dev;
        evm_node_config |> open_;
      ]
    ~bisect_ppx:Yes

let _tezt_testnet_scenarios =
  public_exe
    "mavkit-testnet-scenarios"
    ~internal_name:"main"
    ~path:"src/bin_testnet_scenarios"
    ~synopsis:"Run scenarios on testnets"
    ~bisect_ppx:No
    ~static:false
    ~deps:
      [
        mavkit_test_helpers |> open_;
        tezt_wrapper |> open_ |> open_ ~m:"Base";
        tezt_tezos |> open_ |> open_ ~m:"Runnable.Syntax";
        tezt_etherlink |> open_;
      ]
