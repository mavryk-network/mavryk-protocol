PACKAGES_SUBPROJECT:=$(patsubst %.opam,%,$(notdir $(shell find src vendors -name \*.opam -print)))
PACKAGES:=$(patsubst %.opam,%,$(notdir $(shell find opam -name \*.opam -print)))

define directory_of_version
src/proto_$(shell echo $1 | tr -- - _)
endef

# Opam is not present in some build environments. We don't strictly need it.
# Those environments set MAVRYK_WITHOUT_OPAM.
ifndef MAVRYK_WITHOUT_OPAM
current_opam_version := $(shell opam --version)
endif

include scripts/version.sh

DOCKER_IMAGE_NAME := mavryk
DOCKER_IMAGE_VERSION := latest
DOCKER_BUILD_IMAGE_NAME := $(DOCKER_IMAGE_NAME)_build
DOCKER_BUILD_IMAGE_VERSION := latest
DOCKER_BARE_IMAGE_NAME := $(DOCKER_IMAGE_NAME)-bare
DOCKER_BARE_IMAGE_VERSION := latest
DOCKER_DEBUG_IMAGE_NAME := $(DOCKER_IMAGE_NAME)-debug
DOCKER_DEBUG_IMAGE_VERSION := latest
DOCKER_DEPS_IMAGE_NAME := registry.gitlab.com/tezos/opam-repository
DOCKER_DEPS_IMAGE_VERSION := runtime-build-dependencies--${opam_repository_tag}
DOCKER_DEPS_MINIMAL_IMAGE_VERSION := runtime-dependencies--${opam_repository_tag}
COVERAGE_REPORT := _coverage_report
COBERTURA_REPORT := _coverage_report/cobertura.xml
PROFILE?=dev
VALID_PROFILES=dev release static

# See the documentation of [~release_status] in [manifest/manifest.mli].
RELEASED_EXECUTABLES := $(shell cat script-inputs/released-executables)
EXPERIMENTAL_EXECUTABLES := $(shell cat script-inputs/experimental-executables)

# Executables that developers need at the root of the repository but that
# are not useful for users.
# - scripts/snapshot_alpha.sh expects mavkit-protocol-compiler to be at the root.
# - Some tests expect mavkit-snoop to be at the root.
DEV_EXECUTABLES := $(shell cat script-inputs/dev-executables)

ALL_EXECUTABLES := $(RELEASED_EXECUTABLES) $(EXPERIMENTAL_EXECUTABLES) $(DEV_EXECUTABLES)

#Define mavkit only executables by excluding the EVM-node.
MAVKIT_ONLY_EXECUTABLES := $(filter-out mavkit-evm-node,${ALL_EXECUTABLES})

# Set of Dune targets to build, in addition to OCTEZ_EXECUTABLES, in
# the `build` target's Dune invocation. This is used in the CI to
# build the TPS evaluation tool, Octogram and the Tezt test suite in the
# 'build_x86_64-dev-exp-misc' job.
BUILD_EXTRA ?=

# See first mention of MAVRYK_WITHOUT_OPAM.
ifndef MAVRYK_WITHOUT_OPAM
ifeq ($(filter ${opam_version}.%,${current_opam_version}),)
$(error Unexpected opam version (found: ${current_opam_version}, expected: ${opam_version}.*))
endif
endif

ifeq ($(filter ${VALID_PROFILES},${PROFILE}),)
$(error Unexpected dune profile (got: ${PROFILE}, expecting one of: ${VALID_PROFILES}))
endif

# This check ensures that the `MAVKIT_EXECUTABLES` variable contains a subset of
# the `ALL_EXECUTABLE` variable. The `MAVKIT_EXECUTABLES` variable is used
# internally to select a subset of which executables to build.
# The reason for the `foreach` is so that we support both newlines and spaces.
ifneq ($(filter ${ALL_EXECUTABLES},${MAVKIT_EXECUTABLES}),$(foreach executable,${MAVKIT_EXECUTABLES},${executable}))
$(error Unexpected list of executables to build, make sure environment variable MAVKIT_EXECUTABLES is unset)
endif

