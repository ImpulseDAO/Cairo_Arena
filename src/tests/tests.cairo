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

    #[test]
    #[available_gas(3000000000000000)]
    fn test_get_number_of_players() {
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
        assert(actions_system.get_number_of_players(arena.id) == 1, 'Number is not correct');
    }
}
