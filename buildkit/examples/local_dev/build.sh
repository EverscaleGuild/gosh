#!/usr/bin/env bash

[[ -z "$1" ]] && exit

SCRIPT_DIR=$(dirname "${BASH_SOURCE[-1]}")
cd "$SCRIPT_DIR" || exit
DOCKER_REG="${DOCKER_REG:-127.0.0.1:5000}"
IMAGE="$DOCKER_REG"/buildctl-gosh-simple

case "$1" in
    build)
        docker buildx build \
            --push \
            --label WALLET_PUBLIC="$WALLET_PUBLIC" \
            -f goshfile.yaml \
            -t "$IMAGE" .

        docker inspect --format '{{ json .Config }}' "$IMAGE"
        ;;
    buildctl)
        buildctl --addr=docker-container://buildkitd build \
            --frontend gateway.v0 \
            --local dockerfile=. \
            --local context=. \
            --opt source="$DOCKER_REG"/goshfile \
            --opt filename=goshfile.yaml \
            --opt wallet="$WALLET" \
            --opt wallet_secret="$WALLET_SECRET" \
            --opt wallet_public="$WALLET_PUBLIC" \
            --opt env=env.JAEGER_TRACE=localhost:6831 \
            --output type=image,name="$IMAGE",push=true
        ;;
    run)
        docker pull "$IMAGE"
        docker run --rm "$IMAGE" cat /message.txt
        ;;
    save)
        CONTAINER_ID=$(docker create "$IMAGE" /bin/sh)
        mkdir -p "$CONTAINER_ID"
        (
            cd "$CONTAINER_ID" || exit
            docker export "$CONTAINER_ID" | tar --exclude=etc/mtab --exclude=proc --exclude=dev -xf -
            docker rm -fv "$CONTAINER_ID"
            find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum > ../"$CONTAINER_ID".sha
        )
        ;;
esac
