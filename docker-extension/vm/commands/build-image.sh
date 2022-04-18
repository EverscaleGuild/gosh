#!/bin/sh
set -e

GOSH_NETWORK="net.ton.dev"
GOSH_ROOT_CONTRACT_ADDRESS="0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f"
REPOSITORY_NAME=$1
TARGET_IMAGE=$2


NETWORKS="${NETWORKS:-https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev}"

mkdir -p /workdir/$REPOSITORY_NAME
cd /workdir/$REPOSITORY_NAME
git clone gosh::${GOSH_NETWORK}://${GOSH_ROOT_CONTRACT_ADDRESS}/$REPOSITORY_NAME
cd $REPOSITORY_NAME

set DOCKER_BUILDKIT=1
set DOCKER_CLI_EXPERIMENTAL=enabled

TARGET_IMAGE=$(docker buildx build \
    -f goshfile.yaml \
    --iidfile ../id.txt \
    --load \
    --rm \
    --quiet \
    --no-cache \
    . )

if [[ -z "$TARGET_IMAGE" ]]; then
    echo "Error: Image was not built"
    exit 1
fi

TARGET_IMAGE_SHA=$(docker inspect --format='{{index (split (index .RepoDigests 0) "@") 1}}' $TARGET_IMAGE)

if [[ -z "$TARGET_IMAGE_SHA" ]]; then
    echo "Error: Target image hash not found"
    exit 2
fi
