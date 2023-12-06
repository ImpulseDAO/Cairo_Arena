# Cairo_Arena
EthGlobal Istanbul submission 

## Prepare

### Install Scarb

```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

### Install dojo-up

```baseh
curl -L https://install.dojoengine.org | bash
```

### Intall dojo engines

```bash
dojoup -v 0.3.10
```

## Player create their own Strategies and Declare class

### Create account

- Create keytstore from a private key

```bash
starkli signer keystore from-key ~/.starkli-wallets/deployer/account0_keystore.json
```

- Retrive the class hash of your account

```bash
starkli class-hash-at <SMART_WALLET_ADDRESS> --rpc http://0.0.0.0:5050
```

- Create Account Descriptor

```bash
touch ~/.starkli-wallets/deployer/account0_account.json
```

```json
{
  "version": 1,
  "variant": {
        "type": "open_zeppelin",
        "version": 1,
        "public_key": "<SMART_WALLET_PUBLIC_KEY>"
  },
    "deployment": {
        "status": "deployed",
        "class_hash": "<SMART_WALLET_CLASS_HASH>",
        "address": "<SMART_WALLET_ADDRESS>"
  }
}
```

### An example strategy contract can refer to

```bash
cd ./examples/focus_on_offence
```

### Compile the strategy contract

```bash
scarb build
```

### Declare the class after Strategy contract compiled

```bash
starkli declare target/dev/focus_on_offence_Strategy.contract_class.json --rpc http://0.0.0.0:5050 --account ~/.starkli-wallets/deployer/account0_account.json --keystore ~/.starkli-wallets/deployer/account0_keystore

Class hash declared:
0x0057dfdc7b7f813288e54f6a2ea0d2077f7c54a643620ef2b8074a58589c959d
```

### Set Strategy Hash

```bash
export STRATEGY_HASH=0x0057dfdc7b7f813288e54f6a2ea0d2077f7c54a643620ef2b8074a58589c959d
```

## Testing with Katana

### Run Katana

```bash
katana --disable-fee
```

### Build

```bash
sozo build
```

### Deploy

```bash
sozo migrate --name test

# Executor
  > Contract address: 0x59f31686991d7cac25a7d4844225b9647c89e3e1e2d03460dbc61e3fbfafc59
# Base Contract
  > Class Hash: 0x5a2c567ed06c8059c8d1199684796a0a0ef614f9a2ab628700e804524816b5c
# World
  > Contract address: 0x13dfc87155d415ae384a35ba4333dfe160645ad7c83dc8b5812bd7ade9d69d6
# Models (5)
Arena
  > Class hash: 0x1d0a8d953789685e89eaf0122aee0335ab197357a97460eff6344c979921384
ArenaCharacter
  > Class hash: 0x438fa799db979acfed33a995018b5deb94f82d78b24fb6cbe6d4a0d47d89186
ArenaRegistered
  > Class hash: 0x7d30be85d8a9ab1b461c1fca67f4674a70196101006e4eb0c40fb99fa8b5c63
CharacterInfo
  > Class hash: 0x301643c1de8fc19b97b5329e51ac23e515e22cb385232ff480fd1e91cb08280
Counter
  > Class hash: 0x3a2eed18b648b121845a31197ec8c2e406acaedba312a912e6209f8b1333df5
  > Registered at: 0x7ec59e22e5f2da6831d6f6433aa69f7e1482b17e2b93dfce2fbe1f80f14b01e
# Contracts (1)
actions
  > Contract address: 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035

🎉 Successfully migrated World at address 0x13dfc87155d415ae384a35ba4333dfe160645ad7c83dc8b5812bd7ade9d69d6
```

### Authorization

```bash
./scripts/default_auth.sh
```

### Set Actions Address

```bash
export ACTIONS_ADDRESS=0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035
```

### Set World Address

```bash
export WORLD_ADDRESS=0x13dfc87155d415ae384a35ba4333dfe160645ad7c83dc8b5812bd7ade9d69d6
```

### Set Player1

```bash
export PLAYER1_ACCOUNT_ADDRESS=0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973
export PLAYER1_PRIVATE_KEY=0x1800000000300000180000000000030000000000003006001800006600
```

### Set Player2

```bash
export PLAYER2_ACCOUNT_ADDRESS=0x5686a647a9cdd63ade617e0baf3b364856b813b508f03903eb58a7e622d5855
export PLAYER2_PRIVATE_KEY=0x33003003001800009900180300d206308b0070db00121318d17b5e6262150b
```

### Create Character with two players

```bash
sozo execute -c 0x617374656e,1,1,2,1,$STRATEGY_HASH $ACTIONS_ADDRESS createCharacter --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY

sozo execute -c 0x6b756265,2,1,1,1,$STRATEGY_HASH $ACTIONS_ADDRESS createCharacter --rpc-url http://localhost:5050 --account-address $PLAYER2_ACCOUNT_ADDRESS --private-key $PLAYER2_PRIVATE_KEY
```

### Create Arena

```bash
sozo execute -c 0x6172656e61,0 $ACTIONS_ADDRESS createArena  --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```

### Register Character

```bash
sozo execute -c 1 $ACTIONS_ADDRESS register --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY

sozo execute -c 1 $ACTIONS_ADDRESS register --rpc-url http://localhost:5050 --account-address $PLAYER2_ACCOUNT_ADDRESS --private-key $PLAYER2_PRIVATE_KEY
```

### Play Arena

```bash
sozo execute -c 1 $ACTIONS_ADDRESS play --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```

### Verifi winner

```bash
sozo model get Arena 1 --world $WORLD_ADDRESS --rpc-url http://localhost:5050
```

### Leveling up

```bash
sozo execute $ACTIONS_ADDRESS level_up --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```

### Assign points

```bash
sozo execute -c 0,0,0,1 $ACTIONS_ADDRESS assign_points --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```

### Update Strategy

```bash
sozo execute -c $STRATEGY_HASH $ACTIONS_ADDRESS update_strategy --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```

### Close Arena And Distribute Rewards

```bash
sozo execute -c 1 $ACTIONS_ADDRESS closeArena --rpc-url http://localhost:5050 --account-address $PLAYER1_ACCOUNT_ADDRESS  --private-key $PLAYER1_PRIVATE_KEY
```