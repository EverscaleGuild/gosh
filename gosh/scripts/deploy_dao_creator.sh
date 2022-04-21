#!/bin/bash
#	This file is part of Ever OS.
#	
#	Ever OS is free software: you can redistribute it and/or modify 
#	it under the terms of the Apache License 2.0 (http://www.apache.org/licenses/)
#	
#	Copyright 2019-2022 (c) EverX

source utils.sh

fn=../daocreater
fn_src=$fn.sol
fn_abi=$fn.abi.json
fn_code=$fn.tvc
fn_keys=$fn.keys.json
GOSH=../gosh

# while getopts "fh" opt; do
#   case $opt in
#     f)
#     if [ -f $fn_keys ]; then rm $fn_keys; fi
#     shift
#     ;;
#     h)
#     echo Usage: $0 -f NETWORK
#     echo
#     echo "  -f (optional) - force to redeploy GOSH"
#     echo "  NETWORK (optional) - points to network endpoint:"
#     echo "      localhost - Evernode SE (default)"
#     echo "      net.ton.dev - devnet"
#     echo "      main.ton.dev - mainnet"
#     echo
#     exit 0
#     ;;
#   esac
# done

export TVM_LINKER=tvm_linker
export TONOS_CLI=tonos-cli
export NETWORK=${1:-localhost}

echo "[deploy $fn]"

WALLET_CODE=$($TVM_LINKER decode --tvc ../goshwallet.tvc | sed -n '/code:/ s/ code: // p')
WALLET_DATA=$($TVM_LINKER decode --tvc ../goshwallet.tvc | sed -n '/data:/ s/ data: // p')

DAO_CODE=$($TVM_LINKER decode --tvc ../goshdao.tvc | sed -n '/code:/ s/ code: // p')
DAO_DATA=$($TVM_LINKER decode --tvc ../goshdao.tvc | sed -n '/data:/ s/ data: // p')

GOSH_ADDR=$(cat $GOSH.addr)

CTOR_PARAMS="{\"gosh\":\"$GOSH_ADDR\",\"WalletCode\":\"$WALLET_CODE\",\"WalletData\":\"$WALLET_DATA\",\"codeDao\":\"$DAO_CODE\",\"dataDao\":\"$DAO_DATA\"}"
./deploy_contract.sh $fn $CTOR_PARAMS 100000000000 || exit 1
DAO_CREATOR_ADDR=$(cat $fn.addr)

echo ===================== DAO CREATOR =====================
echo Gosh: $GOSH_ADDR
echo DAO creator
echo address: $DAO_CREATOR_ADDR
echo "   keys:" $(cat $fn_keys)
echo balance: $(account_balance $NETWORK $DAO_CREATOR_ADDR)