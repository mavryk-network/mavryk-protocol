FROM mavryk-network/mavryk-protocol-debug:amd64_master

WORKDIR /home/mavryk

RUN mkdir -p scripts
RUN mkdir -p output

# environment variables
ENV NODE_ENV=production
ENV EXTERNAL_RESSOURCES=/usr/local/share/mavryk/evm_kernel
ENV OUTPUT=/home/mavryk/output

# install node dependencies
USER root
RUN apk add nodejs npm
USER mavryk

# copy scripts
COPY --chown=mavryk:nogroup package.json .
COPY --chown=mavryk:nogroup scripts scripts
COPY --chown=mavryk:nogroup docker/command.sh .
RUN chmod +x command.sh

# install scripts dependencies
RUN npm install --omit=optional

# launch benchmarking
ENTRYPOINT ["./command.sh"]