#!/usr/bin/env bash
set -e

NETWORKS="${NETWORKS:-https://gra01.net.everos.dev}"
TARGET_IMAGE=teamgosh/sample-target-image
REPO_NAME=demo-100
GOSH_NETWORK=net.ton.dev
GOSH_ROOT_CONTRACT=0:2f4ade4a98f916f47b1b2ff7abe1ee8a096d8443754b01b092d5043aa8ba1c8e
GOSH_ADDRESS=gosh::"$GOSH_NETWORK"://"$GOSH_ROOT_CONTRACT"/"$REPO_NAME"

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



###
step 1. Clone GOSH repo


if [[ -d "$REPO_NAME" ]]; then

    cd "$REPO_NAME"
    # git
    docker run --rm -ti -v "$(pwd)":/root teamgosh/git-remote-gosh \
        pull
    cd ..

else

    # git
    docker run --rm -ti -v "$(pwd)":/root teamgosh/git-remote-gosh \
        clone \
        "$GOSH_ADDRESS" \
        "$REPO_NAME"

fi



###
step 2. Get current commit hash

cd "$REPO_NAME"
GOSH_COMMIT_HASH=$(git rev-parse HEAD)
cd ..

echo Current commit hash: "$GOSH_COMMIT_HASH"


###
step 3. Build the image from GOSH repo

cd "$REPO_NAME"

docker buildx build \
    -f goshfile.yaml \
    -t "$TARGET_IMAGE" \
    --label WALLET_PUBLIC="$WALLET_PUBLIC" \
    --label GOSH_ADDRESS="$GOSH_ADDRESS" \
    --label GOSH_COMMIT_HASH="$GOSH_COMMIT_HASH" \
    --push \
    --no-cache \
    .

cd ..

docker pull "$TARGET_IMAGE"



###
step 4. Get image GOSH_HASH

GOSH_IMAGE_SHA=$(../../../docker-extension/vm/commands/gosh-image-sha.sh "$TARGET_IMAGE")
echo GOSH_IMAGE_SHA "$GOSH_IMAGE_SHA"

# same for alpine bash
GOSH_IMAGE_SHA_ALPINE=$(docker run --rm -ti \
    -v /var/run/docker.sock:/var/run/docker.sock \
    teamgosh/alpine-hash \
    /command/gosh-image-sha.sh "$TARGET_IMAGE" | tr -d '\r\n')
echo GOSH_IMAGE_SHA_ALPINE "$GOSH_IMAGE_SHA_ALPINE"



###
step 5. Sign the image

echo "Signing GOSH_IMAGE_SHA"
check=$(docker run --rm teamgosh/sign-cli check \
    -n "$NETWORKS" \
    "$WALLET_PUBLIC" \
    "$GOSH_IMAGE_SHA")

if [[ "$check" = "true"* ]]; then
    echo GOSH_IMAGE_SHA is already signed. Nothing to do.
else
    docker run --rm teamgosh/sign-cli sign \
        -n "$NETWORKS" \
        -g "$WALLET" \
        -s "$WALLET_SECRET" \
        "$WALLET_SECRET" \
        "$GOSH_IMAGE_SHA"
fi

# same for alpine bash
echo "Signing GOSH_IMAGE_SHA_ALPINE"
check=$(docker run --rm teamgosh/sign-cli check \
    -n "$NETWORKS" \
    "$WALLET_PUBLIC" \
    "$GOSH_IMAGE_SHA_ALPINE")

if [[ "$check" = "true"* ]]; then
    echo GOSH_IMAGE_SHA_ALPINE is already signed. Nothing to do.
else
    docker run --rm teamgosh/sign-cli sign \
        -n "$NETWORKS" \
        -g "$WALLET" \
        -s "$WALLET_SECRET" \
        "$WALLET_SECRET" \
        "$GOSH_IMAGE_SHA_ALPINE"
fi
