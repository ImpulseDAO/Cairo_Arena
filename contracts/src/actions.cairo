use starknet::{ContractAddress, ClassHash};

use dojo_arena::models::io::{
    InitialAttributes, CharacterAttributes, SetTier, CharacterState, BattleAction
};
use dojo_arena::models::{ArenaCharacter};


const HP_MULTIPLIER: u8 = 10;
const BASE_HP: u8 = 90;

const ENERGY_MULTIPLIER: u8 = 3;
const BASE_ENERGY: u8 = 20;

// const NUMBER_OF_PLAYERS: u32 = 4;

const COUNTER_ID: u32 = 99999999;

const FIRST_POS: u8 = 6;
const SECOND_POS: u8 = 9;
const RANGE_POS: u8 = 15;
const MAX_TURNS: u8 = 25;

const AGI_INITIATIVE_MODIFIER: u8 = 25;
// Base_Quick_Atack_Initiative
const QUICK_ATC_INI: u8 = 10;
// Base_Precise_Atack_Initiative
const PRECISE_ATC_INI: u8 = 15;
// Base_Heavy_Atack_Initiative
const HEAVY_ATC_INI: u8 = 20;
// Base Move Initiative
const MOVE_INI: u8 = 8;
const REST_INI: u8 = 8;

const QUICK_ATC_ENERGY: u8 = 2;
const PRECISE_ATC_ENERGY: u8 = 4;
const HEAVY_ATC_ENERGY: u8 = 6;

const QUICK_ATC_DAMAGE: u8 = 5;
const PRECISE_ATC_DAMAGE: u8 = 10;
const HEAVY_ATC_DAMAGE: u8 = 20;

const QUICK_HIT_CHANCE: u128 = 80;
const PRECISE_HIT_CHANCE: u128 = 60;
const HEAVY_HIT_CHANCE: u128 = 35;

const REST_RECOVERY: u8 = 5;

#[starknet::interface]
trait IActions<TContractState> {
    fn createCharacter(
        self: @TContractState, name: felt252, attributes: InitialAttributes, strategy: ClassHash
    );
    fn createArena(self: @TContractState, name: felt252, current_tier: SetTier);
    fn register(self: @TContractState, arena_id: u32);
    fn play(self: @TContractState, arena_id: u32);
    fn battle(self: @TContractState, c1: ArenaCharacter, c2: ArenaCharacter) -> ArenaCharacter;
}
