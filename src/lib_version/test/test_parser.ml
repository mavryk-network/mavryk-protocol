(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs. <contact@nomadic-labs.com>               *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(*                                                                           *)
(*****************************************************************************)

(** Testing
    _______
    Component: lib_version
    Invocation: dune exec src/lib_version/test/main.exe \
                  -- --file test_parser.ml
    Subject: Test versions parser
 *)

let mavkit_legal_versions =
  [
    ( "mavkit-10.93",
      {
        product = Mavkit;
        Version.major = 10;
        minor = 93;
        additional_info = Release;
      } );
    ( "mavkit-v10.93",
      {
        product = Mavkit;
        Version.major = 10;
        minor = 93;
        additional_info = Release;
      } );
    ( "mavkit-10.93+dev",
      {product = Mavkit; Version.major = 10; minor = 93; additional_info = Dev}
    );
    ( "mavkit-10.93-rc1",
      {product = Mavkit; Version.major = 10; minor = 93; additional_info = RC 1}
    );
    ( "mavkit-10.93-rc1+dev",
      {
        product = Mavkit;
        Version.major = 10;
        minor = 93;
        additional_info = RC_dev 1;
      } );
    ( "mavkit-10.93-beta1",
      {
        product = Mavkit;
        Version.major = 10;
        minor = 93;
        additional_info = Beta 1;
      } );
    ( "mavkit-10.93-beta1+dev",
      {
        product = Mavkit;
        Version.major = 10;
        minor = 93;
        additional_info = Beta_dev 1;
      } );
  ]

let etherlink_legal_versions =
  [
    ( "etherlink-10.93",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = Release;
      } );
    ( "etherlink-v10.93",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = Release;
      } );
    ( "etherlink-10.93+dev",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = Dev;
      } );
    ( "etherlink-10.93-rc1",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = RC 1;
      } );
    ( "etherlink-10.93-rc1+dev",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = RC_dev 1;
      } );
    ( "etherlink-10.93-beta1",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = Beta 1;
      } );
    ( "etherlink-10.93-beta1+dev",
      {
        product = Etherlink;
        Version.major = 10;
        minor = 93;
        additional_info = Beta_dev 1;
      } );
  ]

let parse_version s = Mavryk_version_parser.version_tag (Lexing.from_string s)

let eq v1 v2 =
  let open Version in
  let additional_info_eq a1 a2 =
    match (a1, a2) with
    | Dev, Dev -> true
    | Dev, _ -> false
    | Beta n1, Beta n2 | Beta_dev n1, Beta_dev n2 -> n1 = n2
    | Beta _, _ | Beta_dev _, _ -> false
    | RC n1, RC n2 | RC_dev n1, RC_dev n2 -> n1 = n2
    | RC _, _ | RC_dev _, _ -> false
    | Release, Release -> true
    | Release, _ -> false
  in
  match (v1, v2) with
  | Some v1, Some v2 ->
      v1.major = v2.major && v1.minor = v2.minor
      && additional_info_eq v1.additional_info v2.additional_info
  | _, _ -> false

let version_typ : Mavryk_version_parser.t option Check.typ =
  Check.equalable
    (fun ppf -> function
      | Some v -> Mavryk_version_parser.pp ppf v
      | None -> Mavryk_version_parser.(pp ppf default))
    eq

let () =
  Test.register
    ~__FILE__
    ~title:"Version: Test Mavkit versions parser"
    ~tags:["version"; "mavkit"]
  @@ fun () ->
  ( Fun.flip List.iter mavkit_legal_versions @@ fun (x, e) ->
    Check.(
      (Some e = parse_version x)
        version_typ
        ~error_msg:"Expected %L, got %R"
        ~__LOC__) ) ;
  unit

let () =
  Test.register
    ~__FILE__
    ~title:"Version: Test Etherlink versions parser"
    ~tags:["version"; "etherlink"]
  @@ fun () ->
  ( Fun.flip List.iter etherlink_legal_versions @@ fun (x, e) ->
    Check.(
      (Some e = parse_version x)
        version_typ
        ~error_msg:"Expected %L, got %R"
        ~__LOC__) ) ;
  unit
