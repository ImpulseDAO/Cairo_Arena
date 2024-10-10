use starknet::ContractAddress;
use starknet::ClassHash;
use dojo_arena::models::Character::{CharacterAttributes};


#[derive(Serde, Copy, Drop, Introspect)]
enum Direction {
    Right,
    Left,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum BattleAction {
    QuickAttack,
    PreciseAttack,
    HeavyAttack,
    Move
    Rest,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum SetTier {
    Tier5,
    Tier4,
    Tier3,
    Tier2,
    Tier1,
}


#[derive(Drop, Serde)]
#[dojo::model]
struct ArenaCounter {
    #[key]
    counter: u32,
    arena_count: u32,
}

#[derive(Drop, Serde)]
#[dojo::model]
struct Arena {
    #[key]
    id: u32,
    player: ContractAddress,
    name: felt252,
    current_tier: SetTier,
    characters_number: u8,
    winner: felt252,
    is_closed: bool,
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Position {
    x: u8,
    y: u8
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum Direction {
    Up,
    Down,
    Right,
    Left,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum Side {
    Red,
    Blue,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct ArenaCharacter {
    #[key]
    arena_id: u32,
    #[key]
    cid: u8,
    name: felt252,
    level: u8,
    hp: u32,
    energy: u32,
    attributes: CharacterAttributes,
    character_owner: ContractAddress,
    strategy: ClassHash,
    position: Position,
    direction: Direction,
    action: BattleAction,
    initiative: u8,
    consecutive_rest_count: u8,
    side: Side,
}

#[derive(Drop, Serde)]
#[dojo::model]
struct ArenaRegistered {
    #[key]
    arena_id: u32,
    #[key]
    character_owner: ContractAddress,
    registered: bool,
}
