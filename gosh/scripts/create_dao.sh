#!/bin/bash
#	This file is part of Ever OS.
#
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#
#	Copyright 2019-2022 (c) EverX

source utils.sh

if [ -z $1 ]; then
    echo "Usage: $0 DAO_NAME <NETWORK>"
    exit
fi
DAO_NAME=$1

DAO_CREATOR=../daocreator
DAO_CREATOR_ABI=$DAO_CREATOR.abi.json
DAO_CREATOR_KEYS=$DAO_CREATOR.keys.json
DAO_CREATOR_ADDR=$(cat $DAO_CREATOR.addr)

GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_ADDR=$(cat $GOSH.addr)

DAO=../goshdao
DAO_KEYS=$DAO.keys.json

export TONOS_CLI=tonos-cli
export NETWORK=${2:-localhost}


if [ "$NETWORK" == "localhost" ]; then
    WALLET=wallets/localnode/SafeMultisigWallet
else
    WALLET=wallets/devnet/SafeMultisigWallet
fi

WALLET_ADDR=$(cat $WALLET.addr)
WALLET_ABI=$WALLET.abi.json
WALLET_KEYS=$WALLET.keys.json

DAO_PUBKEY=$(cat $WALLET_KEYS | sed -n '/public/ s/.*\([[:xdigit:]]\{64\}\).*/0x\1/p')

ONE_K_EVERS=1000000000000

CALLED="deployDao {\"root_pubkey\":\"$DAO_PUBKEY\",\"name\":\"$DAO_NAME\"}"
$TONOS_CLI -u $NETWORK call $DAO_CREATOR_ADDR $CALLED --abi $DAO_CREATOR_ABI --sign $DAO_CREATOR_KEYS > /dev/null || exit 1
DAO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$DAO_NAME\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
cp $WALLET_KEYS $DAO_KEYS
./giver.sh $DAO_ADDR $ONE_K_EVERS

sleep 5

echo ===================== DAO =====================
echo "  Gosh root:" $GOSH_ADDR
echo DAO creator: $DAO_CREATOR_ADDR
echo "DAO ($(account_data $NETWORK $DAO_ADDR))"
echo "       name:" $DAO_NAME
echo "    address:" $DAO_ADDR
echo "       keys:" $(cat $DAO_KEYS)
