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
    character_count: u32,
    winner: felt252,
    is_closed: bool,
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Position {
    x: usize,
    y: usize
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum Direction {
    None,
    Up,
    Down,
    Right,
    Left,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct ArenaCharacter {
    #[key]
    arena_id: u32,
    #[key]
    character_count: u32,
    name: felt252,
    level: u32,
    hp: u32,
    energy: u32,
    attributes: CharacterAttributes,
    character_owner: ContractAddress,
    strategy: ClassHash,
    position: Position,
    direction: Direction,
    action: BattleAction,
    initiative: u32,
    consecutive_rest_count: u32,
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
