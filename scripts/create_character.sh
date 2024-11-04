#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

export WORLD_ADDRESS=$(cat ./manifest_dev.json | jq -r '.world.address')
export ACTIONS_ADDRESS=$(cat ./manifest_dev.json | jq -r '.contracts[] | select(.tag == "arena-actions").address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS
echo " "
echo action system : $ACTIONS_ADDRESS
echo "---------------------------------------------------------------------------"

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6331,1,1,2,1,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x23ab45933374a72027c7abcf8119353142cf8846f65b0c99e45426766d04de4 \
	--private-key 0x587692064670966047507699fbfbebb04e93531ca6d8a503519385fe0d2a3e7

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6332,1,2,1,1,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x51f6b9c9b9bf3bceda278fd0e0c1e159cc7cc3bc98892b25a8621c10d854523 \
	--private-key 0x1a46735c4a0747ccd1996998b796bc4407843bffe856f99b4a2f52a954ef287

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6333,2,1,1,1,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x51bc72c6efd31eca83093e271450173017c805d6f2359f3a4bef42d13690325 \
	--private-key 0x3cd22febab9ad143e65dcb2b9a05e43b9183ccb5bf7f29c17a52a692efd9b24

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6334,1,1,1,2,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x3474ec5ceda2839aebbf7041a4041398b1145d8c264cfc9ea8ef8c4a262277a \
	--private-key 0x1b701070106e37b85340feea1a98d8e629e06efde7915e7887449aa3d1e1e1

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6335,1,2,1,1,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x4f05eae7453f0b9cb4eb36317d146a1603cafc7ad4ea2f04f5d0273e5b34762 \
	--private-key 0x70729ed5f3cdd2cb9d33677b98eb7a6ee418f0447545b2bd2365c49b0018f50

sozo execute --world $WORLD_ADDRESS $ACTIONS_ADDRESS createCharacter -c 0x6336,1,1,2,1,0x53673358efd0bed498c39f6726ccbac76281093a653c2522500d7d0481d7085 --wait --rpc-url $STARKNET_RPC_URL \
	--account-address 0x30dd6c373a48d71c53b9456842eccd8b5fde5c92bc04b927f2728181e8513ca \
	--private-key 0x4d8ce8874e6fb96a2b0b98bb4e3c8e7ef6b61070976a3839ff4a3ba9d6868e

