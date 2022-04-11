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
    git clone \
    gosh::net.ton.dev://0:a6af961f2973bb00fe1d3d6cfee2f2f9c89897719c2887b31ef5ac4fd060638f/gosh/example \
    example1

echo
echo Clone DONE
echo
echo

read -r -p "Continue? [y/N]
" y
[[ ! "$y" = [yY]* ]] && exit 1

echo
echo Build and push with GOSH frontend
echo
echo

docker buildx build \
    --push \
    -f example1/goshfile.yaml \
    --label WALLET_PUBLIC="$WALLET_PUBLIC" \
    -t $TARGET_IMAGE \
    example1

echo
echo Build and push DONE
echo
echo

read -r -p "Continue? [y/N]
" y
[[ ! "$y" = [yY]* ]] && exit 1

echo
echo Sign "$TARGET_IMAGE"
echo
echo

docker pull "$TARGET_IMAGE"

TARGET_IMAGE_SHA=$(docker inspect --format='{{index (split (index .RepoDigests 0) "@") 1}}' $TARGET_IMAGE)
echo TARGET_IMAGE_SHA=\'"$TARGET_IMAGE_SHA"\'

if [[ -z "$TARGET_IMAGE_SHA" ]]; then
    echo Target image hash not found
    exit
fi

docker run --rm teamgosh/sign-cli sign \
    -n "$NETWORKS" \
    -g "$WALLET" \
    -s "$WALLET_SECRET" \
    "$WALLET_SECRET" \
    "$TARGET_IMAGE_SHA"

read -r -p "Check? [y/N]
" y
[[ ! "$y" = [yY]* ]] && exit 1

docker run --rm teamgosh/sign-cli check \
    -n "$NETWORKS" \
    "$WALLET_PUBLIC" \
    "$TARGET_IMAGE_SHA"
