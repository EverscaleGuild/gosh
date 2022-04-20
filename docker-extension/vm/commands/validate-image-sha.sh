#!/bin/bash
set -e

# 

# params: repo commit_hash
# output: gosh_hash

REPOSITORY_NAME=$1
COMMIT_HASH=$2

GOSH_NETWORK="net.ton.dev"
GOSH_ROOT_CONTRACT_ADDRESS="0:2f4ade4a98f916f47b1b2ff7abe1ee8a096d8443754b01b092d5043aa8ba1c8e"

NETWORKS="${NETWORKS:-https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev}"

GOSH_REMOTE_URL=gosh::${GOSH_NETWORK}://${GOSH_ROOT_CONTRACT_ADDRESS}/"$REPOSITORY_NAME"


{
    LAST_PWD=$(pwd)
    mkdir -p /workdir/"$REPOSITORY_NAME"
    cd /workdir/"$REPOSITORY_NAME"

    git clone "$GOSH_REMOTE_URL" "$REPOSITORY_NAME"

    cd "$REPOSITORY_NAME"
    git fetch -a
    git checkout "$COMMIT_HASH"

    IDDFILE=../"$REPOSITORY_NAME".iidfile

    docker buildx build \
        -f goshfile.yaml \
        --load \
        --iidfile "$IDDFILE" \
        --no-cache \
        .

    TARGET_IMAGE=$(< "$IDDFILE")

    if [[ -z "$TARGET_IMAGE" ]]; then
        echo "Error: Image was not built"
        exit 1
    fi

    GOSH_SHA=$(/command/gosh-image-sha.sh "$TARGET_IMAGE")
    docker rmi "$TARGET_IMAGE" || true

    cd "$LAST_PWD"
} >&2

echo "$GOSH_SHA"
