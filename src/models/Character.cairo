use starknet::ContractAddress;
use starknet::ClassHash;

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterAttributes {
    strength: u8,
    agility: u8,
    vitality: u8,
    stamina: u8,
}

#[derive(Drop, Serde)]
#[dojo::model]
struct CharacterInfo {
    #[key]
    player: ContractAddress,
    name: felt252,
    attributes: CharacterAttributes,
    strategy: ClassHash,
    level: u8,
    experience: u32,
    points: u32,
    golds: u32,
}
