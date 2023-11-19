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
```

### Authorization

```bash
./scripts/default_auth.sh
```

### Create Character with two players

```bash
sozo execute -c 0x617374656e,1,1,2,1,0x0057dfdc7b7f813288e54f6a2ea0d2077f7c54a643620ef2b8074a58589c959d 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 createCharacter --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600

sozo execute -c 0x6b756265,2,1,1,1,0x0057dfdc7b7f813288e54f6a2ea0d2077f7c54a643620ef2b8074a58589c959d 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 createCharacter --rpc-url http://localhost:5050 --account-address 0x5686a647a9cdd63ade617e0baf3b364856b813b508f03903eb58a7e622d5855 --private-key 0x33003003001800009900180300d206308b0070db00121318d17b5e6262150b
```

### Create Arena

```bash
sozo execute -c 0x6172656e61,0 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 createArena  --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```

### Register Character

```bash
sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 register --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600

sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 register --rpc-url http://localhost:5050 --account-address 0x5686a647a9cdd63ade617e0baf3b364856b813b508f03903eb58a7e622d5855 --private-key 0x33003003001800009900180300d206308b0070db00121318d17b5e6262150b
```

### Play Arena

```bash
sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 play --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```

### Verifi winner

```bash
sozo model get Arena 1 --world 0x13dfc87155d415ae384a35ba4333dfe160645ad7c83dc8b5812bd7ade9d69d6 --rpc-url http://localhost:5050
```

### Leveling up

```bash
sozo execute 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 level_up --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```

### Assign points

```bash
sozo execute -c 0,0,0,1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 assign_points --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```

### Update Strategy

```bash
sozo execute -c 0x0057dfdc7b7f813288e54f6a2ea0d2077f7c54a643620ef2b8074a58589c959d 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 update_strategy --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```

### Close Arena And Distribute Rewards

```bash
sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 closeArena --rpc-url http://localhost:5050 --account-address 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973  --private-key 0x1800000000300000180000000000030000000000003006001800006600
```