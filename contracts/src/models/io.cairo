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
    strength: u8,
    agility: u8,
    vitality: u8,
    stamina: u8,
}

#[derive(Serde, Copy, Drop, Introspect)]
struct InitialAttributes {
    strength: u8,
    agility: u8,
    vitality: u8,
    stamina: u8,
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
    hp: u8,
    position: u8,
    energy: u8,
    consecutive_rest_count: u8,
}

#[derive(Serde, Copy, Drop, Introspect)]
enum Direction {
    Right,
    Left,
}