# Where to copy executables.
# Used when building Docker images to help with the COPY instruction.
MAVKIT_BIN_DIR?=.

VALID_MAVKIT_BIN_DIRS=. bin

ifeq ($(filter ${VALID_MAVKIT_BIN_DIRS},${MAVKIT_BIN_DIR}),)
$(error Unexpected value for MAVKIT_BIN_DIR (got: ${MAVKIT_BIN_DIR}, expecting one of: ${VALID_MAVKIT_BIN_DIRS}))
endif

# See first mention of MAVRYK_WITHOUT_OPAM.
ifdef MAVRYK_WITHOUT_OPAM
current_ocaml_version := $(shell ocamlc -version)
else
current_ocaml_version := $(shell opam exec -- ocamlc -version)
endif

# Default target.
#
# Note that you can override the list of executables to build on the command-line, e.g.:
#
#     make MAVKIT_EXECUTABLES='mavkit-node mavkit-client'
#
# This is more efficient than 'make mavkit-node mavkit-client'
# because it only calls 'dune' once.
#
# Targets 'all', 'release', 'experimental-release' and 'static' define
# different default lists of executables to build but they all can be
# overridden from the command-line.
.PHONY: all
all:
	@$(MAKE) build MAVKIT_EXECUTABLES?="$(ALL_EXECUTABLES)"

.PHONY: release
release:
	@$(MAKE) build PROFILE=release MAVKIT_EXECUTABLES?="$(RELEASED_EXECUTABLES)"

.PHONY: mavkit
mavkit:
	@$(MAKE) build PROFILE=release OCTEZ_EXECUTABLES?="$(OCTEZ_ONLY_EXECUTABLES)"

.PHONY: experimental-release
experimental-release:
	@$(MAKE) build PROFILE=release MAVKIT_EXECUTABLES?="$(RELEASED_EXECUTABLES) $(EXPERIMENTAL_EXECUTABLES)"

.PHONY: build-additional-tezt-test-dependency-executables
build-additional-tezt-test-dependency-executables:
	@dune build contrib/mavkit_injector_server/mavkit_injector_server.exe

.PHONY: strip
strip: all
	@chmod +w $(ALL_EXECUTABLES)
	@strip -s $(ALL_EXECUTABLES)
	@chmod -w $(ALL_EXECUTABLES)

.PHONY: static
static:
	@$(MAKE) build PROFILE=static MAVKIT_EXECUTABLES?="$(RELEASED_EXECUTABLES)"

.PHONY: build-parameters
build-parameters:
	@dune build --profile=$(PROFILE) $(COVERAGE_OPTIONS) @copy-parameters

.PHONY: $(ALL_EXECUTABLES)
$(ALL_EXECUTABLES):
	dune build $(COVERAGE_OPTIONS) --profile=$(PROFILE) _build/install/default/bin/$@
	cp -f _build/install/default/bin/$@ ./

.PHONY: kaitai-struct-files-update
kaitai-struct-files-update:
	@dune exe client-libs/bin_codec_kaitai/codec.exe dump kaitai specs in client-libs/kaitai-struct-files/files

.PHONY: kaitai-struct-files
kaitai-struct-files:
	@$(MAKE) kaitai-struct-files-update
	@$(MAKE) -C client-libs/kaitai-struct-files/

