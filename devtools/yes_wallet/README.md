# Yes_wallet script

The purpose of this tool is to extract baker addresses from a node's
context and generate mavkit-client's wallet containing these addresses.
In combination with the yes-node patch it can be used to perform a test
protocol migration (see the relevant documentation page for more details)
or to reproduce contexts where trouble occurred in the past in order to
debug them.

The script can be run using dune:

```shell
dune exec devtools/yes_wallet/yes_wallet.exe -- create from context /path/to/context in /path/to/wallet
```

The script will automatically detect the protocol of the given context
and use the appropriate module to extract the data.

Whenever a new protocol is snapshotted, this script requires the
following adjustments, **which are currently being automatically
performed by the Manifest** (`src/manifest/main.ml`):

  1. `get_delegates_alpha.ml` should be copied with an appropriate name
  2. `dune` should be updated with a new executable definition
  3. delete modules supporting frozen protocol versions to ease the maintenance burden.

The Manifest can also be invoked manually by calling `make -C manifest`.

Support for older protocols (down to Ithaca) can be restored relatively
easily using git.

For instance to revive support for Ithaca:

* `git checkout <commit-or-tag> -- devtools/yes_wallet/get_delegates_012_PsIthaca.ml`
* modify the `dune` file to import `mavryk-protocol-012-Psithaca`
* `dune build`

The `<commit-or-tag>` refers to some git revision, where the support
was still maintained (given protocol was active).

After that, the support for the given protocol should be restored.

## Populating an alias file

In order to define aliases, `yes-wallet` supports an optional flag,
`--aliases` which takes as argument .json file like the following:

```json
[ 
  {
    "alias": "Tezos Foundation Baker 1",
    "address": "mv3RCw1KLQZ1ULrYNJMcMKN9An4LNthEA9CT",
    "publicKey": "p2pk64qdTFeEGX4QBidPhHX3DadEQVCKpwnaeZg3Mrm6HuM81UAeCq1"
  },
  {
    "alias": "Tezos Foundation Baker 2",
    "address": "mv3XBks18YUcVEhLneN6v6UUjUuPk6FAb54p",
    "publicKey": "p2pk65aRfSEqWS1oKrmLCQTaLZULRAEWbmtqouMQhbZC82eirDcUfz4"
  },
  {
    "alias": "Tezos Foundation Baker 3",
    "address": "mv3GZYzwUGVqJ7YQ5LP8snRBnHmcxk96xYDi",
    "publicKey": "p2pk67A75WnRFWcBgPa9FTLCLAMTohiJXY7TnJiEzX2VuUDK5T3JL6k"
  },
  {
    "alias": "Tezos Foundation Baker 4",
    "address": "mv3GmqQNVmbAF3TdC98S2cPjhEtB1VxNQUN2",
    "publicKey": "p2pk66UPQPLsLejfoss1iwss34icqnZT7UuqdbMaNTzGXQKfGaURMGH"
  },
  {
    "alias": "Tezos Foundation Baker 5",
    "address": "mv3KkznrNE4iPPjwwhwUxvuzdt7r1eRxE7wy",
    "publicKey": "p2pk65rGpQjUzFuQ9zTzCsBgZn9DLhgzw4AyM17kgqc3zUgphXpfpB6"
  },
  {
    "alias": "Tezos Foundation Baker 6",
    "address": "mv3FuGBrMjvAbWW9A2qHifbBRjf2KCptheX2",
    "publicKey": "p2pk67N1gEB2gYkwcLJQcNmGQvr4R7w2QyKQWJbnGb9MkeGjFVE5JuW"
  },
  {
    "alias": "Tezos Foundation Baker 8",
    "address": "mv3WuXV7pBcYfaBGTVggB71bATMoHH4YAk5E",
    "publicKey": "p2pk65dXz5EXTvHskQqmveu5aS9dNLKNajDtcoht4nrmvPYr3F7ecGH"
  }
]
```

Such file can be populated using an indexer's API. For example the
following script gets all known aliases from active delegates in Tezos
Mainnet using [tzkt.io](https://tzkt.io)'s API:

```shell
curl https://api.tzkt.io/v1/delegates?limit=5000 | jq 'map(select ((.alias?) and .active) |{ "alias" : .alias, "address" : .address , "publicKey" : .publicKey})' > aliases.json

```
