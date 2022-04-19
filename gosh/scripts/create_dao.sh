#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

if [ -z $1 ]; then
    echo "Usage: $0 DAO_NAME <NETWORK>"
    exit
fi

CONTRACT=../daocreater
CONTRACT_ABI=$CONTRACT.abi.json
CONTRACT_KEYS=$CONTRACT.keys.json
CONTRACT_ADDR=$(cat $CONTRACT.addr)

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

THIRTY_EVERS=30000000000

CALLED="deployDao {\"root_pubkey\":\"$DAO_PUBKEY\",\"name\":\"$1\"}"
$TONOS_CLI -u $NETWORK call $CONTRACT_ADDR $CALLED --abi $CONTRACT_ABI --sign $CONTRACT_KEYS > /dev/null || exit 1
DAO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
cp $WALLET_KEYS $DAO_KEYS
./giver.sh $DAO_ADDR $THIRTY_EVERS

echo ===================== DAO =====================
echo Gosh root: $GOSH_ADDR
echo  DAO name: $1
echo  DAO addr: $DAO_ADDR
echo  DAO keys: $(cat $DAO_KEYS)