.PHONY: check-kaitai-struct-files
check-kaitai-struct-files:
	@git diff --exit-code HEAD -- client-libs/kaitai-struct-files/files || (echo "Cannot check kaitai struct files, some changes are uncommitted"; exit 1)
	@dune build client-libs/bin_codec_kaitai/codec.exe
	@rm client-libs/kaitai-struct-files/files/*.ksy
	@_build/default/client-libs/bin_codec_kaitai/codec.exe dump kaitai specs in client-libs/kaitai-struct-files/files 2>/dev/null
	@git add client-libs/kaitai-struct-files/files/*.ksy
	@git diff --exit-code HEAD -- client-libs/kaitai-struct-files/files/ || (echo "Kaitai struct files mismatch. Update the files with `make kaitai-struct-files-update`."; exit 1)

.PHONY: validate-kaitai-struct-files
validate-kaitai-struct-files:
	@$(MAKE) check-kaitai-struct-files
	@./client-libs/kaitai-struct-files/scripts/kaitai_e2e.sh client-libs/kaitai-struct-files/files 2>/dev/null || \
	 (echo "To see the full log run: \"./client-libs/kaitai-struct-files/scripts/kaitai_e2e.sh client-libs/kaitai-struct-files/files client-libs/kaitai-struct-files/input\""; exit 1)

# Remove the old names of executables.
# Depending on the commit you are updating from (v14.0, v15 or some version of master),
# the exact list can vary. We just remove all of them.
# Don't try to generate this list from *_EXECUTABLES: this list should not evolve as
# we add new executables, and this list should contain executables that were built
# before (e.g. old protocol daemons) but that are no longer built.
.PHONY: clean-old-names
clean-old-names:
	@rm -f mavryk-node
	@rm -f mavryk-validator
	@rm -f mavryk-client
	@rm -f mavryk-admin-client
	@rm -f mavryk-signer
	@rm -f mavryk-codec
	@rm -f mavryk-protocol-compiler
	@rm -f mavryk-proxy-server
	@rm -f mavryk-baker-alpha
	@rm -f mavryk-accuser-alpha
	@rm -f mavryk-smart-rollup-node-alpha
	@rm -f mavryk-smart-rollup-client-alpha
	@rm -f mavryk-snoop
	@rm -f mavryk-dal-node
# mavkit-validator should stay in this list for Mavkit 16.0 because we
# removed the executable
	@rm -f mavkit-validator
	@rm -f mavkit-smart-rollup-node-PtAtLas
	@rm -f mavkit-smart-rollup-node-alpha

# See comment of clean-old-names for an explanation regarding why we do not try
# to generate the symbolic links from *_EXECUTABLES.
.PHONY: build
build: clean-old-names
ifneq (${current_ocaml_version},${ocaml_version})
	$(error Unexpected ocaml version (found: ${current_ocaml_version}, expected: ${ocaml_version}))
endif
ifeq (${MAVKIT_EXECUTABLES},)
	$(error The build target requires MAVKIT_EXECUTABLES to be specified. Please use another target (e.g. 'make' or 'make release') and make sure that environment variable MAVKIT_EXECUTABLES is unset)
endif
	@dune build --profile=$(PROFILE) $(COVERAGE_OPTIONS) \
		$(foreach b, $(MAVKIT_EXECUTABLES), _build/install/default/bin/${b}) \
		$(BUILD_EXTRA) \
		@copy-parameters
	@mkdir -p $(MAVKIT_BIN_DIR)/
	@cp -f $(foreach b, $(MAVKIT_EXECUTABLES), _build/install/default/bin/${b}) $(MAVKIT_BIN_DIR)/
	@cd $(MAVKIT_BIN_DIR)/; \
		ln -s mavkit-smart-rollup-node mavkit-smart-rollup-node-PtAtLas; \
		ln -s mavkit-smart-rollup-node mavkit-smart-rollup-node-alpha

# List protocols, i.e. directories proto_* in src with a MAVRYK_PROTOCOL file.
MAVRYK_PROTOCOL_FILES=$(wildcard src/proto_*/lib_protocol/MAVRYK_PROTOCOL)
PROTOCOLS=$(patsubst %/lib_protocol/MAVRYK_PROTOCOL,%,${MAVRYK_PROTOCOL_FILES})

