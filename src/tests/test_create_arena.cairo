#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;

    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDefTrait};

    use cairo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use cairo_arena::models::Arena::{Arena, m_Arena, ArenaCounter, m_ArenaCounter, SetTier, ArenaCharacter, m_ArenaCharacter, ArenaRegistered, m_ArenaRegistered};
    use cairo_arena::models::Character::{CharacterInfo, m_CharacterInfo, CharacterAttributes};
    use cairo_arena::constants::COUNTER_ID;

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
    #[available_gas(3000000000000000)]
    fn test_create_arena() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.createCharacter(
            'asten',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            starknet::class_hash_const::<0x123>()
        );

        actions_system.createArena('Sky Arena');

        let player = starknet::contract_address_const::<0x0>();

        let counter: ArenaCounter = world.read_model(COUNTER_ID);
        assert(counter.arena_count == 1, 'arena count is not correct');

        let arena: Arena = world.read_model(counter.arena_count);
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
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system.createArena('Sky Arena');

        let player = starknet::contract_address_const::<0x0>();

        let counter: ArenaCounter = world.read_model(COUNTER_ID);
        assert(counter.arena_count == 1, 'arena count is not correct');

        let arena: Arena = world.read_model(counter.arena_count);
        assert(arena.name == 'Sky Arena', 'name is not correct');
        assert(arena.player == player, 'owner is not correct');
        assert(arena.current_tier == SetTier::Tier5, 'Tier is not correct');
        assert(arena.characters_number == 0, 'Character count is not correct');
        assert(arena.winner == 0, 'winner is not correct');
    }
}
