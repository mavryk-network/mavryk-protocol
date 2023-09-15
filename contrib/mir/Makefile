# SPDX-FileCopyrightText: 2023 Serokell <hi@serokell.io>
# SPDX-FileCopyrightText: 2023 Baking Bad <hello@bakingbad.dev>
#
# SPDX-License-Identifier: MIT

.PHONY: build fill-kernel-chunks prepare-smart-rollup-config originate_rollup debug-kernel-internal debug-kernel-simple debug-kernel-full clean-rollup-dir clean-build clean

# Folders
BIN_DIR ?= bin
TARGET_DIR ?= target
# Where temporary folder of rollup node will be
SMART_ROLLUP_NODE_DIR ?= .tezos-smart-rollup-node

# Executables
SMART_ROLLUP_INSTALLER ?= smart-rollup-installer

# Addresses
## Alias for the originated rollup
ROLLUP_ALIAS ?= mir-rollup
## Address that will pay for operations
OPERATOR_ADDR ?= rollup-operator

# Produces the immediate .wasm kernel created by Rust
$(BIN_DIR)/mir-raw-kernel.wasm: $(shell find src) Cargo.toml
	mkdir -p $(BIN_DIR)
	cargo build --release --target wasm32-unknown-unknown
	cp $(TARGET_DIR)/wasm32-unknown-unknown/release/mir.wasm $(BIN_DIR)/mir-raw-kernel.wasm

# Applies the processing to the kernel that is suggested by all tutorials
$(BIN_DIR)/mir-kernel.wasm: $(BIN_DIR)/mir-raw-kernel.wasm
	wasm-strip $(BIN_DIR)/mir-raw-kernel.wasm -o $(BIN_DIR)/mir-kernel.wasm

# No real kernel would fit into Tezos' operation size limits, so we have
# to use a dedicated tool that would split the kernel into chunks and create
# an installer kernel that would load those chunks on run.
# The chunks have to be exposed via our local rollup node.
$(BIN_DIR)/mir-installer-kernel.wasm: $(BIN_DIR)/mir-kernel.wasm
  ifeq ($(SMART_ROLLUP_INSTALLER),smart-rollup-installer)
  ifeq (, $(shell which smart-rollup-installer))
  $(error "No smart-rollup-installer in $$PATH, you can install it with `cargo install`. \
           Make sure cargo binaries folder is in your path")
  endif
  endif
	$(SMART_ROLLUP_INSTALLER) get-reveal-installer \
		--upgrade-to $(BIN_DIR)/mir-kernel.wasm \
		--output $(BIN_DIR)/mir-installer-kernel.wasm \
		--preimages-dir $(BIN_DIR)/wasm_2_0_0

%-kernel.wasm.hex: %-kernel.wasm
	xxd -ps -c 0 $*-kernel.wasm | tr -d '\n' > $@

build: $(BIN_DIR)/mir-installer-kernel.wasm.hex

# Load the kernel chunks into the local node's dir
fill-kernel-chunks: $(BIN_DIR)/mir-installer-kernel.wasm.hex
	mkdir -p $(SMART_ROLLUP_NODE_DIR)/wasm_2_0_0
	cp -r $(BIN_DIR)/wasm_2_0_0 $(SMART_ROLLUP_NODE_DIR)/

originate-rollup: $(BIN_DIR)/mir-installer-kernel.wasm.hex
	octez-client originate smart rollup $(ROLLUP_ALIAS) \
		from $(OPERATOR_ADDR) \
		of kind wasm_2_0_0 \
		of type int \
		with kernel $(BIN_DIR)/mir-installer-kernel.wasm.hex \
		--burn-cap 999 --fee-cap 100 \
		--force

# Run this in background in order for rollup operations to take progress.
#
# We'll bind the node to be an operator of the originated rollup, and that won't
# work without removing the previous operators from the config.
run-rollup-node: clean-rollup-dir fill-kernel-chunks

	octez-smart-rollup-node init operator config \
		for "$(ROLLUP_ALIAS)" \
		with operators "$(OPERATOR_ADDR)" \
		--data-dir "$(SMART_ROLLUP_NODE_DIR)" \
		--force

	octez-smart-rollup-node \
		run operator for "$(ROLLUP_ALIAS)" \
		with operators "$(OPERATOR_ADDR)" \
		--data-dir "$(SMART_ROLLUP_NODE_DIR)"

clean-rollup-dir:
	@# Trying to remove safely
	$(if $(SMART_ROLLUP_NODE_DIR),,$(error SMART_ROLLUP_NODE_DIR var is empty))
	rm -rf $(SMART_ROLLUP_NODE_DIR)

clean-build:
	@# Trying to remove safely
	$(if $(BIN_DIR),,$(error BIN_DIR var is empty))
	rm -rf $(BIN_DIR)
	rm -rf ./target

# This is a template for inputs file put to debugger.
# Created automatically on call to debugger, you can next update this file
# as needed.
debugger-inputs.json:
	echo '[[{"external": "07"}]]' > debugger-inputs.json
	# the format is explained here
	# https://tezos.gitlab.io/alpha/smart_rollups.html#testing-your-kernel

debug-kernel-internal: $(BIN_DIR)/$(KERNEL_NAME).wasm debugger-inputs.json
	# not always we've generated some kernel pages, so create the folder
  # if it is absent, for uniformity
	mkdir -p $(BIN_DIR)/wasm_2_0_0
	octez-smart-rollup-wasm-debugger \
		--kernel $(BIN_DIR)/$(KERNEL_NAME).wasm \
		--inputs debugger-inputs.json \
		--preimage-dir $(BIN_DIR)/wasm_2_0_0

# This tests the original kernel before any processing.
# Requires less tooling to run, and provides almost the same coverage.
debug-kernel-simple:
	$(MAKE) debug-kernel-internal KERNEL_NAME=mir-raw-kernel

debug-kernel-full:
	$(MAKE) debug-kernel-internal KERNEL_NAME=mir-installer-kernel

clean: clean-build clean-rollup-dir
