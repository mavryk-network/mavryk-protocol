#!/bin/sh

set -eu

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <test-name> <test-package> [<test-package> ...]"
    echo
    echo "Runs the tests in <test-packages>, redirecting the output to \`tests_results/<test-name>.log\`."
    echo "In addition, it outputs a rudimentary JUnit test report file to \`tests_results/<test-name>.xml\`."
    echo
    echo "Example: $0 p2p_and_base @src/lib_p2p/runtest @src/lib_base/runtest"
    exit 1
fi

name=${1:?}
shift

mkdir -p test_results

echo "Running test \"dune build ${COVERAGE_OPTIONS:-} $*\" ..."

START=$(date +%s.%N)

TEST_WRAPPER_REPEAT=${TEST_WRAPPER_REPEAT:-1}

nb_fail=0
for _ in $(seq "$TEST_WRAPPER_REPEAT"); do
    exitcode_file=$(mktemp)
    {
        echo "0" > "$exitcode_file" ;
        # If set, COVERAGE_OPTIONS will typically contain "--instrument-with bisect_ppx".
        # We need this to be word split for the arguments to be properly parsed by dune.
        # shellcheck disable=SC2086
        dune build -j $DUNE_JOBS --force --error-reporting=twice ${COVERAGE_OPTIONS:-} "$@" 2>&1 ||
            echo "$?" > "$exitcode_file" ;
    } | tee "test_results/$name.log"
    EXITCODE=$(cat "$exitcode_file")
    rm "$exitcode_file"

    if [ "$EXITCODE" -eq 0 ]; then
        echo "Ok";
    else
        echo "Error: exited with exitcode $EXITCODE. See full logs in test_results/$name.log"
        nb_fail=$((nb_fail + 1))
    fi
done

END=$(date +%s.%N)

dt=$(echo "$END - $START" | bc)
dd=$(echo "$dt/86400" | bc)
dt2=$(echo "$dt-86400*$dd" | bc)
dh=$(echo "$dt2/3600" | bc)
dt3=$(echo "$dt2-3600*$dh" | bc)
dm=$(echo "$dt3/60" | bc)
ds=$(echo "$dt3-60*$dm" | bc)

LC_NUMERIC=C printf "Total runtime: %02d:%02d:%02.4f\n" "$dh" "$dm" "$ds"

timestamp=$(date -Is)
hostname=$(hostname)

cat > "test_results/$name.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="unittest" errors="0" failures="${nb_fail}" skipped="0" tests="${TEST_WRAPPER_REPEAT}" time="${dt}" timestamp="${timestamp}" hostname="${hostname}">
    <testcase classname="${name}" name="${name}" time="${dt}">
EOF

if ! [ "$nb_fail" -eq 0 ]; then
    msg="Exited with exitcode $EXITCODE."

    # Add link to log artifact when running in CI
    if [ -n "${CI_SERVER_URL:-}" ]; then
        url=$CI_SERVER_URL/$CI_PROJECT_NAMESPACE/$CI_PROJECT_NAME/-/jobs/$CI_JOB_ID/artifacts/file/test_results/$name.log
        msg="$msg See logs at $url"
    fi

    cat >> "test_results/$name.xml" <<EOF
      <failure message="${msg}"/>
EOF
fi

cat >> "test_results/$name.xml" <<EOF
    </testcase>
  </testsuite>
</testsuites>
EOF

if [ "$nb_fail" -gt 0 ]; then
    exit 1
else
    exit 0
fi
