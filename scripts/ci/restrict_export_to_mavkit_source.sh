#!/bin/bash
set -eu

# shellcheck source=./scripts/ci/mavkit-release.sh
. ./scripts/ci/mavkit-release.sh

# Adds export-ignore for each part of the repo that is not part of mavkit
ignore="$(comm -2 -3 <(find . -maxdepth 1 | sed 's|^./||' | sort) <(sort "${mavkit_source_content}"))"
for e in $ignore; do
  if ! [ "$e" = "." ] && ! [ "$e" = ".." ]; then
    echo "$e export-ignore" >> ./.gitattributes
  fi
done
