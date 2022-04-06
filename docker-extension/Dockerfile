FROM node:16.14-alpine AS build

RUN apk --no-cache add curl coreutils docker yarn \
    ca-certificates file iptables libc6-compat libgcc libstdc++ wget && \
    update-ca-certificates && \
    ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2

COPY --chown=root ./ui/ /ui-build/

RUN cd /ui-build && yarn install --silent && npm run build --silent

FROM node:16.14-alpine
ARG content_signature_local_dir

LABEL org.opencontainers.image.title="Gosh" \
    org.opencontainers.image.description="Build your decentralized and secure software supply chain with Docker and Git On-chain Source Holder" \
    org.opencontainers.image.vendor="EverX" \
    com.docker.desktop.extension.api.version=">=0.2.1" \
    com.docker.desktop.extension.icon="/icon.svg"

COPY --from=build /ui-build/build /ui 
COPY metadata.json /
COPY ./vm/docker-compose.yaml /
COPY ./vm/commands/ /command/
COPY $content_signature_local_dir /command/

RUN cd /command/content-signature/ && npm install --production

COPY icon.svg /

CMD [ "sleep", "infinity" ]
