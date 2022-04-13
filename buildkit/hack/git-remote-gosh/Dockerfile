# syntax=docker/dockerfile:1.4

FROM node:17-bullseye-slim

RUN --mount=type=cache,target=/var/cache/apt --mount=type=cache,target=/var/lib/apt <<EOF
    set -ex
    apt-get update -qy
    apt-get install git -qy
EOF
ENTRYPOINT [ "git" ]

WORKDIR /app
COPY gosh gosh
COPY git-remote-gosh git-remote-gosh

ENV NODE_ENV=production

RUN <<EOF
    set -ex
    cd /app/git-remote-gosh
    npm i
    chmod +x git-remote-gosh.js
    cd /usr/local/bin
    ln -s /app/git-remote-gosh/git-remote-gosh.js git-remote-gosh
EOF

WORKDIR /root
