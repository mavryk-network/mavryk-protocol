This directory contains some script and Dockerfile used to start a evm
sequencer rollup.

This document does not explain how smart rollup, smart rollup node,
evm node and the sequencer kernel works.

The following directory allows to initialise an mavkit-node on a
specified network, originate a new evm rollup and start a rollup and
sequencer node.

The script assume the use of only 1 operator key for the rollup node.

First step is to create an `.env` containing all necessary variables:

```
# network to use
# warning: date dependent variables won't be correctly interpreted in compose.yml
MVNETWORK=${MVNETWORK:-"basenet"}

# tag to use for the mavryk docker. default to `master`
MAVKIT_TAG=${MAVKIT_TAG:-master}

# directory where all data dir are placed, default to `./.etherlink-${MVNETWORK}-data`
HOST_MAVRYK_DATA_DIR=${HOST_MAVRYK_DATA_DIR:-"$PWD/.etherlink-$MVNETWORK-data"}

# network used to initialize the mavkit node configuration
MVNETWORK_ADDRESS=${MVNETWORK_ADDRESS:-"https://teztnets.com/$MVNETWORK"}

# snapshot to use to start the mavkit node
SNAPSHOT_URL=${SNAPSHOT_URL-"https://snapshots.eu.tzinit.org/$MVNETWORK/rolling"}

# address of faucet to use with @tacoinfra/get-tez
FAUCET=${FAUCET:-"https://faucet.$MVNETWORK.teztnets.com"}

# endpoint to use to originate the smart rollup.
# it could be possible to use the local node but it
# would require then to first start the mavkit-node sepratatly from the docker compose.
ENDPOINT=${ENDPOINT:-"https://rpc.$MVNETWORK.teztnets.com"}

## Contract options

# alias to use for the exchanger
EXCHANGER_ALIAS=${EXCHANGER_ALIAS-"exchanger"}
# alias to use for the bridge
BRIDGE_ALIAS=${BRIDGE_ALIAS-"bridge"}
# alias to use for the delayed bridge
DELAYED_BRIDGE_ALIAS=${DELAYED_BRIDGE_ALIAS-"delayed_bridge"}
# alias to use for the evm admin contract
EVM_ADMIN_ALIAS=${EVM_ADMIN_ALIAS-"evm_admin"}
# alias to use for the evm admin contract
SEQUENCER_GOVERNANCE_ALIAS=${SEQUENCER_GOVERNANCE_ALIAS-"sequencer_governance"}

## Rollup options

# alias to use for for rollup node operator default acount.
OPERATOR_ALIAS=${OPERATOR_ALIAS:-"operator"}
MINIMUM_OPERATOR_BALANCE=${MINIMUM_OPERATOR_BALANCE:-10000}
# alias to use for the address that originate the rollup. Different from
# the operator to prevent some failure with 1M when reseting the rollup node.
ORIGINATOR_ALIAS=${ORIGINATOR_ALIAS:-"originator"}
# alias to use for rollup.
ROLLUP_ALIAS=${ROLLUP_ALIAS:-"evm_rollup"}
# the used mode for the rollup node
ROLLUP_NODE_MODE=${ROLLUP_NODE_MODE:-"batcher"}
# the chain_id
EVM_CHAIN_ID=${EVM_CHAIN_ID:-123123}
# ethereum accounts
EVM_ACCOUNTS=("6ce4d79d4e77402e1ef3417fdda433aa744c6e1c" "b53dc01974176e5dff2298c5a94343c2585e3c54" "9b49c988b5817be31dfb00f7a5a4671772dcce2b")
# sequencer address alias
SEQUENCER_ALIAS=${SEQUENCER_ALIAS:-"sequencer"}
# sequencer secret key
SEQUENCER_SECRET_KEY=${SEQUENCER_SECRET_KEY:-"edsk3gUfUPyBSfrS9CCgmCiQsTCHGkviBDusMxDJstFtojtc1zcpsh"}
# evm kernel kernel config base file
EVM_KERNEL_CONFIG=${EVM_KERNEL_CONFIG:-"$PWD/evm_config.yaml"}
```

You can you the dailynet by only setting `MVNETWORK` and removing `SNAPSHOT_URL`:
```
export MVNETWORK="dailynet-$(date +%Y-%m-%d)"
export SNAPSHOT_URL=""
```

Then when the variables are defined, or default value is valid you can initialise the mavkit node with:
```
./init.sh init_mavkit_node
```
This initialise the mavkit-node configuration, download the snapshot
and import it.

If you need the mavryk contracts to be deployed, you can run the command:
```
./init.sh originate_contracts
```
By default, this originates the exchanger contract, the bridge contract, the evm admin contract and the sequencer admin contract. It will also update the kernel config.
If you don't want to include one of the contracts, you cat set their alias to `""`.
You can modify the base kernel config by modifying the file `evm_config.yaml` (or the file given with `${SEQUENCER_CONFIG}`).

Last step before running the docker compose is to bootstrap the rollup environment:
```
./init.sh init_rollup
```
This generate a new account, wait until the address has enough mv.
Then it build the evm kernel and originate a new rollup with it.
And finally initialise the rollup node configuration.


then start all node:
```
docker compose up
```
