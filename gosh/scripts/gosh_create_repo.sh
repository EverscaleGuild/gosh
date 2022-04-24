#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

source utils.sh

if [ -z $1 ]; then
    echo "Usage: $0 DAO_NAME REPO_NAME <NETWORK>"
    exit
fi

DAO_NAME=$1
REPO_NAME=$2

WALLET=../goshwallet
WALLET_ABI=$WALLET.abi.json
WALLET_KEYS=$WALLET.keys.json
WALLET_ADDR=$(cat $WALLET.addr)

GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_ADDR=$(cat $GOSH.addr)

TONOS_CLI=tonos-cli
NETWORK=${3:-localhost}

NINETY_EVERS=90000000000

CALLED="deployRepository {\"nameRepo\":\"$REPO_NAME\"}"
$TONOS_CLI -u $NETWORK call $WALLET_ADDR $CALLED --abi $WALLET_ABI --sign $WALLET_KEYS > /dev/null || exit 1

DAO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$DAO_NAME\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
REPO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrRepository "{\"dao\":\"$DAO_NAME\",\"name\":\"$REPO_NAME\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
./giver.sh $REPO_ADDR $NINETY_EVERS

echo ===================== REPO =====================
echo Gosh
echo " address:" $GOSH_ADDR
echo "DAO '$DAO_NAME'"
echo " address:" $DAO_ADDR
echo "repo ($(account_data $NETWORK $REPO_ADDR))"
echo "    name:" $REPO_NAME
echo " address:" $REPO_ADDR
echo "  remote:" "gosh::$NETWORK://$GOSH_ADDR/$DAO_NAME/gosh_test/repo03"
