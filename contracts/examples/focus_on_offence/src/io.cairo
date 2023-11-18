//*
//*************************    
//* BOILERPLATE CODE SECTION
//* DO NOT MODIFY THIS CODE 
//*************************
//

#[derive(Serde, Copy, Drop, Introspect)]
struct CharacterState {
    hp: u8,
    position: u8,
    energy: u8,
    consecutive_rest_count: u8,
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
