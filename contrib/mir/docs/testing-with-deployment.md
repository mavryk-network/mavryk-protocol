<!--
  SPDX-FileCopyrightText: 2023 Serokell <hi@serokell.io>

  SPDX-License-Identifier: MIT
-->

## Prerequisites

You will need the following programs installed:

* Rust with rustup: [install page](https://www.rust-lang.org/tools/install).
* `xxd` command line tool.
* `wasm-strip`: it's simplest to install from releases of
    [`wabt`](https://github.com/WebAssembly/wabt/) repository.
* Some `octez-*` tools: build them from sources or use static
  binaries that can be found in releases of [`tezos
  packaging`](https://github.com/serokell/tezos-packaging) repository.
  * `octez-client`;
  * `octez-smart-rollup-client`;
  * `octez-smart-rollup-node`.
* `smart-rollup-installer`: use `cargo install tezos-smart-rollup-installer`.

Make sure that your data directory of `octez-client` (`~/.octez-client` by default)
mentions the testing network you are planning to operate with.

Also, you will need an address with some tez on it, provide it via the dedicated
variable:

```sh
export OPERATOR_ADDR="ADDRESS or ALIAS"
```

If this variable is not provided, `rollup-operator` alias will be picked. You
may want to just expose this alias instead of providing operator address each
time you test, for that call

```sh
octez-client gen keys rollup-operator
octez-client transfer 1000 from RICH_ADDRESS to rollup-operator --burn-cap 0.1
```

There are numerious restrictions in case you care about rollup actions being
cemented: the operator must have at least 10,000 tez, and commitment with your
action will be published only in 2 weeks unless you are using a dedicated exotic
testing network like Dailynet. But to test the rollup kernel's behaviour that's
not strictly necessary.

## Deploy

Run

```sh
make originate-rollup
```

This will build the kernel and deploy it.

Once the origination command finishes, the originated rollup will reside under
`mir-rollup` alias, unless you specify `ROLLUP_ALIAS` env variable with the
desired name to the command.

Further, in order for the rollup execution to take place, you need to run
a local node. This is doable by calling

```sh
make run-rollup-node
```

Let it execute in the background.

When idle, the running node causes the rollup to process a few service internal
messages at every level.

## Testing

### Invoking kernel with an external message

To send an external message use a command like follows:

```sh
octez-client send smart rollup message "hex:[\"05\"]" from $OPERATOR_ADDR
```

(the specified address should not necessarily be operator address, but we use it for simplicity).

### Checking result

Then observe the result written in the durable storage via

```sh
octez-smart-rollup-client rpc get '/global/block/head/durable/wasm_2_0_0/value?key=/storage'
```

The provided request refers to the current optimistic state, not the cemeneted
one, meaning that actions on the rollup should be visible by that call
immediately. `head` can be replaced with `cemented` or specific level, see `man`
on the command for details.

### Invoking kernel with an internal message

For sending an internal message, a dedicated contract is necessary through which
we would call our rollup.

First, obtain the rollup address via

```sh
octez-smart-rollup-client get smart rollup address
```

(the tezos smart rollup node must be running).

Then follow [the related section of the manual](https://tezos.gitlab.io/shell/smart_rollup_node.html#sending-an-internal-inbox-message)
on how to send the message.

## Trobleshooting

In case something is not working, a few investigation directions further.

### Dead services

Track the logs of the running node. In case you see that only the `injector`
service is logging something for a long time, then something is off.
If you can find

```
Entering degraded mode: only playing refutation game to defend commitments.
```

message, then the node will not push the progress forward.

One of the reasons can be that you rebuilt the kernel, but the rollup node still
serves the old rollup that requires old kernel pages in `wasm_2_0_0` folder that
are not present there anymore.

### Node accepted the messages

Once the message to the rollup is included into the chain, in the node you
should be able to see

```
....sc_rollup_node.inbox: Fetching 1 messages from block
....sc_rollup_node.inbox:   BLXEJoyghMZ6wdbprNEvGc5LjzsY4P7BhVs9myYvLoQE848pNDq at level L
....sc_rollup_node.inbox: Transitioned PVM at inbox level L to
....sc_rollup_node.inbox:   srs132pyW4BFZfgRgTL9jWTaqH4VdMu5wMWu8TvkSK8BYXfb8zwJkA at tick 99000000000
....sc_rollup_node.inbox:   with 4 messages
```

Here
* `L` is the level of block where the message to our rollup was included. The
  rollup kernel will see same level `L` when reading the message from its inbox.
* "Fetching 1 messages" at the first line again refers to your submitted
  message.
* "with 4 messages" at the last line refers to your submitted message + 3
  messages added by Tezos protocol.

### Seeing no "Fetching 1 messages", only 0

It might be that `inbox` service falls behind and is still processing the old
blocks, you can compare the block numbers to check whether this is the case.

If it is, just wait for the `inbox` service to sync up.

### No `last_seen_block`

You can see the following error message:

```
....sc_rollup_node.injector: [tz1hGdJumKDnZ: publish, add_messages, cement, refute] ignoring unreadable
....sc_rollup_node.injector:   file .tezos-smart-rollup-node/injector/last_seen_head on disk:
....sc_rollup_node.injector:   Error:
....sc_rollup_node.injector:     The persistent element .tezos-smart-rollup-node/injector/last_seen_head could not be read,
...
```

It is _fine_ and does not affect operability.
