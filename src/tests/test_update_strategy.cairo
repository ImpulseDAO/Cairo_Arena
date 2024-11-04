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
    fn test_update_strategy() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address };

        let player = starknet::contract_address_const::<0x0>();

        actions_system.createCharacter(
            'c1',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            starknet::class_hash_const::<0x123>()
        );

        let character_info: CharacterInfo = world.read_model(player);

        assert(character_info.player == player, 'player is not correct');
        assert(character_info.strategy == starknet::class_hash_const::<0x123>(), 'strategy is not correct');

        actions_system.update_strategy(
            starknet::class_hash_const::<0x456>()
        );
        let character_info: CharacterInfo = world.read_model(player);
        assert(character_info.strategy == starknet::class_hash_const::<0x456>(), 'strategy is not correct');
    }
}
