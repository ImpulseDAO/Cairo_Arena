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

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, my_state: CharacterState, opponent_state: CharacterState
    ) -> BattleAction;
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

    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

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
                strategy: character_info.strategy
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

        fn battle(self: @ContractState, c1: ArenaCharacter, c2: ArenaCharacter) -> ArenaCharacter {
            let mut c1_state = CharacterState {
                hp: c1.hp, position: FIRST_POS, energy: c1.energy, consecutive_rest_count: 0,
            };

            let mut c2_state = CharacterState {
                hp: c2.hp, position: SECOND_POS, energy: c2.energy, consecutive_rest_count: 0,
            };

            let mut c1_initiative: u8 = 0;
            let mut c2_initiative: u8 = 0;
            let mut turns: u8 = 0;

            let mut winner = c1.clone();
            loop {
                if turns >= 25 {
                    if c1_state.hp <= c2_state.hp {
                        winner = c2;
                        break;
                    }
                }
                turns += 1;

                let mut c1_action: BattleAction = IStrategyLibraryDispatcher {
                    class_hash: c1.strategy
                }
                    .determin_action(c1_state, c2_state);

                let mut c2_action: BattleAction = IStrategyLibraryDispatcher {
                    class_hash: c2.strategy
                }
                    .determin_action(c2_state, c1_state);

                // let mut c1_action: BattleAction = determin_action(c1_state, c2_state);
                // let mut c2_action: BattleAction = determin_action(c2_state, c1_state);

                if c1_action == BattleAction::Rest {
                    c1_state.consecutive_rest_count += 1;
                } else {
                    c1_state.consecutive_rest_count = 0;
                }

                if c2_action == BattleAction::Rest {
                    c2_state.consecutive_rest_count += 1;
                } else {
                    c2_state.consecutive_rest_count = 0;
                }

                c1_initiative = calculate_initiative(c1_action, c1.attributes.agility);
                c2_initiative = calculate_initiative(c2_action, c2.attributes.agility);

                let mut is_c1_first: bool = true;

                if c1_initiative > c2_initiative {
                    is_c1_first = false;
                } else if c1_initiative == c2_initiative {
                    if c1.attributes.agility < c2.attributes.agility {
                        is_c1_first = false;
                    }
                }

                if is_c1_first {
                    execute_action(c1_action, ref c1_state, ref c2_state, @c1, @c2);
                    if c2_state.hp == 0 {
                        break;
                    }
                    execute_action(c2_action, ref c2_state, ref c1_state, @c2, @c1);
                    if c1_state.hp == 0 {
                        winner = c2;
                        break;
                    }
                } else {
                    execute_action(c2_action, ref c2_state, ref c1_state, @c1, @c2);
                    if c1_state.hp == 0 {
                        winner = c2;
                        break;
                    }
                    execute_action(c1_action, ref c1_state, ref c2_state, @c2, @c1);
                    if c2_state.hp == 0 {
                        break;
                    }
                }
            };

            winner
        }
    }
}


#[cfg(test)]
mod tests {
    use starknet::class_hash::Felt252TryIntoClassHash;

    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    // import test utils
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // import models
    use dojo_arena::models::{character_info, counter, arena, arena_character};
    use dojo_arena::models::{CharacterInfo, Counter, Arena, ArenaCharacter};

    use dojo_arena::models::io::{InitialAttributes, SetTier};

    // import actions
    use super::{
        actions, IActionsDispatcher, IActionsDispatcherTrait, COUNTER_ID, HP_MULTIPLIER, BASE_HP,
        ENERGY_MULTIPLIER, BASE_ENERGY
    };

    use debug::PrintTrait;

    #[test]
    #[available_gas(3000000000000000)]
    fn test_create_character() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        let character = get!(world, player, (CharacterInfo));

        assert(character.name == 'asten', 'name is not correct');
        assert(character.attributes.strength == 2, 'strength is not correct');
        assert(character.attributes.agility == 2, 'agility is not correct');
        assert(character.attributes.vitality == 3, 'vitality is not correct');
        assert(character.attributes.stamina == 2, 'stamina is not correct');
    }

    #[test]
    #[should_panic]
    #[available_gas(3000000000000000)]
    fn test_create_character_wrong_init_attributes() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 2, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_create_arena() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.createArena('Sky Arena', SetTier::Tier3);

        let counter = get!(world, COUNTER_ID, (Counter));
        assert(counter.arena_count == 1, 'arena count is not correct');

        let arena = get!(world, counter.arena_count, (Arena));
        assert(arena.name == 'Sky Arena', 'name is not correct');
        assert(arena.owner == player, 'owner is not correct');
        assert(arena.current_tier == SetTier::Tier3, 'Tier is not correct');
        assert(arena.character_count == 0, 'Character count is not correct');
        assert(arena.winner == starknet::contract_address_const::<0>(), 'winner is not correct');
    }

    #[test]
    #[should_panic]
    fn test_register_arena_not_exists() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.register(1);
    }

    #[test]
    #[should_panic]
    fn test_register_character_not_exists() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.createArena('Sky Arena', SetTier::Tier3);

        actions_system.register(1);
    }

    #[test]
    #[should_panic]
    fn test_register_tier_not_match() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier3);

        actions_system.register(1);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_register() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        actions_system.register(1);

        let counter = get!(world, COUNTER_ID, (Counter));
        let arena = get!(world, counter.arena_count, (Arena));
        assert(arena.character_count == 1, 'Character count is not correct');

        let character = get!(world, (arena.id, arena.character_count), (ArenaCharacter));
        assert(character.name == 'asten', 'name is not correct');
        assert(character.attributes.strength == 2, 'strength is not correct');
        assert(character.attributes.agility == 2, 'agility is not correct');
        assert(character.attributes.vitality == 3, 'vitality is not correct');
        assert(character.attributes.stamina == 2, 'stamina is not correct');
        assert(character.character_owner == player, 'owner is not correct');
        assert(character.position == 0, 'position is not correct');

        let hp = 3 * HP_MULTIPLIER + BASE_HP;
        let energy = 2 * ENERGY_MULTIPLIER + BASE_ENERGY;
        assert(character.hp == hp, 'hp is not correct');
        assert(character.energy == energy, 'energy is not correct');
    }

    #[test]
    #[should_panic]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_ready() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let counter = get!(world, COUNTER_ID, (Counter));

        actions_system.register(counter.arena_count);

        actions_system.play(counter.arena_count);
    }

    #[test]
    #[should_panic]
    #[available_gas(3000000000000000)]
    fn test_play_player_already_registered() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'c1',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let counter = get!(world, COUNTER_ID, (Counter));

        actions_system.register(counter.arena_count);
        actions_system.register(counter.arena_count);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_play() {
        let player = starknet::contract_address_const::<0x0>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'c1',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let counter = get!(world, COUNTER_ID, (Counter));

        actions_system.register(counter.arena_count);
    // actions_system.register(counter.arena_count);

    // actions_system.play(counter.arena_count);
    }
}
