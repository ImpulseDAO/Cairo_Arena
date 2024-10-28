: "${STARKNET_RPC_URL:?Environment variable STARKNET_RPC_URL must be set}"

echo "---------------------------------------------------------------------------"
echo RPC URL : $STARKNET_RPC_URL
echo "---------------------------------------------------------------------------"


sncast -u $STARKNET_RPC_URL \
    account add --name world-owner \
    --address 0x5e14af9ed55fdd518e8bacf30a89e12c8450f9b6dd387f6bb6aff7903a7d40d \
    --public-key 0x5e14af9ed55fdd518e8bacf30a89e12c8450f9b6dd387f6bb6aff7903a7d40d \
    --private-key 0x1d105d613aae948c2da77aebb2c346ccb02c8d9c4a3e31d5e9c504dda9f2924 \
    --type oz --add-profile worldowner