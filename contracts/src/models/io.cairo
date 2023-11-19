use starknet::ContractAddress;

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum SetTier {
    Tier5,
    Tier4,
    Tier3,
    Tier2,
    Tier1,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterAttributes {
    strength: u32,
    agility: u32,
    vitality: u32,
    stamina: u32,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct InitialAttributes {
    strength: u32,
    agility: u32,
    vitality: u32,
    stamina: u32,
}

#[derive(Serde, Copy, Drop, Introspect, PartialEq)]
enum BattleAction {
    QuickAttack,
    PreciseAttack,
    HeavyAttack,
    MoveRight,
    MoveLeft,
    Rest,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterState {
    hp: u32,
    position: u32,
    energy: u32,
    consecutive_rest_count: u32,
}

#[derive(Serde, Copy, Drop, Introspect)]
enum Direction {
    Right,
    Left,
}
