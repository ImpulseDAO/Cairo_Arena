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

## Build and Run locally

### Build

```bash
sozo build
```

### Run Katana

```bash
katana --disable-fee
```

### Deploy

```bash
sozo migrate --name test
```

### Invoke or Call contract

- Create a new Character name 'as'

```bash
sozo execute -c 0x6173,1,1,2,1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 createCharacter
```

- Create a new Arena name 'are' with tier5 

```bash
sozo execute -c 0x617265,0 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 createArena
```

- Register Character to Arena

```bash
sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 register
```

- Play Arena

```bash
sozo execute -c 1 0x47c92218dfdaac465ad724f028f0f075b1c05c9ff9555d0e426c025e45c035 play
```


## Playe create their own Strategies and Declare class

### An example contract can refer to

```bash
./examples/focus_on_offence
```

### Declare the class after Strategy contract compiled

```bash
starkli declare target/dev/foucs_on_offence_BattleActionLibrary.contract_class.json --rpc http://0.0.0.0:5050 --account ~/.starkli-wallets/deployer/account0_account.json --keystore ~/.starkli-wallets/deployer/account0_keystore
```