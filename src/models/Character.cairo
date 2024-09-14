use starknet::ContractAddress;
use starknet::ClassHash;

#[derive(Serde, Copy, Drop, Introspect)]
struct InitialAttributes {
    strength: u32,
    agility: u32,
    vitality: u32,
    stamina: u32,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterAttributes {
    strength: u32,
    agility: u32,
    vitality: u32,
    stamina: u32,
}

#[derive(Drop, Serde)]
#[dojo::model]
struct CharacterInfo {
    #[key]
    player: ContractAddress,
    name: felt252,
    attributes: CharacterAttributes,
    strategy: ClassHash,
    level: u32,
    experience: u32,
    points: u32,
    golds: u32,
}
