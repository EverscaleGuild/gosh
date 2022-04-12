#!/usr/bin/env bash

TARGET_IMAGE=teamgosh/example1
NETWORKS="${NETWORKS:-https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev}"

if [[ -z "$WALLET" ]] || [[ -z "$WALLET_PUBLIC" ]] || [[ -z "$WALLET_SECRET" ]]; then
    echo "Make sure \$WALLET \$WALLET_PUBLIC \$WALLET_SECRET are set"
    echo "export WALLET=..."
    echo "export WALLET_SECRET=..."
    echo "export WALLET_PUBLIC=..."
    exit
fi

echo
echo Clone from GOSH ...
echo
echo
docker run --rm -ti \
    -v "$(pwd)":/root \
    teamgosh/git-remote-gosh \
    clone \
    gosh::net.ton.dev://0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/gosh/example \
    example1

echo
echo Clone DONE
echo
echo


read -r -p "Build. Continue? [y/N] : " y
[[ ! "$y" = [yY]* ]] && exit 1

echo
echo Build and push with GOSH frontend
echo
echo

docker buildx build \
    -f example1/goshfile.yaml \
    -t $TARGET_IMAGE \
    --label WALLET_PUBLIC="$WALLET_PUBLIC" \
    --push \
    example1

docker pull "$TARGET_IMAGE"
TARGET_IMAGE_SHA=$(docker inspect --format='{{index (split (index .RepoDigests 0) "@") 1}}' $TARGET_IMAGE)

if [[ -z "$TARGET_IMAGE_SHA" ]]; then
    echo Error: Target image hash not found
    exit
fi

echo
echo Build and push DONE
echo Image: "$TARGET_IMAGE"@"$TARGET_IMAGE_SHA"
echo
echo


read -r -p "Sign. Continue? [y/N] : " y
[[ ! "$y" = [yY]* ]] && exit 1

echo
echo Sign "$TARGET_IMAGE"@"$TARGET_IMAGE_SHA"
echo with public key "$WALLET_PUBLIC"
echo

docker run --rm teamgosh/sign-cli sign \
    -n "$NETWORKS" \
    -g "$WALLET" \
    -s "$WALLET_SECRET" \
    "$WALLET_SECRET" \
    "$TARGET_IMAGE_SHA"

echo
echo Image signed
echo
echo

read -r -p "Check. Continue? [y/N] : " y
[[ ! "$y" = [yY]* ]] && exit 1

echo
echo Check "$TARGET_IMAGE"@"$TARGET_IMAGE_SHA"
echo -n ...

docker run --rm teamgosh/sign-cli check \
    -n "$NETWORKS" \
    "$WALLET_PUBLIC" \
    "$TARGET_IMAGE_SHA"

echo
echo DONE
echo
