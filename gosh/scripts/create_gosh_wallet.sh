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

TONOS_CLI=tonos-cli
NETWORK=${2:-localhost}

CONTRACT=../goshdao
CONTRACT_ABI=$CONTRACT.abi.json
CONTRACT_KEYS=$CONTRACT.keys.json
GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_ADDR=$(cat $GOSH.addr)
CONTRACT_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)

if [ "$NETWORK" == "localhost" ]; then
    WALLET=wallets/localnode/SafeMultisigWallet
else
    WALLET=wallets/devnet/SafeMultisigWallet
fi

WALLET_ADDR=$(cat $WALLET.addr)
WALLET_ABI=$WALLET.abi.json
WALLET_KEYS=$WALLET.keys.json

DAO_PUBKEY=$(cat $WALLET_KEYS | sed -n '/public/ s/.*\([[:xdigit:]]\{64\}\).*/0x\1/p')
WALLET_OWNER_PUBKEY=$DAO_PUBKEY

SEVENTY_EVERS=30000000000

CALLED="deployWallet {\"pubkeyroot\":\"$DAO_PUBKEY\",\"pubkey\":\"$WALLET_OWNER_PUBKEY\"}"
$TONOS_CLI -u $NETWORK call $CONTRACT_ADDR $CALLED --abi $CONTRACT_ABI > /dev/null || exit 1
WALLET_ADDR=$($TONOS_CLI -j -u $NETWORK run $CONTRACT_ADDR getAddrWallet "{\"pubkeyroot\":\"$DAO_PUBKEY\",\"pubkey\":\"$WALLET_OWNER_PUBKEY\"}" --abi $CONTRACT_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
./giver.sh $WALLET_ADDR $SEVENTY_EVERS

echo ===================== DAO =====================
echo Gosh root: $GOSH_ADDR
echo " DAO name:" $1
echo " DAO addr:" $CONTRACT_ADDR
echo "   wallet:" $WALLET_ADDR
