#!/bin/sh

PUBLISHER_KEY=$1
IMAGE_HASH=$2

cd /command/tools/content-signature/
node cli check --network https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev $PUBLISHER_KEY $IMAGE_HASH

