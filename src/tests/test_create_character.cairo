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
    fn test_create_character() {
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

        let player = starknet::contract_address_const::<0x0>();
        let character: CharacterInfo = world.read_model(player);
        assert(character.name == 'asten', 'name is not correct');
        assert(character.attributes.strength == 2, 'strength is not correct');
        assert(character.attributes.agility == 2, 'agility is not correct');
        assert(character.attributes.vitality == 3, 'vitality is not correct');
        assert(character.attributes.stamina == 2, 'stamina is not correct');
    }

    #[test]
    #[should_panic(expected: ('Attributes must sum 5', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_create_character_wrong_init_attributes() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 2, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
    }

    #[test]
    #[should_panic(expected: ('Character already exists', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_create_character_already_exists() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        actions_system
            .createCharacter(
                'Alice',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.createCharacter(
            'Bob',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            starknet::class_hash_const::<0x123>()
        );
    }
}
