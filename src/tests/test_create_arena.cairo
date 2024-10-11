#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;

    use dojo::model::{Model, ModelTest, ModelIndex, ModelEntityTest};
    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    use cairo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use cairo_arena::models::Arena::{Arena, ArenaCounter, SetTier, ArenaCharacter, ArenaRegistered};
    use cairo_arena::constants::COUNTER_ID;
    use cairo_arena::models::Character::{CharacterInfo, CharacterAttributes};

    fn get_systems(world: IWorldDispatcher) -> (ContractAddress, IActionsDispatcher,) {
        let actions_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let mut actions_system = IActionsDispatcher { contract_address: actions_address };

        world.grant_writer(Model::<Arena>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCounter>::selector(), actions_address);
        world.grant_writer(Model::<CharacterInfo>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCharacter>::selector(), actions_address);
        world.grant_writer(Model::<ArenaRegistered>::selector(), actions_address);

        (actions_address, actions_system,)
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_create_arena() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system.createCharacter(
            'asten',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            starknet::class_hash_const::<0x123>()
        );

        actions_system.createArena('Sky Arena');

        let player = starknet::contract_address_const::<0x0>();

        let counter = get!(world, COUNTER_ID, (ArenaCounter));
        assert(counter.arena_count == 1, 'arena count is not correct');

        let arena = get!(world, counter.arena_count, (Arena));
        assert(arena.name == 'Sky Arena', 'name is not correct');
        assert(arena.player == player, 'owner is not correct');
        assert(arena.current_tier == SetTier::Tier5, 'Tier is not correct');
        assert(arena.characters_number == 1, 'Character count is not correct');
        assert(arena.winner == 0, 'winner is not correct');
    }

    #[test]
    #[should_panic(expected: ('Character does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_create_arena_character_does_not_exist() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system.createArena('Sky Arena');

        let player = starknet::contract_address_const::<0x0>();

        let counter = get!(world, COUNTER_ID, (ArenaCounter));
        assert(counter.arena_count == 1, 'arena count is not correct');

        let arena = get!(world, counter.arena_count, (Arena));
        assert(arena.name == 'Sky Arena', 'name is not correct');
        assert(arena.player == player, 'owner is not correct');
        assert(arena.current_tier == SetTier::Tier5, 'Tier is not correct');
        assert(arena.characters_number == 0, 'Character count is not correct');
        assert(arena.winner == 0, 'winner is not correct');
    }
}
