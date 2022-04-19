#!/usr/bin/env bash
set -e

NETWORKS="${NETWORKS:-https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev}"
TARGET_IMAGE=teamgosh/sample-target-image
REPO_DIR=example1
GOSH_ADDRESS=gosh::net.ton.dev://0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/gosh/example

if [[ -z "$WALLET" ]] || [[ -z "$WALLET_PUBLIC" ]] || [[ -z "$WALLET_SECRET" ]]; then
    echo "Make sure \$WALLET \$WALLET_PUBLIC \$WALLET_SECRET are set"
    echo "export WALLET=..."
    echo "export WALLET_SECRET=..."
    echo "export WALLET_PUBLIC=..."
    exit
fi

step() {
    echo
    echo
    echo "$@"
    echo
}

step 1. Clone GOSH repo

docker run --rm -ti \
    -v "$(pwd)":/root \
    teamgosh/git-remote-gosh \
    clone \
    "$GOSH_ADDRESS" \
    "$REPO_DIR"

step 2. Get current commit hash

cd "$REPO_DIR"
GOSH_COMMIT_HASH=$(git rev-parse HEAD)
cd ..
echo Current commit hash: "$GOSH_COMMIT_HASH"

step 3. Build the image from GOSH repo

docker buildx build \
    -f example1/goshfile.yaml \
    -t "$TARGET_IMAGE" \
    --label WALLET_PUBLIC="$WALLET_PUBLIC" \
    --label GOSH_ADDRESS="$GOSH_ADDRESS" \
    --label GOSH_COMMIT_HASH="$GOSH_COMMIT_HASH" \
    --push \
    "$REPO_DIR"

step 4. Get image GOSH_HASH

GOSH_IMAGE_SHA=$(../../../docker-extension/vm/commands/gosh-image-sha.sh "$TARGET_IMAGE")
echo GOSH_IMAGE_SHA "$GOSH_IMAGE_SHA"

step 5. Sign the image

docker run --rm teamgosh/sign-cli sign \
    -n "$NETWORKS" \
    -g "$WALLET" \
    -s "$WALLET_SECRET" \
    "$WALLET_SECRET" \
    "$GOSH_IMAGE_SHA"
