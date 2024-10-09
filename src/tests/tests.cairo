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

    use dojo_arena::models::io::{SetTier, CharacterAttributes};

    // import actions
    use super::{
        actions, IActionsDispatcher, IActionsDispatcherTrait, COUNTER_ID, HP_MULTIPLIER, BASE_HP,
        ENERGY_MULTIPLIER, BASE_ENERGY
    };

    use debug::PrintTrait;


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
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
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
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system
            .createCharacter(
                'c2',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
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
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        actions_system.register(1);

        let counter = get!(world, COUNTER_ID, (Counter));
        let arena = get!(world, counter.arena_count, (Arena));
        assert(actions_system.get_number_of_players(arena.id) == 1, 'Number is not correct');
    }
}
