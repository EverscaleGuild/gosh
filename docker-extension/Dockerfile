FROM node:16.14-alpine
ARG content_signature_local_dir
ARG git_remote_gosh_local_dir
ARG gosh_abi_local_dir

LABEL org.opencontainers.image.title="Gosh" \
    org.opencontainers.image.description="Build your decentralized and secure software supply chain with Docker and Git On-chain Source Holder" \
    org.opencontainers.image.vendor="EverX" \
    com.docker.desktop.extension.api.version=">=0.2.1" \
    com.docker.desktop.extension.icon="http://icons.gosh.run/Gosh%20icon%20-%20black.svg"

RUN ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \
    && apk add git docker bash \
    && mkdir /assets

COPY index.html /ui/index.html
#COPY --from=build /ui-build/build /ui 

#COPY --from=build /ui-build/build/assets/eversdk.wasm /eversdk.wasm
#COPY --from=build /ui-build/build/assets/eversdk.wasm /assets/eversdk.wasm
COPY --from=docker/buildx-bin:latest /buildx /usr/libexec/docker/cli-plugins/docker-buildx

COPY metadata.json /
COPY ./vm/docker-compose.yaml /
COPY ./vm/commands/ /command/
COPY $content_signature_local_dir /command/tools/content-signature
COPY $git_remote_gosh_local_dir /command/tools/git-remote-gosh
COPY $gosh_abi_local_dir /command/tools/gosh

ENV DOCKER_BUILDKIT=1
ENV DOCKER_CLI_EXPERIMENTAL=enabled

RUN cd /command/tools/content-signature/ && npm install --production \
    && cd /command/tools/git-remote-gosh && rm -rf node_modules && npm install --production \
    && ln -s /command/tools/git-remote-gosh/git-remote-gosh.js  /usr/local/bin/git-remote-gosh

COPY icon.svg /

CMD [ "sleep", "infinity" ]
