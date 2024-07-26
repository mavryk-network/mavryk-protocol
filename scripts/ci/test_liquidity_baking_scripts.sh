#!/bin/sh
set -eu

# The first argument of the script is the commit hash used to
# fetch the reference scripts. It cannot be changed for injected
# protocols.
./scripts/check-liquidity-baking-scripts.sh 7dca3e2d6aeb1603cc6685c87f57bba4971f7a5a src/proto_001_PtAtLas 3

# However, for the alpha protocol, it is possible to modify the
# scripts, and therefore to update the hash.
./scripts/check-liquidity-baking-scripts.sh 7dca3e2d6aeb1603cc6685c87f57bba4971f7a5a src/proto_alpha 10