.PHONY: all.pkg
all.pkg:
	@dune build --profile=$(PROFILE) \
	    $(patsubst %.opam,%.install, $(shell find src vendors -name \*.opam -print))

$(addsuffix .pkg,${PACKAGES_SUBPROJECT}): %.pkg:
	@dune build --profile=$(PROFILE) \
	    $(patsubst %.opam,%.install, $(shell find src vendors -name $*.opam -print))

$(addsuffix .pkg,${PACKAGES}): %.pkg:
	dune build --profile=$(PROFILE) $(patsubst %.opam,%.install,$*.opam)

$(addsuffix .test,${PACKAGES_SUBPROJECT}): %.test:
	@dune build --profile=$(PROFILE) \
	    @$(patsubst %/$*.opam,%,$(shell find src vendors -name $*.opam))/runtest

$(addsuffix .test,${PACKAGES}): %.test:
	@echo "'make $*.test' is no longer supported"

.PHONY: coverage-report
coverage-report:
	@bisect-ppx-report html --tree --ignore-missing-files -o ${COVERAGE_REPORT} --coverage-path ${COVERAGE_OUTPUT}
	@echo "Report should be available in file://$(shell pwd)/${COVERAGE_REPORT}/index.html"

.PHONY: coverage-report-summary
coverage-report-summary:
	@bisect-ppx-report summary --coverage-path ${COVERAGE_OUTPUT}

.PHONY: coverage-report-cobertura
coverage-report-cobertura:
	@bisect-ppx-report cobertura --ignore-missing-file --coverage-path ${COVERAGE_OUTPUT} ${COBERTURA_REPORT}
	@echo "Cobertura report should be available in ${COBERTURA_REPORT}"

.PHONY: enable-time-measurement
enable-time-measurement:
	@$(MAKE) all DUNE_INSTRUMENT_WITH=mavryk-time-measurement

.PHONY: test-protocol-compile
test-protocol-compile:
	@dune build --profile=$(PROFILE) $(COVERAGE_OPTIONS) @runtest_compile_protocol
	@dune build --profile=$(PROFILE) $(COVERAGE_OPTIONS) @runtest_out_of_opam

PROTO_DIRS := $(shell find src/ -maxdepth 1 -type d -path "src/proto_*" 2>/dev/null | LC_COLLATE=C sort)
NONPROTO_DIRS := $(shell find src/ -maxdepth 1 -mindepth 1 -type d -not -path "src/proto_*" 2>/dev/null | LC_COLLATE=C sort)
OTHER_DIRS := $(shell find contrib/ ci/ client-libs/ -maxdepth 1 -mindepth 1 -type d 2>/dev/null | LC_COLLATE=C sort)

.PHONY: test-proto-unit
test-proto-unit:
	DUNE_PROFILE=$(PROFILE) \
		COVERAGE_OPTIONS="$(COVERAGE_OPTIONS)" \
		scripts/test_wrapper.sh test-proto-unit \
		$(addprefix @, $(addsuffix /runtest,$(PROTO_DIRS)))

.PHONY: test-lib-store-slow
test-lib-store-slow:
	DUNE_PROFILE=$(PROFILE) \
		COVERAGE_OPTIONS="$(COVERAGE_OPTIONS)" \
		dune exec src/lib_store/unix/test/slow/test_slow.exe -- --file test_slow.ml --info

.PHONY: test-lib-store-bench
test-lib-store-bench:
	DUNE_PROFILE=$(PROFILE) \
		COVERAGE_OPTIONS="$(COVERAGE_OPTIONS)" \
		dune exec src/lib_store/unix/test/bench/bench.exe -- --file bench.ml --info

.PHONY: test-nonproto-unit
test-nonproto-unit:
	DUNE_PROFILE=$(PROFILE) \
		COVERAGE_OPTIONS="$(COVERAGE_OPTIONS)" \
		scripts/test_wrapper.sh test-nonproto-unit \
		$(addprefix @, $(addsuffix /runtest,$(NONPROTO_DIRS)))

