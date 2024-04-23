ARG BASE_IMAGE
ARG BASE_IMAGE_VERSION
ARG BASE_IMAGE_VERSION_NON_MIN
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION

FROM ${BUILD_IMAGE}:${BUILD_IMAGE_VERSION} as builder


FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as intermediate
# Pull in built binaries
COPY --chown=tezos:nogroup --from=builder /home/mavryk/mavryk/bin /home/mavryk/bin
# Add parameters for active protocols
COPY --chown=tezos:nogroup --from=builder /home/mavryk/mavryk/parameters /home/mavryk/scripts/
# Add EVM kernel artifacts
RUN ls -la /home/mavryk/scripts
RUN mkdir -p /home/mavryk/scripts/evm_kernel
COPY --chown=tezos:nogroup --from=builder /home/mavryk/evm_kernel/evm_installer.wasm* /home/mavryk/evm_kernel/_evm_installer_preimages* /home/mavryk/scripts/evm_kernel/
COPY --chown=tezos:nogroup --from=builder /home/mavryk/evm_kernel/evm_benchmark_installer.wasm* /home/mavryk/evm_kernel/_evm_unstripped_installer_preimages* /home/mavryk/scripts/evm_kernel/

# Add entrypoint scripts
COPY --chown=tezos:nogroup scripts/docker/entrypoint.* /home/mavryk/bin/
# Add scripts
COPY --chown=tezos:nogroup scripts/alphanet_version src/bin_client/bash-completion.sh script-inputs/active_protocol_versions /home/mavryk/scripts/

FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as debug
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION
ARG COMMIT_SHORT_SHA

# Open Container Initiative
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="info@mavryk.io" \
      org.opencontainers.image.base.name="alpine:3.14" \
      org.opencontainers.image.description="Mavryk node" \
      org.opencontainers.image.documentation="https://tezos.gitlab.io/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.title="mavryk-debug" \
      org.opencontainers.image.url="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.vendor="Mavryk Dynamics"

USER root
# hadolint ignore=DL3018
RUN apk --no-cache add vim
USER tezos

ENV EDITOR=/usr/bin/vi
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/bin /usr/local/bin
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/scripts/ /usr/local/share/tezos/
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


FROM ${BASE_IMAGE}:${BASE_IMAGE_VERSION_NON_MIN} as stripper
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/bin /home/mavryk/bin
RUN rm /home/mavryk/bin/*.sh && chmod +rw /home/mavryk/bin/* && strip /home/mavryk/bin/*
# hadolint ignore=DL3003,DL4006,SC2046
RUN cd /home/mavryk/bin && for b in $(ls mavkit*); do ln -s "$b" $(echo "$b" | sed 's/^mavkit/mavryk/'); done


FROM  ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as bare
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION
ARG COMMIT_SHORT_SHA

# Open Container Initiative
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="info@mavryk.io" \
      org.opencontainers.image.base.name="alpine:3.14" \
      org.opencontainers.image.description="Mavryk node" \
      org.opencontainers.image.documentation="https://tezos.gitlab.io/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.title="mavryk-debug" \
      org.opencontainers.image.url="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.vendor="Mavryk Dynamics"

COPY --chown=tezos:nogroup --from=stripper /home/mavryk/bin /usr/local/bin
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/scripts/ /usr/local/share/tezos


FROM  ${BASE_IMAGE}:${BASE_IMAGE_VERSION} as minimal
ARG BUILD_IMAGE
ARG BUILD_IMAGE_VERSION
ARG COMMIT_SHORT_SHA

# Open Container Initiative
# https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.authors="info@mavryk.io" \
      org.opencontainers.image.base.name="alpine:3.14" \
      org.opencontainers.image.description="Mavryk node" \
      org.opencontainers.image.documentation="https://tezos.gitlab.io/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.title="mavryk-debug" \
      org.opencontainers.image.url="https://gitlab.com/mavryk-network/mavryk-protocol" \
      org.opencontainers.image.vendor="Mavryk Dynamics"

COPY --chown=tezos:nogroup --from=stripper /home/mavryk/bin /usr/local/bin
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/bin/entrypoint.* /usr/local/bin/
COPY --chown=tezos:nogroup --from=intermediate /home/mavryk/scripts/ /usr/local/share/tezos
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
