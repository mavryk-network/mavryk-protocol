#!/bin/sh

set -eu

if [ -n "${TRACE:-}" ]; then set -x; fi

if [ -z "${TZ_FLAKE_TEST_TESTS}" ]; then
   echo "TZ_FLAKE_TEST_TESTS is undefined, do set it in the pipeline variables"
   exit 1
fi

TZ_FLAKE_TEST_LOOP_COUNT=${TZ_FLAKE_TEST_LOOP_COUNT:-10}
TZ_FLAKE_TEST_OPTS=${TZ_FLAKE_TEST_OPTS:-'--display short --no-buffer'}

echo "Running flakiness test for targets TZ_FLAKE_TEST_TESTS=${TZ_FLAKE_TEST_TESTS}, TZ_FLAKE_TEST_LOOP_COUNT=${TZ_FLAKE_TEST_LOOP_COUNT}, TZ_FLAKE_TEST_OPTS=${TZ_FLAKE_TEST_OPTS}"

nb_fail=0
for i in $(seq "$TZ_FLAKE_TEST_LOOP_COUNT"); do
    echo "Starting flake test loop ${i}/${TZ_FLAKE_TEST_LOOP_COUNT}"
    # We need word splitting here to allow the user to select multiple
    # options and tests.
    echo "${TZ_FLAKE_TEST_OPTS} ${TZ_FLAKE_TEST_TESTS}" \
        | xargs -n 9999 -s 9999 -x dune build --force --error-reporting=twice \
        || nb_fail=$((nb_fail + 1))
    echo "Completed flake test loop ${i}/${TZ_FLAKE_TEST_LOOP_COUNT} (failures: ${nb_fail})"
done

if [ ${nb_fail} -gt 0 ]; then
    exit 1
fi
