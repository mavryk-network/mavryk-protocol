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
* `tezos-smart-rollup-installer`: use `cargo install tezos-smart-rollup-installer`.

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
