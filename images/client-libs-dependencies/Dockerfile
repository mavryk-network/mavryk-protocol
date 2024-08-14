# runtime + end-to-end test dependencies
#
# This image builds on the runtime build test dependencies and additionally includes:
#
# - kaitai-struct-compiler installed from the source.
# - xxd.
# - java.
# - node version $recommended_node_version and dependencies from package.json in the root.

# This image is intended for
# - Running end-to-end semantic validation of automatically generated
#   kaitai struct files (.ksy files).

ARG BUILD_IMAGE

# hadolint ignore=DL3006
FROM ${BUILD_IMAGE}

LABEL org.opencontainers.image.title="client-libs-dependencies"

USER root
WORKDIR /tmp

# hadolint ignore=DL3018
RUN apk update && apk add --no-cache \
    # Install xxd that is required for input generation of e2e kaitai semantic validation.
    # mavryk-network/mavryk-protocol CI job 'kaitai_e2e_checks' requires coreutils mktemp
    xxd coreutils \
    # Required to clone "kaitai-struct-compiler"
    git \
    # Install Java for building and running "kaitai-struct-compiler".
    openjdk11 \
    # deps for nodejs/install-nvm.sh
    bash wget gcc make \
    # deps for running compiled executables: _build/default/client-libs/bin_codec_kaitai/codec.exe
    libev-dev hidapi-dev

# Install "kaitai-struct-compiler".
# Building "kaitai-struct-compiler" from source is described here:
#    - https://doc.kaitai.io/developers.html#_prerequisites
# This requires temporarily installing Scala Build Tool (sbt).
# Ignore warning from use of 'cd'.
ARG SBT_VERSION=1.9.7
COPY sbt-$SBT_VERSION.tgz.sha256 .
RUN wget -q https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz \
    && sha256sum --check sbt-${SBT_VERSION}.tgz.sha256 \
    && tar xfz sbt-${SBT_VERSION}.tgz -C /tmp
# Clone the repository.
ARG KSC_TAG=11b8e7f1b1849aaebcae32836b393d12be78b87f
ARG KSC_VERSION=0.11-SNAPSHOT
# hadolint ignore=DL3003
RUN git clone --recursive https://github.com/kaitai-io/kaitai_struct.git \
    # Change working directory to "kaitai_scruct/compiler" as specified here:
    #    - https://doc.kaitai.io/developers.html#_building_for_jvm
    && cd /tmp/kaitai_struct \
    && git checkout --recurse-submodules ${KSC_TAG}
# Build universal zip package as specified here:
#    - https://doc.kaitai.io/developers.html#_building_for_jvm
WORKDIR /tmp/kaitai_struct/compiler
RUN /tmp/sbt/bin/sbt compilerJVM/universal:packageBin \
    # Unzip executable to "/usr/local".
    && unzip jvm/target/universal/kaitai-struct-compiler-${KSC_VERSION}.zip -d /usr/local \
    # Remove "kaitai-struct" repository and "sbt".
    && rm -rf /tmp/sbt-${SBT_VERSION}.tgz /tmp/sbt-${SBT_VERSION}.tgz.sha256 /tmp/kaitai_struct /tmp/sbt /root/.cache /root/.sbt
# Make "kaitai-struct-compiler" available as part of the "PATH".
ENV PATH="/usr/local/kaitai-struct-compiler-${KSC_VERSION}/bin:${PATH}"

# Create a static system group and system user (no password + login shell)
# Prepare sudo, ssh and run
RUN echo 'mavryk:x:1000:mavryk' >> /etc/group \
 && echo 'mavryk:x:1000:1000:mavryk:/home/mavryk:/bin/sh' >> /etc/passwd \
 && echo 'mavryk:!::0:::::' >> /etc/shadow \
 && mkdir -pv /home/mavryk/.ssh /run/mavryk/client /run/mavryk/node \
 && chown -R mavryk:mavryk /home/mavryk /run/mavryk \
 && chmod 700 /home/mavryk/.ssh \
 && mkdir -pv /etc/sudoers.d \
 && echo 'mavryk ALL=(ALL:ALL) NOPASSWD:ALL' > /etc/sudoers.d/mavryk \
 && chmod 440 /etc/sudoers.d/mavryk

USER mavryk
ENV USER=mavryk
WORKDIR /home/mavryk

COPY --chown=mavryk:mavryk install-nvm.sh /tmp/install-nvm.sh
RUN /tmp/install-nvm.sh && rm -rf /tmp/install-nvm.sh

# Install the recommended Node version and the Mavkit JS dependencies.
ARG recommended_node_version=18.18.2
COPY --chown=mavryk:mavryk install_build_deps.js.sh /tmp/install_build_deps.js.sh
COPY --chown=mavryk:mavryk package.json /home/mavryk/package.json
COPY --chown=mavryk:mavryk package-lock.json /home/mavryk/package-lock.json
RUN /tmp/install_build_deps.js.sh && rm -rf /tmp/install_build_deps.js.sh /home/mavryk/package.json /home/mavryk/package-lock.json
