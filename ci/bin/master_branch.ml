(*****************************************************************************)
(*                                                                           *)
(* SPDX-License-Identifier: MIT                                              *)
(* Copyright (c) 2024 Nomadic Labs. <contact@nomadic-labs.com>               *)
(*                                                                           *)
(*****************************************************************************)

(* This module defines the jobs of the [master_branch] pipeline.

   This pipeline runs for each merge on the [master] branch. To goal
   of this pipeline is to publish artifacts for the development
   version of Octez, including:

   - docker images,
   - static binaries, and
   - documentation. *)

open Common
open Gitlab_ci
open Gitlab_ci.Util
open Tezos_ci

let jobs =
  let job_docker_rust_toolchain =
    job_docker_rust_toolchain
      ~__POS__ (* Always rebuild on master to reduce risk of tampering *)
      ~always_rebuild:true
      ~rules:[job_rule ~when_:Always ()]
      ()
  in
  let rules_octez_docker_changes_or_master =
    [
      job_rule ~if_:Rules.on_master ~when_:Always ();
      job_rule ~changes:changeset_octez_docker_changes_or_master ();
    ]
  in
  let job_docker_amd64_experimental : tezos_job =
    job_docker_build
      ~__POS__
      ~rules:rules_octez_docker_changes_or_master
      ~arch:Amd64
      Experimental
  in
  let job_docker_arm64_experimental : tezos_job =
    job_docker_build
      ~__POS__
      ~rules:rules_octez_docker_changes_or_master
      ~arch:Arm64
      Experimental
  in
  let job_docker_merge_manifests =
    job_docker_merge_manifests
      ~__POS__
      ~ci_docker_hub:true
        (* TODO: In theory, actually uses either release or
           experimental variant of docker jobs depending on
           pipeline. In practice, this does not matter as these jobs
           have the same name in the generated files
           ([oc.build:ARCH]). However, when the merge_manifest jobs
           are created directly in the appropriate pipeline, the
           correcty variant must be used. *)
      ~job_docker_amd64:job_docker_amd64_experimental
      ~job_docker_arm64:job_docker_arm64_experimental
  in
  let job_static_arm64 =
    job_build_static_binaries
      ~__POS__
      ~arch:Arm64
      ~rules:[job_rule ~when_:Always ()]
      ()
  in
  let job_static_x86_64 =
    job_build_static_binaries
      ~__POS__
      ~arch:Amd64
      ~rules:[job_rule ~when_:Always ()]
      ()
  in
  let job_unified_coverage_default : tezos_job =
    job
      ~__POS__
      ~image:Images.runtime_build_test_dependencies
      ~name:"oc.unified_coverage"
      ~stage:Stages.test_coverage
      ~variables:
        [
          ("PROJECT", Predefined_vars.(show ci_project_path));
          ("DEFAULT_BRANCH", Predefined_vars.(show ci_commit_sha));
        ]
      ~allow_failure:Yes
      ~before_script:
        ((* sets COVERAGE_OUTPUT *)
         before_script ~source_version:true [])
      ~when_:Always
      ~coverage:"/Coverage: ([^%]+%)/"
      [
        (* On the project default branch, we fetch coverage from the last merged MR *)
        "mkdir -p _coverage_report";
        "dune exec scripts/ci/download_coverage/download.exe -- -a \
         from=last-merged-pipeline --info --log-file \
         _coverage_report/download_coverage.log";
        "./scripts/ci/report_coverage.sh";
      ]
    |> enable_coverage_location |> enable_coverage_report
  in
  let job_publish_documentation : tezos_job =
    job
      ~__POS__
      ~name:"publish:documentation"
      ~image:Images.runtime_build_test_dependencies
      ~stage:Stages.doc
      ~dependencies:(Dependent [])
      ~before_script:
        (before_script
           ~eval_opam:true
             (* Load the environment poetry previously created in the docker image.
                Give access to the Python dependencies/executables. *)
           ~init_python_venv:true
           [
             {|echo "${CI_PK_GITLAB_DOC}" > ~/.ssh/id_ed25519|};
             {|echo "${CI_KH}" > ~/.ssh/known_hosts|};
             {|chmod 400 ~/.ssh/id_ed25519|};
           ])
      ~interruptible:false
      ~rules:[job_rule ~changes:changeset_octez_docs ~when_:On_success ()]
      ["./scripts/ci/doc_publish.sh"]
  in
  (* Smart Rollup: Kernel SDK

     See [src/kernel_sdk/RELEASE.md] for more information. *)
  let job_publish_kernel_sdk : tezos_job =
    job
      ~__POS__
      ~name:"publish_kernel_sdk"
      ~image:Images.rust_toolchain
      ~stage:Stages.manual
      ~rules:
        [
          (* This job is in the last stage {!Stages.manual} so we
             can disallow failure without blocking the pipeline.
             Furthermore, unlike other manual jobs, this is not
             an "optional" job for which failures are
             tolerated. *)
          job_rule ~when_:Manual ~allow_failure:No ();
        ]
      ~allow_failure:Yes
      ~dependencies:(Dependent [Artifacts job_docker_rust_toolchain])
      ~interruptible:false
      ~variables:
        [("CARGO_HOME", Predefined_vars.(show ci_project_dir) // "cargo")]
      ~cache:[{key = "kernels"; paths = ["cargo/"]}]
      [
        "make -f kernels.mk publish-sdk-deps";
        (* Manually set SSL_CERT_DIR as default setting points to empty dir *)
        "SSL_CERT_DIR=/etc/ssl/certs CC=clang make -f kernels.mk publish-sdk";
      ]
  in
  (* arm builds are manual on the master branch pipeline *)
  let build_arm_rules = [job_rule ~when_:Manual ~allow_failure:Yes ()] in
  let job_build_arm64_release =
    job_build_arm64_release ~rules:build_arm_rules ()
  in
  let job_build_arm64_exp_dev_extra =
    job_build_arm64_exp_dev_extra ~rules:build_arm_rules ()
  in
  [
    (* Stage: build *)
    job_docker_rust_toolchain;
    job_static_x86_64;
    job_static_arm64;
    job_build_arm64_release;
    job_build_arm64_exp_dev_extra;
    job_docker_amd64_experimental;
    job_docker_arm64_experimental;
    (* Stage: test_coverage *)
    job_unified_coverage_default;
    (* Stage: doc *)
    job_publish_documentation;
    (* Stage: prepare_release *)
    job_docker_merge_manifests;
    (* Stage: manual *)
    job_publish_kernel_sdk;
  ]
