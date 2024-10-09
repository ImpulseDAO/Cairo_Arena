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

    use dojo_arena::constants::{COUNTER_ID, HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY};

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
    #[should_panic(expected: ('Arena does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_arena_not_exists() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.register(1);
    }

    #[test]
    #[should_panic(expected: ('Character does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_character_not_exists() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system.createArena('Sky Arena', SetTier::Tier3);

        actions_system.register(1);
    }

    #[test]
    #[should_panic(expected: ('Character tier is not allowed', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_tier_not_match() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier3);

        actions_system.register(1);
    }

    #[test]
    #[should_panic(expected: ('Character already registered', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_player_already_registered() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'c1',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        let counter = get!(world, COUNTER_ID, (ArenaCounter));

        actions_system.register(counter.arena_count);
        actions_system.register(counter.arena_count);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_register() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        let player = starknet::contract_address_const::<0x0>();

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena', SetTier::Tier5);

        actions_system.register(1);

        let counter = get!(world, COUNTER_ID, (ArenaCounter));
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
}
