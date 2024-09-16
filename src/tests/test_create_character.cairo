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
    use dojo_arena::models::Character::{CharacterInfo, InitialAttributes};

    fn get_systems(world: IWorldDispatcher) -> (ContractAddress, IActionsDispatcher,) {
        let actions_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let mut actions_system = IActionsDispatcher { contract_address: actions_address };

        world.grant_writer(Model::<CharacterInfo>::selector(), actions_address);

        (actions_address, actions_system,)
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_create_character() {
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        let player = starknet::contract_address_const::<0x0>();
        let character = get!(world, player, (CharacterInfo));

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
        let world = spawn_test_world!();
        let (_, mut actions_system,) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                InitialAttributes { strength: 2, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
    }
}