.PHONY: test-other-unit
test-other-unit:
	DUNE_PROFILE=$(PROFILE) \
		COVERAGE_OPTIONS="$(COVERAGE_OPTIONS)" \
		scripts/test_wrapper.sh test-other-unit \
		$(addprefix @, $(addsuffix /runtest,$(OTHER_DIRS)))

.PHONY: test-unit
test-unit: test-nonproto-unit test-proto-unit test-other-unit

.PHONY: test-unit-alpha
test-unit-alpha:
	@dune build --profile=$(PROFILE) @src/proto_alpha/lib_protocol/runtest

# TODO: https://gitlab.com/tezos/tezos/-/issues/5377
# Running the runtest_js targets intermittently hangs.
.PHONY: test-js
test-js:
	@dune build --error-reporting=twice @runtest_js

.PHONY: build-tezt
build-tezt:
	@dune build tezt

.PHONY: build-simulation-scenario
build-simulation-scenario:
	@dune build devtools/testnet_experiment_tools/
	@mkdir -p $(MAVKIT_BIN_DIR)/
	@cp -f _build/default/devtools/testnet_experiment_tools/simulation_scenario.exe $(MAVKIT_BIN_DIR)/simulation-scenario
	@cp -f _build/default/devtools/testnet_experiment_tools/safety_checker.exe $(MAVKIT_BIN_DIR)/safety-checker

.PHONY: test-tezt
test-tezt: build-additional-tezt-test-dependency-executables
	@dune exec --profile=$(PROFILE) $(COVERAGE_OPTIONS) tezt/tests/main.exe

.PHONY: test-tezt-i
test-tezt-i: build-additional-tezt-test-dependency-executables
	@dune exec --profile=$(PROFILE) $(COVERAGE_OPTIONS) tezt/tests/main.exe -- --info

.PHONY: test-tezt-c
test-tezt-c: build-additional-tezt-test-dependency-executables
	@dune exec --profile=$(PROFILE) $(COVERAGE_OPTIONS) tezt/tests/main.exe -- --commands

.PHONY: test-tezt-v
test-tezt-v: build-additional-tezt-test-dependency-executables
	@dune exec --profile=$(PROFILE) $(COVERAGE_OPTIONS) tezt/tests/main.exe -- --verbose

.PHONY: test-tezt-coverage
test-tezt-coverage: build-additional-tezt-test-dependency-executables
	@dune exec --profile=$(PROFILE) $(COVERAGE_OPTIONS) tezt/tests/main.exe -- --keep-going --test-timeout 1800

.PHONY: test-code
test-code: test-protocol-compile test-unit test-tezt

# This is as `make test-code` except we allow failure (prefix "-")
# because we still want the coverage report even if an individual
# test happens to fail.
.PHONY: test-coverage
test-coverage:
	-@$(MAKE) test-protocol-compile
	-@$(MAKE) test-unit
	-@$(MAKE) test-tezt

.PHONY: test-coverage-tenderbake
test-coverage-tenderbake:
	-@$(MAKE) test-unit-alpha

.PHONY: test-webassembly
test-webassembly:
	@dune build --profile=$(PROFILE) @src/lib_webassembly/bin/runtest-python

.PHONY: lint-opam-dune
lint-opam-dune:
	@dune build --profile=$(PROFILE) @runtest_dune_template

# Ensure that all unit tests are restricted to their opam package
# (change 'mavkit-distributed-internal' to one the most elementary packages of
# the repo if you add "internal" dependencies to mavkit-distributed-internal)
.PHONY: lint-tests-pkg
lint-tests-pkg:
	@(dune build -p mavkit-distributed-internal @runtest @runtest_js) || \
	{ echo "You have probably defined some tests in dune files without specifying to which 'package' they belong."; exit 1; }


