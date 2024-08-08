#!/bin/sh

cat << EOT
This script is deprecated.

To update dependencies, you have to:

- in mavryk-network/mavryk-protocol:
  - update version constraints in manifest/ and run: make -C manifest
  - update full_opam_repository_tag in: scripts/version.sh
  - update the lock file in: opam/virtual/mavkit-deps.opam.locked
    (for instance using: scripts/update_opam_lock.sh)

- in tezos/opam-repository:
  - update opam_repository_commit_hash in: scripts/version.sh
    (to match full_opam_repository_tag from scripts/version.sh from mavryk-network/mavryk-protocol)
  - update the opam lock file: mavkit-deps.opam.locked
    (copy opam/virtual/mavkit-deps.opam.locked from mavryk-network/mavryk-protocol)

More information in the documentation:
https://protocol.mavryk.org/developer/contributing-adding-a-new-opam-dependency.html
EOT

exit 1
