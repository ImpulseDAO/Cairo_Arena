use starknet::ContractAddress;
use starknet::ClassHash;


#[derive(Serde, Copy, Drop)]
struct CharacterAttributes {
    strength: u8,
    agility: u8,
    vitality: u8,
    stamina: u8,
}

#[derive(Serde, Copy, Drop)]
enum Side {
    Red,
    Blue,
}

#[derive(Copy, Drop, Serde)]
struct Position {
    pub x: u8,
    pub y: u8
}


#[derive(Serde, Copy, Drop)]
pub enum BattleAction {
    QuickAttack,
    PreciseAttack,
    HeavyAttack,
    Move,
    Rest,
}

#[derive(Serde, Copy, Drop, PartialEq)]
pub enum Direction {
    Up,
    Down,
    Right,
    Left,
}

#[derive(Copy, Drop, Serde)]
pub struct ArenaCharacter {
    arena_id: u32,
    pub cid: u8,
    pub name: felt252,
    pub level: u8,
    pub hp: u32,
    pub energy: u32,
    pub attributes: CharacterAttributes,
    pub character_owner: ContractAddress,
    pub strategy: ClassHash,
    pub position: Position,
    pub direction: Direction,
    pub action: BattleAction,
    pub initiative: u8,
    pub consecutive_rest_count: u8,
    pub side: Side,
}
