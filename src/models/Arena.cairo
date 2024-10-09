use starknet::ContractAddress;
use starknet::ClassHash;
use dojo_arena::models::Character::{CharacterAttributes};


#[derive(Serde, Copy, Drop, Introspect)]
enum Direction {
    Right,
    Left,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterState {
    hp: u32,
    position: u32,
    energy: u32,
    consecutive_rest_count: u32,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum BattleAction {
    QuickAttack,
    PreciseAttack,
    HeavyAttack,
    MoveRight,
    MoveLeft,
    MoveUp,
    MoveDown,
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
    winner: ContractAddress,
    total_golds: u32,
    total_rating: u32,
    is_closed: bool,
}

#[derive(Copy, Drop, Serde)]
#[dojo::model]
struct ArenaCharacter {
    #[key]
    arena_id: u32,
    #[key]
    character_count: u32,
    name: felt252,
    hp: u32,
    energy: u32,
    attributes: CharacterAttributes,
    character_owner: ContractAddress,
    strategy: ClassHash,
    rating: u32,
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
