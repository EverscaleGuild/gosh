#!/usr/bin/env bash
set -e

REPO_NAME=demo-100
GOSH_NETWORK=net.ton.dev
GOSH_ROOT_CONTRACT=0:2f4ade4a98f916f47b1b2ff7abe1ee8a096d8443754b01b092d5043aa8ba1c8e
GOSH_ADDRESS=gosh::"$GOSH_NETWORK"://"$GOSH_ROOT_CONTRACT"/"$REPO_NAME"

echo Cloning "$GOSH_ADDRESS"

docker run --rm -ti \
    -v "$(pwd)":/root \
    teamgosh/git-remote-gosh \
    clone \
    "$GOSH_ADDRESS" \
    "$REPO_NAME"
