#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

echo "---------------------------------------------------------------------------"
echo RPC URL : $STARKNET_RPC_URL
echo "---------------------------------------------------------------------------"

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/1

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/2

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/3

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/4

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/5

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/6

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/7

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/8

starkli account deploy \
    --rpc $STARKNET_RPC_URL \
    --private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7 \
    ./scripts/accounts/9