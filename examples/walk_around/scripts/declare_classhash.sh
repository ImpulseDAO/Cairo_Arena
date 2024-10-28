: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

echo "---------------------------------------------------------------------------"
echo RPC URL : $STARKNET_RPC_URL
echo "---------------------------------------------------------------------------"

sncast -u $STARKNET_RPC_URL \
    --account worldowner \
    declare -c Strategy