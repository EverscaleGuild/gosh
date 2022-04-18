#!/bin/bash

get_gosh_image_sha() {
    local TARGET_IMAGE=$1

    {
        CONTAINER_ID=$(docker create "$TARGET_IMAGE" /bin/sh 2>/dev/null)

        mkdir -p "$CONTAINER_ID"

        cd "$CONTAINER_ID" || exit 1
        docker export "$CONTAINER_ID" | tar --exclude=etc/mtab --exclude=proc --exclude=dev -xf -
        GOSH_SHA256=$(find . -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum | awk '{ print $1 }')
        cd .. || exit 1

        docker rm -fv "$CONTAINER_ID" >/dev/null
        rm -rf "$CONTAINER_ID"
    } > /dev/null 2>&1

    echo "$GOSH_SHA256"
}
