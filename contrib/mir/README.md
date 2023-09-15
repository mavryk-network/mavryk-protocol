# M.I.R - Michelson In Rust

This repo hosts the Rust implementation of the typechecker and interpreter for
Michelson smart contract language and implements a Michelson runtime as a
Smart Rollup.

This project implements a Michelson runtime as a Smart Rollup.

## Building

Running

```
cargo build --target wasm32-unknown-unknown
```

will build the project in wasm, installing all the necessary toolchain.

You will need `clang >= 11` installed in the system. This and other constraints
can be found mentioned in the
[Rust SDK for Smart Rollups](https://docs.rs/tezos-smart-rollup/latest/tezos_smart_rollup/).

That build command will also automatically install the standard library for
`wasm32-unknown-unknown` target since compiling to that target is necessary for
actually using the produced kernel in Tezos network.

## Automatic testing

You can run the included tests by the following command.

`cargo test`

Some tests print gas consumption information (in addition to testing it), but `cargo test` omits output from successful tests by default. To see it, run

`cargo test -- --show-output`

## Testing rollup manually

There are two basic ways to poke the rollup.

### Testing with debugger

The simpler way to test the rollup is using the debugger.

See [the official page](https://tezos.gitlab.io/shell/smart_rollup_node.html#testing-your-kernel) for instructions.

In our case you need:
* Prerequisite: obtain `octez-smart-rollup-wasm-debugger`.

  It can be built from OCaml sources, or you can get a ready static binary from the Releases page of [tezos-packaging](https://github.com/serokell/tezos-packaging) repository.

* Run `make debugger-inputs.json` and fill your message content into that file.
* Run `make debug-kernel-simple`.
* Interact with the debugger as mentioned in the docs. Observe the printed debug
  messages, check the necessary durable storage keys. Usually you just type

  ```sh
  step inbox
  ```

  to make the kernel consume the input messages, and then to check out the
  result written to the durable storage:

  ```sh
  show key /storage
  ```

The mentioned command tests the very raw kernel as produced by Rust.

For real deployment some preprocessing is necessary. If you want to account for
it, use `make debug-kernel-full`. This would require some of the tools mentioned
in the [deployment](./docs/testing-with-deployment.md) document.

### Testing with deployment

See the [respective document](./docs/testing-with-deployment.md) on this.
