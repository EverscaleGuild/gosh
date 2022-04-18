#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

if [ -z $1 ]; then
    echo "Usage: $0 REPO_NAME <NETWORK>"
    exit
fi

GOSH=../gosh
GOSH_ABI=$GOSH.abi.json
GOSH_KEYS=$GOSH.keys.json
GOSH_ADDR=$(cat $GOSH.addr)

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

OWNER_PUBKEY=$(cat $WALLET_KEYS | sed -n '/public/ s/.*\([[:xdigit:]]\{64\}\).*/0x\1/p')
PAYLOAD=$($TONOS_CLI body --abi $GOSH_ABI deployRepository "{\"pubkey\":\"$OWNER_PUBKEY\",\"name\":\"$1\"}" \
          | sed -n '/Message body:/ s/Message body: // p')

THREE_EVERS=3000000000
THIRTY_EVERS=30000000000
VALUE=$THREE_EVERS

CALLED="submitTransaction {\"dest\":\"$GOSH_ADDR\",\"value\":$VALUE,\"bounce\":false,\"allBalance\":false,\"payload\":\"$PAYLOAD\"}"
$TONOS_CLI -u $NETWORK call $WALLET_ADDR $CALLED --abi $WALLET_ABI --sign $WALLET_KEYS > /dev/null || exit 1
REPO_ADDR=$($TONOS_CLI -j -u $NETWORK run $GOSH_ADDR getAddrRepository "{\"pubkey\":\"$OWNER_PUBKEY\",\"name\":\"$1\"}" --abi $GOSH_ABI | sed -n '/value0/ p' | cut -d'"' -f 4)
./giver.sh $REPO_ADDR $THIRTY_EVERS

echo ===================== REPO =====================
echo name: $1
echo addr: $REPO_ADDR
