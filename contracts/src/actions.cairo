use starknet::{ContractAddress, ClassHash};

use dojo_arena::models::io::{
    InitialAttributes, CharacterAttributes, SetTier, CharacterState, BattleAction
};
use dojo_arena::models::{ArenaCharacter};


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

#[starknet::interface]
trait IActions<TContractState> {
    fn createCharacter(
        ref self: TContractState, name: felt252, attributes: InitialAttributes, strategy: ClassHash
    );
    fn createArena(ref self: TContractState, name: felt252, current_tier: SetTier);
    fn closeArena(ref self: TContractState, arena_id: u32);
    fn register(ref self: TContractState, arena_id: u32);
    fn play(ref self: TContractState, arena_id: u32);
    fn level_up(ref self: TContractState);
    fn assign_points(
        ref self: TContractState, strength: u32, agility: u32, vitality: u32, stamina: u32
    );
    fn update_strategy(ref self: TContractState, strategy: ClassHash);
    fn battle(
        ref self: TContractState, c1: ArenaCharacter, c2: ArenaCharacter
    ) -> (ArenaCharacter, Span<Span<u32>>);
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
        new_pos_and_hit, new_pos_and_steps, calculate_initiative, execute_action, get_gain_xp,
        get_level_xp, mirror_ation_to_int
    };
    use super::{
        IActions, HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY, COUNTER_ID, FIRST_POS,
        SECOND_POS, RANGE_POS, MAX_TURNS, QUICK_ATC_ENERGY, PRECISE_ATC_ENERGY, HEAVY_ATC_ENERGY,
        QUICK_ATC_DAMAGE, PRECISE_ATC_DAMAGE, HEAVY_ATC_DAMAGE, AGI_INITIATIVE_MODIFIER,
        QUICK_ATC_INI, PRECISE_ATC_INI, HEAVY_ATC_INI, MOVE_INI, REST_INI, QUICK_HIT_CHANCE,
        PRECISE_HIT_CHANCE, HEAVY_HIT_CHANCE, REST_RECOVERY, MAX_LEVEL, MAX_STRENGTH, MAX_AGILITY,
        MAX_VITALITY, MAX_STAMINA
    };

    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

    use debug::PrintTrait;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BattleLog: BattleLog,
    }

    #[derive(Drop, starknet::Event)]
    struct BattleLog {
        #[key]
        arena_id: u32,
        logs: Span<Span<u32>>,
    }

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn createCharacter(
            ref self: ContractState,
            name: felt252,
            attributes: InitialAttributes,
            strategy: ClassHash
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
            };

            let owner = get_caller_address();

            set!(
                world,
                (
                    CharacterInfo {
                        owner,
                        name,
                        attributes,
                        strategy,
                        level: 0,
                        experience: 0,
                        points: 0,
                        golds: 0,
                    },
                )
            );
        }

        fn createArena(ref self: ContractState, name: felt252, current_tier: SetTier) {
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
                total_golds: 5000,
                total_rating: 0,
                is_closed: false,
            };

            set!(world, (arena, counter));
        }

        fn closeArena(ref self: ContractState, arena_id: u32) {
            let world = self.world_dispatcher.read();
            let owner = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, Arena);
            assert(arena.owner == owner, 'Only owner can close arena');
            assert(!arena.is_closed, 'Arena is already closed');

            arena.is_closed = true;

            let mut character_count = arena.character_count;
            let mut i = 0;
            loop {
                i += 1;
                let mut character = get!(world, (arena_id, i), ArenaCharacter);
                let rewards = character.rating * arena.total_golds / arena.total_rating;

                let mut character_info = get!(world, character.character_owner, CharacterInfo);
                character_info.golds += rewards;
                set!(world, (character_info));

                if i == character_count {
                    break;
                }
            };

            set!(world, (arena));
        }

        fn register(ref self: ContractState, arena_id: u32) {
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
                character_info.level >= min && character_info.level <= max,
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
                strategy: character_info.strategy,
                rating: 0,
            };

            set!(world, (arena, character, registered));
        }

        fn play(ref self: ContractState, arena_id: u32) {
            let world = self.world_dispatcher.read();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, Arena);
            assert(!arena.is_closed, 'Arena is closed');
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
                    let (winner, logs) = self.battle(c1, c2);

                    emit!(world, BattleLog { arena_id: arena_id, logs: logs });

                    characters.append(winner);
                    winner_count += 1;
                };
                if winner_count == 1 {
                    break;
                }
                character_count = winner_count;
            };

            // winner is of ArenaCharacter
            let mut winner = characters.pop_front().unwrap();

            arena.winner = winner.character_owner;

            let mut character_info = get!(world, winner.character_owner, CharacterInfo);
            character_info.experience += get_gain_xp(character_info.level);

            winner.rating += get_gain_xp(character_info.level);
            arena.total_rating += get_gain_xp(character_info.level);
            set!(world, (arena, character_info, winner));
        }

        fn level_up(ref self: ContractState) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut character_info = get!(world, player, CharacterInfo);
            assert(character_info.level < MAX_LEVEL, 'Max level reached');

            let level_xp = get_level_xp(character_info.level);
            assert(character_info.experience >= level_xp, 'Not enough experience');

            character_info.experience -= level_xp;
            character_info.level += 1;
            character_info.points += 1;

            set!(world, (character_info));
        }

        fn assign_points(
            ref self: ContractState, strength: u32, agility: u32, vitality: u32, stamina: u32
        ) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut character_info = get!(world, player, CharacterInfo);
            assert(strength + agility + vitality + stamina > 0, 'No points to assign');
            assert(
                character_info.points >= strength + agility + vitality + stamina,
                'Not enough points'
            );

            let mut attributes = character_info.attributes;

            attributes.strength += strength;
            attributes.agility += agility;
            attributes.vitality += vitality;
            attributes.stamina += stamina;

            assert(
                attributes.strength <= MAX_STRENGTH
                    && attributes.agility <= MAX_AGILITY
                    && attributes.vitality <= MAX_VITALITY
                    && attributes.stamina <= MAX_STAMINA,
                'Attributes are not allowed'
            );

            character_info.attributes = attributes;
            character_info.points -= 1;

            set!(world, (character_info));
        }

        fn update_strategy(ref self: ContractState, strategy: ClassHash) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            // TODO: Consume XP / Experience Points to enable updates

            let mut character_info = get!(world, player, CharacterInfo);
            character_info.strategy = strategy;

            set!(world, (character_info));
        }

        fn battle(
            ref self: ContractState, c1: ArenaCharacter, c2: ArenaCharacter
        ) -> (ArenaCharacter, Span<Span<u32>>) {
            let mut logs = ArrayTrait::new();

            let mut c1_state = CharacterState {
                hp: c1.hp, position: FIRST_POS, energy: c1.energy, consecutive_rest_count: 0,
            };

            let mut c2_state = CharacterState {
                hp: c2.hp, position: SECOND_POS, energy: c2.energy, consecutive_rest_count: 0,
            };

            let mut c1_initiative: u32 = 0;
            let mut c2_initiative: u32 = 0;
            let mut turns: u32 = 0;

            let mut winner = c1.clone();
            loop {
                if turns >= 25 {
                    if c1_state.hp <= c2_state.hp {
                        winner = c2;
                    }
                    break;
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

                let mut arr = array![
                    turns,
                    c1_state.hp,
                    c2_state.hp,
                    c1_state.position,
                    c2_state.position,
                    c1_state.energy,
                    c2_state.energy,
                    mirror_ation_to_int(c1_action),
                    mirror_ation_to_int(c2_action),
                    c1_initiative,
                    c2_initiative
                ];
                logs.append(arr.span());

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
                    execute_action(c2_action, ref c2_state, ref c1_state, @c2, @c1);

                    if c1_state.hp == 0 {
                        winner = c2;
                        break;
                    }
                    execute_action(c1_action, ref c1_state, ref c2_state, @c1, @c2);
                    if c2_state.hp == 0 {
                        break;
                    }
                }
            };

            let mut arr = array![
                turns + 1,
                c1_state.hp,
                c2_state.hp,
                c1_state.position,
                c2_state.position,
                c1_state.energy,
                c2_state.energy,
                0,
                0,
                0,
                0
            ];
            logs.append(arr.span());

            (winner, logs.span())
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

    use dojo_arena::models::io::{InitialAttributes, SetTier, CharacterAttributes};

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
    fn test_update_strategy() {
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
        let character = get!(world, player, (CharacterInfo));
        assert(
            character.strategy == starknet::class_hash_const::<0x123>(), 'strategy is not correct'
        );

        actions_system.update_strategy(starknet::class_hash_const::<0x321>());
        let character = get!(world, player, (CharacterInfo));
        assert(
            character.strategy == starknet::class_hash_const::<0x321>(), 'strategy is not correct'
        );
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_close_arena() {
        let player = starknet::contract_address_const::<0x0>();
        let player2 = starknet::contract_address_const::<0x1>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
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
        actions_system
            .createCharacter(
                'c2',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x321>()
            );

        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let mut arena = get!(world, 1, (Arena));
        arena.character_count = 2;
        arena.total_rating = 100;
        set!(world, (arena));

        let c1 = ArenaCharacter {
            arena_id: 1,
            character_count: 1,
            name: 'c1',
            hp: 30,
            energy: 26,
            position: 0,
            attributes: CharacterAttributes { strength: 2, agility: 2, vitality: 3, stamina: 2, },
            character_owner: player,
            strategy: starknet::class_hash_const::<0x123>(),
            rating: 30,
        };

        let c2 = ArenaCharacter {
            arena_id: 1,
            character_count: 2,
            name: 'c2',
            hp: 30,
            energy: 26,
            position: 0,
            attributes: CharacterAttributes { strength: 2, agility: 2, vitality: 3, stamina: 2, },
            character_owner: player2,
            strategy: starknet::class_hash_const::<0x321>(),
            rating: 70,
        };

        set!(world, (c1, c2));

        actions_system.closeArena(1);

        let arena = get!(world, 1, (Arena));
        assert(arena.is_closed, 'arena is not closed');

        let character = get!(world, (arena.id, 1), (ArenaCharacter));
        assert(character.name == 'c1', 'name is not correct');
        assert(character.character_owner == player, 'owner is not correct');

        let character = get!(world, (arena.id, 2), (ArenaCharacter));
        assert(character.name == 'c2', 'name is not correct');
        assert(character.character_owner == player2, 'owner is not correct');

        let character_info = get!(world, player, (CharacterInfo));
        assert(character_info.golds == 1500, 'golds is not correct');

        let character_info = get!(world, player2, (CharacterInfo));
        assert(character_info.golds == 3500, 'golds is not correct');
    }

    mod testing_strategies;
    use testing_strategies::{Strategy};

    #[test]
    #[available_gas(3000000000000000)]
    fn test_play() {
        let player = starknet::contract_address_const::<0x1>();
        let player2 = starknet::contract_address_const::<0x2>();

        let mut models = array![
            character_info::TEST_CLASS_HASH,
            character_info::TEST_CLASS_HASH,
            counter::TEST_CLASS_HASH,
            arena::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
            arena_character::TEST_CLASS_HASH,
        ];

        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());

        let actions_system = IActionsDispatcher { contract_address };

        let character_info_1 = CharacterInfo {
            owner: player,
            name: 'c1',
            attributes: CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            strategy: Strategy::TEST_CLASS_HASH.try_into().unwrap(),
            level: 0,
            experience: 0,
            points: 0,
            golds: 0,
        };

        let character_info_2 = CharacterInfo {
            owner: player2,
            name: 'c1',
            attributes: CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            strategy: Strategy::TEST_CLASS_HASH.try_into().unwrap(),
            level: 0,
            experience: 0,
            points: 0,
            golds: 0,
        };

        actions_system.createArena('Sky Arena', SetTier::Tier5);
        let mut arena = get!(world, 1, (Arena));
        arena.character_count = 2;
        set!(world, (arena, character_info_1, character_info_2));

        let c1 = ArenaCharacter {
            arena_id: 1,
            character_count: 1,
            name: 'c1',
            hp: 30,
            energy: 26,
            position: 0,
            attributes: CharacterAttributes { strength: 2, agility: 2, vitality: 3, stamina: 2, },
            character_owner: player,
            strategy: Strategy::TEST_CLASS_HASH.try_into().unwrap(),
            rating: 30,
        };

        let c2 = ArenaCharacter {
            arena_id: 1,
            character_count: 2,
            name: 'c2',
            hp: 30,
            energy: 26,
            position: 0,
            attributes: CharacterAttributes { strength: 2, agility: 3, vitality: 2, stamina: 2, },
            character_owner: player2,
            strategy: Strategy::TEST_CLASS_HASH.try_into().unwrap(),
            rating: 70,
        };

        set!(world, (c1, c2));

        actions_system.play(1);

        let arena = get!(world, 1, (Arena));
        arena.winner.print();
    }
}
