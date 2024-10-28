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