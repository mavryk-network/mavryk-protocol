ARG BASE_IMAGE=registry.gitlab.com/tezos/opam-repository
ARG BASE_IMAGE_VERSION
ARG RUST_TOOLCHAIN_IMAGE
ARG RUST_TOOLCHAIN_IMAGE_TAG

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as without-evm-artifacts
# use alpine /bin/ash and set pipefail.
# see https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
# Do not move the ARG below above the FROM or it gets erased.
# More precisely: ARG above FROM can be used in the FROM itself, but nowhere else.
ARG MAVKIT_EXECUTABLES
ARG GIT_SHORTREF
ARG GIT_DATETIME
ARG GIT_VERSION
WORKDIR /home/tezos
RUN mkdir -p /home/tezos/mavryk/scripts /home/tezos/mavryk/script-inputs /home/tezos/mavryk/parameters /home/tezos/evm_kernel
COPY --chown=tezos:nogroup Makefile mavryk
COPY --chown=tezos:nogroup script-inputs/active_protocol_versions mavryk/script-inputs/
COPY --chown=tezos:nogroup script-inputs/active_protocol_versions_without_number mavryk/script-inputs/
COPY --chown=tezos:nogroup script-inputs/released-executables mavryk/script-inputs/
COPY --chown=tezos:nogroup script-inputs/experimental-executables mavryk/script-inputs/
COPY --chown=tezos:nogroup script-inputs/dev-executables mavryk/script-inputs/
COPY --chown=tezos:nogroup dune mavryk
COPY --chown=tezos:nogroup scripts/version.sh mavryk/scripts/
COPY --chown=tezos:nogroup src mavryk/src
COPY --chown=tezos:nogroup irmin mavryk/irmin
COPY --chown=tezos:nogroup tezt mavryk/tezt
COPY --chown=tezos:nogroup opam mavryk/opam
COPY --chown=tezos:nogroup dune mavryk/dune
COPY --chown=tezos:nogroup dune-workspace mavryk/dune-workspace
COPY --chown=tezos:nogroup dune-project mavryk/dune-project
COPY --chown=tezos:nogroup vendors mavryk/vendors
COPY --chown=tezos:nogroup devtools/testnet_experiment_tools mavryk/devtools/testnet_experiment_tools
ENV GIT_SHORTREF=${GIT_SHORTREF}
ENV GIT_DATETIME=${GIT_DATETIME}
ENV GIT_VERSION=${GIT_VERSION}
RUN opam exec -- make -j 20 -C mavryk release MAVKIT_EXECUTABLES="${MAVKIT_EXECUTABLES}" MAVKIT_BIN_DIR=bin
# Build the simulation-scenario tool
RUN opam exec -- make -j 20 -C mavryk build-simulation-scenario MAVKIT_BIN_DIR=bin
# Gather the parameters of all active protocols in 1 place
RUN while read -r protocol; do \
  mkdir -p mavryk/parameters/"$protocol"-parameters && \
  cp mavryk/src/proto_"$(echo "$protocol" | tr - _)"/parameters/*.json mavryk/parameters/"$protocol"-parameters; \
  done < mavryk/script-inputs/active_protocol_versions

WORKDIR /home/tezos/
