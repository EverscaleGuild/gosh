#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX
set -e

if [ -z $TONOS_CLI ]; then
    TONOS_CLI=tonos-cli
fi
if [ -z $NETWORK ]; then
    NETWORK=localhost
fi
if [ -e $1.keys.json ]; then
    KEYOPT=setkey
fi
CTOR_PARAMS=$2
TWO_EVERS=2000000000
BALANCE=${3:-$TWO_EVERS}

echo "[$0] genaddr..."
CONTRACT_ADDRESS=$($TONOS_CLI genaddr $1.tvc --abi $1.abi.json --${KEYOPT:-genkey} $1.keys.json | grep "Raw address:" | cut -d ' ' -f 3)
echo ADDR=$CONTRACT_ADDRESS

echo "[$0] request giver..."
./giver.sh $CONTRACT_ADDRESS $BALANCE

echo "[$0] deploy $1"
$TONOS_CLI --url $NETWORK deploy $1.tvc $CTOR_PARAMS --sign $1.keys.json --abi $1.abi.json > /dev/null

echo -n $CONTRACT_ADDRESS > $1.addr
