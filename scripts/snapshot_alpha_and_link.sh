#!/usr/bin/env bash

set -e

usage="Usage:

$ ./scripts/snapshot_alpha_and_link.sh [<version_number> [<name>]]

This packs the current proto_alpha directory in a new
proto_<version_number>_<hash> directory with all the necessary renamings.
It then updates .gitlab-ci.yml and links the protocol in the node, client and codec.

<version_number> defaults to the the last snapshotted protocol number
plus one. <name> defaults to 'next'. <version_number> must also be
given to give <name>, in that order.
"

script_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"
cd "$script_dir"/..

if [ "${1:-}" = "--help" ]; then
  echo "$usage"
  exit 1
fi

if [ -z "${1:-}" ]; then
    last_proto_name=$(find . -name "proto_[0-9][0-9][0-9]_*" | awk -F'/' '{print $$NF}' | sort -r | head -1)
    last_proto_version=$(echo "$last_proto_name" | cut -d'_' -f2 | sed 's/^0*//')
    new_proto_version_int=$(( last_proto_version+1 ))
    new_proto_version=$(printf "%03d" "$new_proto_version_int")
    version_number=$new_proto_version
else
    version_number="$1"
fi

if [ -z "${2:-}" ]; then
    name="next"
else
    name="$2"
fi

echo "snapshot_alpha.sh ${name}_${version_number}"
SILENCE_REMINDER=yes "$script_dir"/snapshot_alpha.sh "${name}"_"${version_number}"

dir=$(ls -d src/proto_"${version_number}"_*)

if [ -z "$dir" ]; then
  echo "Failed to find where the protocol was snapshotted."
  exit 1
fi

short_hash=$(basename "$dir" | awk -F'_' '{print $3}')

if [ -z "$short_hash" ]; then
  echo "Failed to extract protocol short hash from directory name: $dir"
  exit 1
fi

echo "link_protocol.sh src/proto_${version_number}_${short_hash}"
"$script_dir"/link_protocol.sh src/proto_"${version_number}"_"${short_hash}"

echo "Done. You can now commit everything."
echo "Don't forget to: git add src/proto_${version_number}_${short_hash} docs/${version_number}"
