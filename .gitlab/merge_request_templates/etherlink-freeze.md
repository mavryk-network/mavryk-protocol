# What

The commit for the next basenet upgrade is: RELEASE_COMMIT

# Steps

## Freeze the kernel

Prepare the basenet kernel:
```
$ git checkout RELEASE_COMMIT
$ etherlink/scripts/build-wasm.sh
$ cp etherlink/kernels-<RELEASE_COMMIT>/evm_kernel.wasm etherlink/kernel_evm/kernel/tests/resources/basenet_evm_kernel.wasm
```

Update the constant `basenet_evm_commit` in `tezt/lib_tezos/constant.ml`:
```
let basenet_evm_commit = "RELEASE_COMMIT"
```

## Freeze the node

Copy dev into prod:
```
$ cd etherlink/bin_node
$ rm -rf lib_prod
$ cp -r lib_dev lib_prod
```

Replace the various dev mention inside lib_prod:
```
$ cd lib_prod

# On Linux
$ find . -type f -exec sed -i 's/dev\"/prod\"/g' {} +
$ find . -type f -exec sed -i 's/\_dev/\_prod/g' {} +

# Or on macOS
$ find . -type f -exec sed -i '' 's/dev\"/prod\"/g' {} +
$ find . -type f -exec sed -i '' 's/\_dev/\_prod/g' {} +
```

Update `etherlink/bin_node/main.ml`:

The main module uses both `lib_dev` and `lib_prod`. For all functions/branches for prod mode, replace the implementation with implementation from corresponding functions/branches for dev mode. This needs to be done manually.

Update manifest:
```
$ cd ../../
$ make -C manifest
```
At this point you might need to manually update the dependencies in `manifest.ml`. You simply have to copy the list of dependencies from dev to prod.

## Remove migration code if any

Any migration code should be removed and goes back to:
```
if STORAGE_VERSION == current_version + 1 {
  // MIGRATION CODE - START
  // MIGRATION CODE - END
  store_storage_version(host, STORAGE_VERSION)?;
  return Ok(MigrationStatus::Done);
}
```

## Test

Simply compile everything and run the tests!
```
$ make mavkit-evm-node && make -f etherlink.mk evm_kernel.wasm
$ dune exec etherlink/tezt/tests/main.exe -- -f evm_sequencer.ml -f evm_rollup.ml -j 4 --keep-going
```

# Checklist

- [ ] Freeze the kernel and node changelogs and create the NEXT section.
- [ ] Freeze the kernel.
- [ ] Freeze evm-node.
- [ ] Remove migration code if any.
