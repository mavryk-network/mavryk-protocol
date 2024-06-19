#!/bin/sh

set -e

bin_dir="$(cd "$(dirname "$0")" && echo "$(pwd -P)/")"

: "${BIN_DIR:="/usr/local/bin"}"
: "${DATA_DIR:="/var/run/tezos"}"

: "${NODE_HOST:="node"}"
: "${NODE_RPC_PORT:="8732"}"
# This is the bind address INSIDE the docker so as long as there
# is no explicit port redirection, it is not exposed to the
# outside world.
: "${NODE_RPC_ADDR:="[::]"}"

: "${PROTOCOL:="unspecified-PROTOCOL-variable"}"

# export all these variables to be used in the inc script
export node="$BIN_DIR/mavkit-node"
export client="$BIN_DIR/mavkit-client"
export admin_client="$BIN_DIR/mavkit-admin-client"
export baker="$BIN_DIR/mavkit-baker-$PROTOCOL"
export endorser="$BIN_DIR/mavkit-endorser-$PROTOCOL"
export accuser="$BIN_DIR/mavkit-accuser-$PROTOCOL"
export signer="$BIN_DIR/mavkit-signer"
export smart_rollup_node="$BIN_DIR/mavkit-smart-rollup-node"

export client_dir="$DATA_DIR/client"
export node_dir="$DATA_DIR/node"
export node_data_dir="$node_dir/data"
export smart_rollup_node_data_dir="$DATA_DIR/smart-rollup-node"

# shellcheck source=./scripts/docker/entrypoint.inc.sh
. "$bin_dir/entrypoint.inc.sh"

command=${1:-mavkit-node}
shift 1

case $command in
    mavkit-node)
        launch_node "$@"
        ;;
    mavkit-upgrade-storage)
        upgrade_node_storage
        ;;
    mavkit-snapshot-import)
        snapshot_import "$@"
        ;;
    mavkit-baker)
        launch_baker "$@"
        ;;
    mavkit-baker-test)
        launch_baker_test "$@"
        ;;
    mavkit-endorser)
        launch_endorser "$@"
        ;;
    mavkit-endorser-test)
        launch_endorser_test "$@"
        ;;
    mavkit-accuser)
        launch_accuser "$@"
        ;;
    mavkit-accuser-test)
        launch_accuser_test "$@"
        ;;
    mavkit-client)
        configure_client
        exec "$client" "$@"
        ;;
    mavkit-admin-client)
        configure_client
        exec "$admin_client" "$@"
        ;;
    mavkit-signer)
        exec "$signer" "$@"
        ;;
    mavkit-smart-rollup-node)
        launch_smart_rollup_node "$@"
        ;;
    *)
        cat <<EOF
Available commands:

The following are wrappers around the mavkit binaries.
To call the mavkit binaries directly you must override the
entrypoint using --entrypoint . All binaries are in
$BIN_DIR and the mavryk data in $DATA_DIR

You can specify the network with argument --network, for instance:
  --network carthagenet
(default is mainnet).

Daemons:
- mavkit-node [args]
  Initialize a new identity and run the mavkit node.

- mavkit-smart-rollup-node [args]
  Run the mavkit smart rollup node.

- mavkit-baker [keys]
- mavkit-baker-test [keys]
- mavkit-endorser [keys]
- mavkit-endorser-test [keys]

Clients:
- mavkit-client [args]
- mavkit-signer [args]
- mavkit-admin-client

Commands:
  - mavkit-upgrade-storage
  - mavkit-snapshot-import [args]
    Import a snapshot. The snapshot must be available in the file /snapshot
    Using docker run, you can make it available using the command :
       docker run -v <yourfilename>:/snapshot mavrykdynamics/mavryk mavkit-snapshot-import
    <yourfilename> must be an absolute path.
EOF
        ;;
esac
