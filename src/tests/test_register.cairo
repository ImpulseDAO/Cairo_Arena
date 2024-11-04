#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;

    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDefTrait};

    use cairo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use cairo_arena::models::Arena::{Arena, m_Arena, ArenaCounter, m_ArenaCounter, SetTier, ArenaCharacter, m_ArenaCharacter, ArenaRegistered, m_ArenaRegistered, Side, Direction};
    use cairo_arena::models::Character::{CharacterInfo, m_CharacterInfo, CharacterAttributes};

    use cairo_arena::constants::{COUNTER_ID, HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY};

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "arena", resources: [
                TestResource::Model(m_Arena::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaCounter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaCharacter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaRegistered::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_CharacterInfo::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Contract(
                    ContractDefTrait::new(actions::TEST_CLASS_HASH, "actions")
                        .with_writer_of([dojo::utils::bytearray_hash(@"arena")].span())
                )
            ].span()
        };
 
        ndef
    }

    #[test]
    #[should_panic(expected: ('Arena does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_arena_not_exists() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.register(1, Side::Red);
    }

    #[test]
    #[should_panic(expected: ('Character does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_character_not_exists() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.createArena('Sky Arena');

        actions_system.register(1, Side::Red);
    }

    #[test]
    #[should_panic(expected: ('Character tier is not allowed', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_register_tier_not_match() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        let admin = starknet::contract_address_const::<0x0>();
        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena');

        let alice = starknet::contract_address_const::<0x1>();
        set_contract_address(alice);
        actions_system
            .createCharacter(
                'alice',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        set_contract_address(admin);
        let mut alice_info: CharacterInfo = world.read_model(alice);
        alice_info.level = 1;

        world.write_model(@alice_info);

        set_contract_address(alice);
        actions_system.register(1, Side::Red);
    }

    #[test]
    #[should_panic(expected: ('Character already registered', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_player_already_registered() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'c1',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena');

        let counter: ArenaCounter = world.read_model(COUNTER_ID);

        actions_system.register(counter.arena_count, Side::Red);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_register() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        let player = starknet::contract_address_const::<0x0>();

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena');

        let counter: ArenaCounter = world.read_model(COUNTER_ID);
        let arena: Arena = world.read_model(counter.arena_count);
        assert(arena.characters_number == 1, 'Character count is not correct');

        let character: ArenaCharacter = world.read_model((arena.id, arena.characters_number));
        assert(character.name == 'asten', 'name is not correct');
        assert(character.attributes.strength == 2, 'strength is not correct');
        assert(character.attributes.agility == 2, 'agility is not correct');
        assert(character.attributes.vitality == 3, 'vitality is not correct');
        assert(character.attributes.stamina == 2, 'stamina is not correct');
        assert(character.character_owner == player, 'owner is not correct');
        assert(character.position.x == 0, 'position is not correct');
        assert(character.position.y == 1, 'position is not correct');
        assert(character.direction == Direction::Right, 'direction is not correct');
        assert(character.consecutive_rest_count == 0, 'rest count is not correct');
        assert(character.side == Side::Red, 'side is not correct');

        let hp = 3 * HP_MULTIPLIER + BASE_HP;
        let energy = 2 * ENERGY_MULTIPLIER + BASE_ENERGY;
        assert(character.hp == hp, 'hp is not correct');
        assert(character.energy == energy, 'energy is not correct');

        let alice = starknet::contract_address_const::<0x1>();
        set_contract_address(alice);
        actions_system
            .createCharacter(
                'alice',
                CharacterAttributes { strength: 0, agility: 2, vitality: 3, stamina: 0 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.register(1, Side::Red);

        let counter: ArenaCounter = world.read_model(COUNTER_ID);
        let arena: Arena = world.read_model(counter.arena_count);
        assert(arena.characters_number == 2, 'Character count is not correct');

        let character: ArenaCharacter = world.read_model((arena.id, arena.characters_number));
        assert(character.name == 'alice', 'name is not correct');
        assert(character.attributes.strength == 1, 'strength is not correct');
        assert(character.attributes.agility == 3, 'agility is not correct');
        assert(character.attributes.vitality == 4, 'vitality is not correct');
        assert(character.attributes.stamina == 1, 'stamina is not correct');
        assert(character.character_owner == alice, 'owner is not correct');
        assert(character.position.x == 0, 'position is not correct');
        assert(character.position.y == 3, 'position is not correct');
        assert(character.direction == Direction::Right, 'direction is not correct');
        assert(character.consecutive_rest_count == 0, 'rest count is not correct');
        assert(character.side == Side::Red, 'side is not correct');

        let hp = 4 * HP_MULTIPLIER + BASE_HP;
        let energy = 1 * ENERGY_MULTIPLIER + BASE_ENERGY;
        assert(character.hp == hp, 'hp is not correct');
        assert(character.energy == energy, 'energy is not correct');
    }
}
