# CI guideline

This document describes the operating principles of the source code
around the CI.

# Implementation of job `script`s

## Inline scripts

I.e., having the `script` in the YAML definition of the job. Inline
scripts MUST only be used for small job definitions (less than 5
lines) that do not use any control flow.

## Calling out to a script

`script` definitions longer than 5 lines of code (excluding comments)
OR that use control-flow MUST be placed in a separate shell
script. This shell script should be named after the job and placed in
the same folder as it's definition. Example:
`.gitlab/ci/jobs/script:snapshot_alpha_and_link.sh`.

Conversely, if a script is ONLY to be used in the CI (e.g. not for
local use), and it's ONLY usage is in the `(before_|after_)script:`
definition of a single CI job, then it MUST be named as per the rule
above.

Examples:

  - `.gitlab/ci/jobs/prepare_release/docker:merge_manifests.sh` this
    script is typically only used in the CI, and is only used in one
    job. Therefore, it's naming is correct.
 - The job `semgrep` defined in `.gitlab/jobs/test/semgrep.yml` calls
   out to `./scripts/semgrep/lint-all-ocaml-sources.sh` in its
   `script:` section. However, this script is also intended for local
   use. Therefore, this script should not be renamed
   `.gitlab/jobs/test/semgrep.sh`.

## The case of templates

The above rules also applies to GitLab CI job templates, removing the
initial `.` in the name of the template. In other words, the `script`
of the template `.build` defined in `.gitlab/ci/jobs/build/common.yml`
should call `.gitlab/ci/jobs/build/build.sh`.

## `before_script` and `after_script`

The same rules also apply to `before_script` and `after_script`.  If
the definition must be outlined, then the scripts should be called
`JOB_NAME_before.sh` respectively `JOB_NAME_after.sh`.
