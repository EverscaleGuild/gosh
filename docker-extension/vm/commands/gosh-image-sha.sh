#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 target_image"
    exit 1
fi

TARGET_IMAGE=$1

# TARGET_IMAGE=127.0.0.1:5000/buildctl-gosh-simple:latest
# docker pull "$TARGET_IMAGE"

# docker buildx build --load -q -t test-hash -f - . <<EOF
# FROM alpine
# WORKDIR /out
# RUN --mount=type=bind,from="$TARGET_IMAGE",source=/,target=. \
#     find . -type f -exec sha256sum -b {} + | LC_ALL=C sort | sha256sum | awk '{ printf "sha256:%s", \$1 }' > /hash
# EOF
# docker run --rm -ti test-hash cat /hash

{
    docker pull "$TARGET_IMAGE"
    CONTAINER_ID=$(docker create "$TARGET_IMAGE" /bin/sh)

    mkdir -p "$CONTAINER_ID"

    cd "$CONTAINER_ID" || exit 1
    docker export "$CONTAINER_ID" | tar --exclude=etc/mtab --exclude=proc --exclude=dev -xf -
    GOSH_SHA256=$(find . -type f -exec sha256sum -b {} + | LC_ALL=C sort | sha256sum | awk '{ print $1 }')
    cd .. || exit 1

    docker rm -fv "$CONTAINER_ID" >/dev/null
    rm -rf "$CONTAINER_ID"
} > /dev/null 2>&1

printf 'sha256:%s' "$GOSH_SHA256"