TEST_DIRS := $(shell find src -name "test" -type d -print -o -name "test-*" -type d -print)
EXCLUDE_TEST_DIRS := $(addprefix --exclude-file ,$(addsuffix /,${TEST_DIRS}))

.PHONY: test
test: test-code

.PHONY: check-linting check-python-linting check-ocaml-linting

check-linting:
	@scripts/lint.sh --check-scripts
	@scripts/lint.sh --check-ocamlformat
	@scripts/lint.sh --check-rust-toolchain
	@dune build --profile=$(PROFILE) @fmt

check-python-linting:
	@$(MAKE) -C docs lint

check-python-typecheck:
	@$(MAKE) -C docs typecheck

check-ocaml-linting:
	@./scripts/semgrep/lint-all-ocaml-sources.sh

.PHONY: fmt fmt-ocaml fmt-python
fmt: fmt-ocaml fmt-python fmt-shell

fmt-shell:
	scripts/lint.sh --format-shell

fmt-ocaml:
	@dune build --profile=$(PROFILE) @fmt --auto-promote

fmt-python:
	@$(MAKE) -C docs fmt

.PHONY: dpkg
dpkg:	all
	@./scripts/dpkg/make_dpkg.sh

.PHONY: rpm
rpm:	all
	@./scripts/rpm/make_rpm.sh


.PHONY: build-deps
build-deps:
	@./scripts/install_build_deps.sh

.PHONY: build-dev-deps
build-dev-deps:
	@./scripts/install_build_deps.sh --dev

.PHONY: lift-protocol-limits-patch
lift-protocol-limits-patch:
	@git apply -R ./src/bin_tps_evaluation/lift_limits.patch || true
	@git apply ./src/bin_tps_evaluation/lift_limits.patch

.PHONY: build-tps-deps
build-tps-deps:
	@./scripts/install_build_deps.sh --tps

.PHONY: build-tps
build-tps: lift-protocol-limits-patch all build-tezt
	@dune build ./src/bin_tps_evaluation
	@cp -f ./_build/default/src/bin_tps_evaluation/main_tps_evaluation.exe mavryk-tps-evaluation
	@cp -f ./src/bin_tps_evaluation/mavryk-tps-evaluation-benchmark-tps .
	@cp -f ./src/bin_tps_evaluation/mavryk-tps-evaluation-estimate-average-block .
	@cp -f ./src/bin_tps_evaluation/mavryk-tps-evaluation-gas-tps .

.PHONY: build-octogram
build-octogram: all
	@dune build ./src/bin_octogram
	@cp -f ./_build/default/src/bin_octogram/octogram_main.exe octogram

.PHONY: build-unreleased
build-unreleased: all
	@echo 'Note: "make build-unreleased" is deprecated. Just use "make".'

.PHONY: docker-image-build
docker-image-build:
	@docker build \
		-t $(DOCKER_BUILD_IMAGE_NAME):$(DOCKER_BUILD_IMAGE_VERSION) \
		-f build.Dockerfile \
		--build-arg BASE_IMAGE=$(DOCKER_DEPS_IMAGE_NAME) \
		--build-arg BASE_IMAGE_VERSION=$(DOCKER_DEPS_IMAGE_VERSION) \
		.

.PHONY: docker-image-debug
docker-image-debug:
	docker build \
		-t $(DOCKER_DEBUG_IMAGE_NAME):$(DOCKER_DEBUG_IMAGE_VERSION) \
		--build-arg BASE_IMAGE=$(DOCKER_DEPS_IMAGE_NAME) \
		--build-arg BASE_IMAGE_VERSION=$(DOCKER_DEPS_MINIMAL_IMAGE_VERSION) \
		--build-arg BUILD_IMAGE=$(DOCKER_BUILD_IMAGE_NAME) \
		--build-arg BUILD_IMAGE_VERSION=$(DOCKER_BUILD_IMAGE_VERSION) \
		--target=debug \
		.

