#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

export WORLD_ADDRESS=$(cat ./manifest_dev.json | jq -r '.world.address')
export ACTIONS_ADDRESS=$(cat ./manifest_dev.json | jq -r '.contracts[] | select(.tag == "arena-actions").address')
export FIGHT_STSTEM_ADDRESS=$(cat ./manifest_dev.json | jq -r '.contracts[] | select(.tag == "arena-fight_system").address')


echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo " "
echo actions : $ACTIONS_ADDRESS
echo " "
echo FIGHT_STSTEM : $FIGHT_STSTEM_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> models authorizations
# sozo auth grant --world $WORLD_ADDRESS --rpc-url $STARKNET_RPC_URL --wait writer \
#   model:arena-ArenaCounter,$ACTIONS_ADDRESS \
#   model:arena-Arena,$ACTIONS_ADDRESS \
#   model:arena-ArenaCharacter,$ACTIONS_ADDRESS \
#   model:arena-ArenaRegistered,$ACTIONS_ADDRESS \
#   model:arena-CharacterInfo,$ACTIONS_ADDRESS

# sozo auth grant --world $WORLD_ADDRESS --rpc-url $STARKNET_RPC_URL --wait writer \
#   model:arena-ArenaCounter,$FIGHT_STSTEM_ADDRESS \
#   model:arena-Arena,$FIGHT_STSTEM_ADDRESS \
#   model:arena-ArenaCharacter,$FIGHT_STSTEM_ADDRESS \
#   model:arena-ArenaRegistered,$FIGHT_STSTEM_ADDRESS \
#   model:arena-CharacterInfo,$FIGHT_STSTEM_ADDRESS

# echo "Default authorizations have been successfully set."