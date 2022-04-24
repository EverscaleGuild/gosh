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

TONOS_CLI=tonos-cli
NETWORK=${2:-localhost}

GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_ADDR=$(cat $GOSH.addr)

DAO=../goshdao
DAO_ABI=$DAO.abi.json
DAO_KEYS=$DAO.keys.json
DAO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrDao "{\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)

WALLET=../goshwallet
WALLET_KEYS=$WALLET.keys.json
WALLET_SEED_PHRASE=$($TONOS_CLI -j genphrase | sed -n '/phrase/ p' | cut -d'"' -f 4)
$TONOS_CLI getkeypair $WALLET_KEYS "$WALLET_SEED_PHRASE" > /dev/null

DAO_PUBKEY=$(cat $DAO_KEYS | sed -n '/public/ s/.*\([[:xdigit:]]\{64\}\).*/0x\1/p')
WALLET_PUBKEY=$(cat $WALLET_KEYS | sed -n '/public/ s/.*\([[:xdigit:]]\{64\}\).*/0x\1/p')

NINETY_EVERS=90000000000

CALLED="deployWallet {\"pubkeyroot\":\"$DAO_PUBKEY\",\"pubkey\":\"$WALLET_PUBKEY\"}"
$TONOS_CLI -u $NETWORK call $DAO_ADDR $CALLED --abi $DAO_ABI > /dev/null || exit 1
WALLET_ADDR=$($TONOS_CLI -j -u $NETWORK run $DAO_ADDR getAddrWallet "{\"pubkeyroot\":\"$DAO_PUBKEY\",\"pubkey\":\"$WALLET_PUBKEY\"}" --abi $DAO_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
echo -n $WALLET_ADDR > $WALLET.addr
./giver.sh $WALLET_ADDR $NINETY_EVERS

echo ===================== GOSH WALLET =====================
echo "Gosh root:" $GOSH_ADDR
echo " DAO name:" $1
echo " DAO addr:" $DAO_ADDR
echo "wallet ($(account_data $NETWORK $WALLET_ADDR))"
echo "{"
echo "    \"address\": \"$WALLET_ADDR\","
echo "    \"keys\":" $(cat $WALLET_KEYS)
echo "}"
