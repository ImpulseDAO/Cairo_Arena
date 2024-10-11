#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

export WORLD_ADDRESS=$(cat ./manifests/release/deployment/manifest.json | jq -r '.world.address')
export ACTIONS_ADDRESS=$(cat ./manifests/release/deployment/manifest.json | jq -r '.contracts[] | select(.tag == "Arena-actions" and .kind == "DojoContract").address')
export FIGHT_STSTEM_ADDRESS=$(cat ./manifests/release/deployment/manifest.json | jq -r '.contracts[] | select(.tag == "Arena-fight_system" and .kind == "DojoContract").address')


echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo " "
echo actions : $ACTIONS_ADDRESS
echo " "
echo FIGHT_STSTEM : $FIGHT_STSTEM_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> models authorizations
sozo auth grant --world $WORLD_ADDRESS --rpc-url $STARKNET_RPC_URL --wait writer \
  model:Arena-ArenaCounter,$ACTIONS_ADDRESS \
  model:Arena-Arena,$ACTIONS_ADDRESS \
  model:Arena-ArenaCharacter,$ACTIONS_ADDRESS \
  model:Arena-ArenaRegistered,$ACTIONS_ADDRESS \
  model:Arena-CharacterInfo,$ACTIONS_ADDRESS

sozo auth grant --world $WORLD_ADDRESS --rpc-url $STARKNET_RPC_URL --wait writer \
  model:Arena-ArenaCounter,$FIGHT_STSTEM_ADDRESS \
  model:Arena-Arena,$FIGHT_STSTEM_ADDRESS \
  model:Arena-ArenaCharacter,$FIGHT_STSTEM_ADDRESS \
  model:Arena-ArenaRegistered,$FIGHT_STSTEM_ADDRESS \
  model:Arena-CharacterInfo,$FIGHT_STSTEM_ADDRESS

echo "Default authorizations have been successfully set."