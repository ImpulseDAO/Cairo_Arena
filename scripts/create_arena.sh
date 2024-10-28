#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

export WORLD_ADDRESS=$(cat ./manifests/dev/deployment/manifest.json | jq -r '.world.address')
export ACTIONS_ADDRESS=$(cat ./manifests/dev/deployment/manifest.json | jq -r '.contracts[] | select(.tag == "Arena-actions" and .kind == "DojoContract").address')
export FIGHT_STSTEM_ADDRESS=$(cat ./manifests/dev/deployment/manifest.json | jq -r '.contracts[] | select(.tag == "Arena-fight_system" and .kind == "DojoContract").address')


echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo " "
echo actions : $ACTIONS_ADDRESS
echo " "
echo FIGHT_STSTEM : $FIGHT_STSTEM_ADDRESS
echo "---------------------------------------------------------------------------"

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createArena -c 0x746573745f6c6f626279 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x23ab45933374a72027c7abcf8119353142cf8846f65b0c99e45426766d04de4 \
	--private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7