.PHONY: docker-image-bare
docker-image-bare:
	@docker build \
		-t $(DOCKER_BARE_IMAGE_NAME):$(DOCKER_BARE_IMAGE_VERSION) \
		--build-arg=BASE_IMAGE=$(DOCKER_DEPS_IMAGE_NAME) \
		--build-arg=BASE_IMAGE_VERSION=$(DOCKER_DEPS_MINIMAL_IMAGE_VERSION) \
		--build-arg=BASE_IMAGE_VERSION_NON_MIN=$(DOCKER_DEPS_IMAGE_VERSION) \
		--build-arg BUILD_IMAGE=$(DOCKER_BUILD_IMAGE_NAME) \
		--build-arg BUILD_IMAGE_VERSION=$(DOCKER_BUILD_IMAGE_VERSION) \
		--target=bare \
		.

.PHONY: docker-image-minimal
docker-image-minimal:
	@docker build \
		-t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION) \
		--build-arg=BASE_IMAGE=$(DOCKER_DEPS_IMAGE_NAME) \
		--build-arg=BASE_IMAGE_VERSION=$(DOCKER_DEPS_MINIMAL_IMAGE_VERSION) \
		--build-arg=BASE_IMAGE_VERSION_NON_MIN=$(DOCKER_DEPS_IMAGE_VERSION) \
		--build-arg BUILD_IMAGE=$(DOCKER_BUILD_IMAGE_NAME) \
		--build-arg BUILD_IMAGE_VERSION=$(DOCKER_BUILD_IMAGE_VERSION) \
		.

.PHONY: docker-image
docker-image: docker-image-build docker-image-debug docker-image-bare docker-image-minimal

.PHONY: install
install:
	@dune build --profile=$(PROFILE) @install
	@dune install

.PHONY: uninstall
uninstall:
	@dune uninstall

.PHONY: coverage-clean
coverage-clean:
	@-rm -Rf ${COVERAGE_OUTPUT}/*.coverage ${COVERAGE_REPORT}

.PHONY: pkg-common-clean
pkg-common-clean:
	@-rm -rf scripts/pkg-common/{baker,client,smartrollup}-binaries

.PHONY: dpkg-clean
dpkg-clean: pkg-common-clean
	@-rm -rf _dpkgstage *.deb

.PHONY: rpm-clean
rpm-clean: pkg-common-clean
	@-rm -rf _rpmbuild *.rpm

.PHONY: clean
clean: coverage-clean clean-old-names dpkg-clean rpm-clean
	@-dune clean
	@-rm -f ${ALL_EXECUTABLES}
	@-${MAKE} -C docs clean
	@-rm -f docs/api/mavryk-{baker,endorser,accuser}-alpha.html docs/api/mavryk-{admin-,}client.html docs/api/mavryk-signer.html

.PHONY: build-kernels-deps
build-kernels-deps:
	$(MAKE) -f kernels.mk build-deps
	$(MAKE) -f etherlink.mk build-deps
	$(MAKE) -C src/risc_v build-deps

.PHONY: build-kernels-dev-deps
build-kernels-dev-deps:
	$(MAKE) -f kernels.mk build-dev-deps
	$(MAKE) -f etherlink.mk build-dev-deps

.PHONY: build-kernels
build-kernels:
	$(MAKE) -f kernels.mk build
	$(MAKE) -f etherlink.mk build
	$(MAKE) -C src/risc_v build

.PHONY: check-kernels
check-kernels:
	$(MAKE) -f kernels.mk check
	$(MAKE) -f etherlink.mk check
	$(MAKE) -C src/risc_v check

.PHONY: test-kernels
test-kernels:
	$(MAKE) -f kernels.mk test
	$(MAKE) -f etherlink.mk test
	$(MAKE) -C src/risc_v test

.PHONY: clean-kernels
clean-kernels:
	$(MAKE) -f kernels.mk clean
	$(MAKE) -f etherlink.mk clean
	$(MAKE) -C src/risc_v clean
