#!/bin/sh

set -eu

usage() {
  echo "Usage: $0 <protocol-trashbin>"
  echo "Restores the protocols stored in <protocol-trashbin>."
  echo "This reverses the effect of 'scripts/remove-old-protocols.sh <protocol-trashbin>'"
  exit 1
}

trash_bin=""
if [ -n "${1:-}" ] && [ "${1:-}" != "--help" ]; then
  trash_bin=$1
else
  usage
fi

if [ "$(find $trash_bin -maxdepth 1 -type f | wc -l)" -gt 0 ]; then
  for protocol in "$trash_bin"/*; do
    echo mv "$protocol" src
    mv "$protocol" src
  done
fi
