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

// dojo decorator
#[dojo::contract]
mod actions {
    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};
    use dojo_arena::models::{CharacterInfo, Arena, Counter, ArenaCharacter, ArenaRegistered};
    use dojo_arena::models::io::{
        InitialAttributes, CharacterAttributes, SetTier, BattleAction, CharacterState, Direction
    };
    use dojo_arena::utils::{
        determin_action, new_pos_and_hit, new_pos_and_steps, calculate_initiative, execute_action
    };
    use super::{
        IActions, HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY, COUNTER_ID, FIRST_POS,
        SECOND_POS, RANGE_POS, MAX_TURNS, QUICK_ATC_ENERGY, PRECISE_ATC_ENERGY, HEAVY_ATC_ENERGY,
        QUICK_ATC_DAMAGE, PRECISE_ATC_DAMAGE, HEAVY_ATC_DAMAGE, AGI_INITIATIVE_MODIFIER,
        QUICK_ATC_INI, PRECISE_ATC_INI, HEAVY_ATC_INI, MOVE_INI, REST_INI, QUICK_HIT_CHANCE,
        PRECISE_HIT_CHANCE, HEAVY_HIT_CHANCE, REST_RECOVERY
    };

    use debug::PrintTrait;

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn createCharacter(
            self: @ContractState, name: felt252, attributes: InitialAttributes, strategy: ClassHash
        ) {
            let world = self.world_dispatcher.read();

            assert(
                attributes.strength
                    + attributes.agility
                    + attributes.vitality
                    + attributes.stamina == 5,
                'Attributes must sum 5'
            );

            let attributes = CharacterAttributes {
                strength: 1 + attributes.strength,
                agility: 1 + attributes.agility,
                vitality: 1 + attributes.vitality,
                stamina: 1 + attributes.stamina,
                level: 0,
                experience: 0,
            };

            let owner = get_caller_address();

            set!(world, (CharacterInfo { owner, name, attributes, strategy },));
        }

        fn createArena(self: @ContractState, name: felt252, current_tier: SetTier) {
            let world = self.world_dispatcher.read();
            let owner = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            counter.arena_count += 1;

            let arena = Arena {
                id: counter.arena_count,
                owner,
                name,
                current_tier,
                character_count: 0,
                winner: contract_address_const::<0>(),
            };

            set!(world, (arena, counter));
        }

        fn register(self: @ContractState, arena_id: u32) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, (Arena));
            arena.character_count += 1;

            let character_info = get!(world, player, CharacterInfo);
            assert(character_info.name != '', 'Character does not exist');

            let mut registered = get!(world, (arena_id, player), ArenaRegistered);
            assert(!registered.registered, 'Character already registered');
            registered.registered = true;

            let (min, max) = match arena.current_tier {
                SetTier::Tier5 => (0, 0),
                SetTier::Tier4 => (1, 1),
                SetTier::Tier3 => (2, 4),
                SetTier::Tier2 => (5, 8),
                SetTier::Tier1 => (8, 255),
            };
            assert(
                character_info.attributes.level >= min && character_info.attributes.level <= max,
                'Character tier is not allowed'
            );

            let hp = character_info.attributes.vitality * HP_MULTIPLIER + BASE_HP;
            let energy = character_info.attributes.stamina * ENERGY_MULTIPLIER + BASE_ENERGY;

            let character = ArenaCharacter {
                arena_id: arena.id,
                character_count: arena.character_count,
                name: character_info.name,
                hp,
                energy,
                position: 0,
                attributes: character_info.attributes,
                character_owner: player,
            };

            set!(world, (arena, character, registered));
        }

        fn play(self: @ContractState, arena_id: u32) {
            let world = self.world_dispatcher.read();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, Arena);
            assert(
                arena.character_count > 0 && arena.character_count % 2 == 0, 'Arena is not ready'
            );

            let mut characters = ArrayTrait::new();
            let mut i: usize = 0;
            loop {
                i += 1;
                if i > arena.character_count {
                    break;
                }
                let c = get!(world, (arena_id, i), ArenaCharacter);
                characters.append(c);
            };

            let mut character_count = arena.character_count;
            loop {
                i = 0;
                let mut winner_count = 0;
                loop {
                    i += 1;
                    if i > character_count / 2 {
                        break;
                    }
                    let c1 = characters.pop_front().unwrap();
                    let c2 = characters.pop_front().unwrap();
                    let winner = self.battle(c1, c2);
                    characters.append(winner);
                    winner_count += 1;
                };
                if winner_count == 1 {
                    break;
                }
                character_count = winner_count;
            };

            let winner = characters.pop_front().unwrap();

            arena.winner = winner.character_owner;
            set!(world, (arena));
        }
    }
}

