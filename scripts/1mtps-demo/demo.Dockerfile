ARG BASE_IMAGE_AND_VERSION

FROM $BASE_IMAGE_AND_VERSION as FOUNDATION
ARG INSTALL_SCRIPT
COPY $INSTALL_SCRIPT /tmp/install.sh
RUN /tmp/install.sh && rm /tmp/install.sh
RUN mkdir -p /opt/1mtps-demo/ /usr/local/share/zcash-params
COPY tx_kernel.wasm scripts/1mtps-demo/mint_and_deposit.tz /opt/1mtps-demo/
COPY scripts/1mtps-demo/sshd_config /etc/ssh
COPY _opam/share/zcash-params /usr/local/share/zcash-params
COPY octogram octez-node octez-client octez-smart-rollup-node octez-dac-node \
     octez-dac-client smart-rollup-installer tx-demo-collector /usr/local/bin/
