use dojo_arena::models::Arena::Position;

const HP_MULTIPLIER: u32 = 10;
const BASE_HP: u32 = 90;

const ENERGY_MULTIPLIER: u32 = 3;
const BASE_ENERGY: u32 = 20;

// const NUMBER_OF_PLAYERS: u32 = 4;

const COUNTER_ID: u32 = 99999999;

const FIRST_POS: u32 = 6;
const SECOND_POS: u32 = 9;
const RANGE_POS: u32 = 15;
const MAX_TURNS: u32 = 25;

const AGI_INITIATIVE_MODIFIER: u32 = 25;
// Base_Quick_Atack_Initiative
const QUICK_ATC_INI: u32 = 10;
// Base_Precise_Atack_Initiative
const PRECISE_ATC_INI: u32 = 15;
// Base_Heavy_Atack_Initiative
const HEAVY_ATC_INI: u32 = 20;
// Base Move Initiative
const MOVE_INI: u32 = 8;
const REST_INI: u32 = 8;

const QUICK_ATC_ENERGY: u32 = 2;
const PRECISE_ATC_ENERGY: u32 = 4;
const HEAVY_ATC_ENERGY: u32 = 6;

const QUICK_ATC_DAMAGE: u32 = 5;
const PRECISE_ATC_DAMAGE: u32 = 10;
const HEAVY_ATC_DAMAGE: u32 = 20;

const QUICK_HIT_CHANCE: u128 = 80;
const PRECISE_HIT_CHANCE: u128 = 60;
const HEAVY_HIT_CHANCE: u128 = 35;

const REST_RECOVERY: u32 = 5;

const MAX_LEVEL: u32 = 9;
const MAX_STRENGTH: u32 = 9;
const MAX_AGILITY: u32 = 9;
const MAX_VITALITY: u32 = 9;
const MAX_STAMINA: u32 = 9;

const GRID_WIDTH: u32 = 7;
const GRID_HEIGHT: u32 = 4;

// left side
const RED: felt252 = "red";
// right side
const BLUE: felt252 = "blue";

const FIRST_POS = Position { x: 0, y: 1 };
const SECOND_POS = Position { x: 0, y: 3 };
const THIRD_POS = Position { x: 0, y: 5 };
const FOURTH_POS = Position { x: 3, y: 1 };
const FIFTH_POS = Position { x: 3, y: 3 };
const SIXTH_POS = Position { x: 3, y: 5 };