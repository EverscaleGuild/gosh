# syntax=docker/dockerfile:1.4
FROM --platform=${BUILDPLATFORM} node:16-slim as base

FROM base
ARG content_signature_local_dir
ARG git_remote_gosh_local_dir
ARG gosh_abi_local_dir

LABEL org.opencontainers.image.title="Gosh" \
    org.opencontainers.image.description="Build your decentralized and secure software supply chain with Docker and Git Open Source Hodler" \
    org.opencontainers.image.vendor="EverX" \
    com.docker.desktop.extension.api.version=">=0.2.1" \
    com.docker.desktop.extension.icon="http://icons.gosh.run/Gosh%20icon%20-%20black.svg" \
    com.docker.extension.detailed-description="<p><strong>GOSH</strong> is a blockchain built around securing the software supply chain and capturing the immense value in open source projects. This is achieved through record-setting blockchain tech, distributed programming, and a decentralized architecture - integrated into the same familiar git, meaning there is no change to the workflow.</p><p><strong>GOSH Docker Extension</strong> implements GOSH repository management and image verification as the newest feature of Docker - a Docker Extension. </p><p>You will be able to create your GOSH account and Decentralized  Autonomous Organization (DAO), set up and manage repositories through a graphical interface directly in Docker Desktop. Repositories stored in GOSH can then be interacted with like any regular remote repository, with a few small configurations to git, making decentralized code management easily available to anyone.</p><p>Images built directly from code stored in GOSH can be verified as GOSH-sourced in the Docker Extension, ensuring security of the software supply chain. You will always know what code specifically is running in your containers, and that none of it was tampered with during build.</p>" \
    com.docker.extension.publisher-url="https://www.gosh.sh"

RUN <<EOF
    set -ex
    apt-get update -qy
    apt-get install -qy git docker bash ca-certificates
EOF

COPY --link --from=docker/buildx-bin:latest /buildx /usr/libexec/docker/cli-plugins/docker-buildx

COPY --link metadata.json /
COPY --link ./vm/docker-compose.yaml /
COPY --link ./vm/commands/ /command/
COPY --link $content_signature_local_dir /command/tools/content-signature
COPY --link $git_remote_gosh_local_dir /command/tools/git-remote-gosh
COPY --link $gosh_abi_local_dir /command/tools/gosh

ENV GOSH_PROTO=http
ENV DOCKER_BUILDKIT=1
ENV DOCKER_CLI_EXPERIMENTAL=enabled
ENV NODE_ENV=production

ARG TARGETOS TARGETARCH
WORKDIR /command/tools/content-signature
RUN npm i

WORKDIR /command/tools/git-remote-gosh
RUN rm -rf node_modules && rm package-lock.json && npm i

RUN ln -s /command/tools/git-remote-gosh/git-remote-gosh.js  /usr/local/bin/git-remote-gosh

COPY --link icon.svg /

COPY --link index.html /ui/index.html

CMD [ "sleep", "infinity" ]
