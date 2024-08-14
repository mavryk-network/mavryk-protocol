ARG BASE_IMAGE
ARG BASE_IMAGE_VERSION
ARG BASE_IMAGE_VERSION_NON_MIN
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION

FROM ${BUILD_IMAGE}:${BUILD_IMAGE_VERSION} as builder


FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as intermediate
# Pull in built binaries
COPY --chown=mavryk:nogroup --from=builder /home/mavryk/mavryk/bin /home/mavryk/bin
# Add parameters for active protocols
COPY --chown=mavryk:nogroup --from=builder /home/mavryk/mavryk/parameters /home/mavryk/scripts/
# Add EVM kernel artifacts
RUN mkdir -p /home/mavryk/scripts/evm_kernel
COPY --chown=mavryk:nogroup --from=builder /home/mavryk/evm_kernel/evm_installer.wasm* /home/mavryk/evm_kernel/_evm_installer_preimages* /home/mavryk/scripts/evm_kernel/
COPY --chown=mavryk:nogroup --from=builder /home/mavryk/evm_kernel/evm_unstripped_installer.wasm* /home/mavryk/evm_kernel/_evm_unstripped_installer_preimages* /home/mavryk/scripts/evm_kernel/

# Add entrypoint scripts
COPY --chown=mavryk:nogroup scripts/docker/entrypoint.* /home/mavryk/bin/
# Add scripts
COPY --chown=mavryk:nogroup scripts/alphanet_version src/bin_client/bash-completion.sh script-inputs/active_protocol_versions /home/mavryk/scripts/

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION_NON_MIN} as stripper
COPY --chown=mavryk:nogroup --from=intermediate /home/mavryk/bin /home/mavryk/bin
# Remove scripts and symlinks pointing to potentially non-existing smart-rollup-node
RUN rm /home/mavryk/bin/*.sh && rm /home/mavryk/bin/mavkit-smart-rollup-node-*
RUN chmod +rw /home/mavryk/bin/* && strip /home/mavryk/bin/*
# hadolint ignore=DL3003,DL4006,SC2046
RUN cd /home/mavryk/bin && for b in $(ls mavkit*); do ln -s "$b" $(echo "$b" | sed 's/^mavkit/mavryk/'); done

FROM  ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as bare
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION
ARG COMMIT_SHORT_SHA
ARG GIT_HISTORY_FILE

# Open Container Initiative
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="info@mavryk.io" \
      org.opencontainers.image.base.name="alpine:3.14" \
      org.opencontainers.image.description="Mavryk node" \
      org.opencontainers.image.documentation="https://protocol.mavryk.org/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.title="mavryk-debug" \
      org.opencontainers.image.url="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.vendor="Mavryk Dynamics"

COPY --chown=mavryk:nogroup --from=stripper /home/mavryk/bin/ /usr/local/bin/
COPY --chown=mavryk:nogroup --from=intermediate /home/mavryk/scripts/ /usr/local/share/mavryk
COPY --chown=mavryk:nogroup ${GIT_HISTORY_FILE} /home/mavryk/git_history
