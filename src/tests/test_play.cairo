#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;

    use dojo::model::{Model, ModelTest, ModelIndex, ModelEntityTest};
    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    use dojo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use dojo_arena::models::Character::{CharacterInfo, CharacterAttributes};
    use dojo_arena::models::Arena::{Arena, ArenaCounter, SetTier, ArenaCharacter, ArenaRegistered};

    use dojo_arena::strategies::testing_strategies::Strategy;

    use dojo_arena::constants::COUNTER_ID;

    use debug::PrintTrait;

    fn get_systems(world: IWorldDispatcher) -> (ContractAddress, IActionsDispatcher,) {
        let actions_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let mut actions_system = IActionsDispatcher { contract_address: actions_address };

        world.grant_writer(Model::<CharacterInfo>::selector(), actions_address);
        world.grant_writer(Model::<Arena>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCounter>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCharacter>::selector(), actions_address);
        world.grant_writer(Model::<ArenaRegistered>::selector(), actions_address);

        (actions_address, actions_system,)
    }

    #[test]
    #[should_panic(expected: ('Arena is not ready', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_ready() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let counter = get!(world, COUNTER_ID, (ArenaCounter));

        actions_system.register(counter.arena_count);

        actions_system.play(counter.arena_count);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_play() {
        let player = starknet::contract_address_const::<0x1>();
        let player2 = starknet::contract_address_const::<0x2>();

        let world = spawn_test_world!();
        let (actions_address, mut actions_system,) = get_systems(world);

        set_contract_address(actions_address);
        let character_info_1 = CharacterInfo {
            player: player,
            name: 'c1',
            attributes: CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            strategy: Strategy::TEST_CLASS_HASH.try_into().unwrap(),
            level: 0,
            experience: 0,
            points: 0,
            golds: 0,
        };

        let character_info_2 = CharacterInfo {
            player: player2,
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
        };

        set!(world, (c1, c2));

        actions_system.play(1);

        let arena = get!(world, 1, (Arena));
        arena.winner.print();
    }
}
