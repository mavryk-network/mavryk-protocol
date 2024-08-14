#!/bin/sh
set -eu

# test the version associated to a git tag. Here we use
# a random version and we check if it is correctly parsed
# The script mavryk-version prints the
# same version displayed by mavkit-node --version

VERSION='10.94'
RANDOMTAG='testtesttest'
TESTBRANCH="$RANDOMTAG"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

test_version() {
  rm -f _build/default/src/lib_version/generated_git_info.ml
  res=$(dune exec mavkit-version || :)
  if [ "$res" != "$1" ]; then
    echo "Expected version '$1', got '$res' => FAIL"
    exit 1
  else
    echo "Tag '$2', expected version '$res' => PASS"
  fi
}

cleanup() {
  set +e
  git tag -d "mavkit-$VERSION" > /dev/null 2>&1
  git tag -d "mavkit-v$VERSION" > /dev/null 2>&1
  git tag -d "mavkit-v$VERSION"+rc1 > /dev/null 2>&1
  git tag -d "mavkit-v$VERSION"-rc1 > /dev/null 2>&1
  git checkout "$CURRENT_BRANCH"
  git branch -D "$TESTBRANCH" > /dev/null 2>&1
  set -e
}

trap cleanup EXIT INT

cleanup

git checkout -b "$TESTBRANCH"

git tag "mavkit-$VERSION" -m "test"
test_version "Mavkit $VERSION" "$VERSION"

git tag "mavkit-v$VERSION" -m "test"
test_version "Mavkit $VERSION" "mavkit-v$VERSION"

git commit --allow-empty -m "test" > /dev/null 2>&1
test_version "Mavkit $VERSION+dev" "$(git describe --tags)"

git tag "mavkit-v$VERSION+rc1" -m "test"
test_version "Mavkit $VERSION+dev" "mavkit-v$VERSION+rc1"

git tag "mavkit-v$VERSION-rc1" -m "test"
test_version "Mavkit $VERSION~rc1" "mavkit-v$VERSION-rc1"

git commit --allow-empty -m "test" > /dev/null 2>&1
test_version "Mavkit $VERSION~rc1+dev" "$(git describe --tags)"

git checkout -

cleanup
