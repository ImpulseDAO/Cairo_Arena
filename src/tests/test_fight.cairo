#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;
    use starknet::ClassHash;

    use dojo::model::{Model, ModelTest, ModelIndex, ModelEntityTest};
    // import world dispatcher
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    use dojo::utils::test::{spawn_test_world, deploy_contract};

    use cairo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use cairo_arena::systems::fight::{fight_system, IFight, IFightDispatcher, IFightDispatcherTrait};
    use cairo_arena::models::Character::{CharacterInfo, CharacterAttributes};
    use cairo_arena::models::Arena::{Arena, ArenaCounter, SetTier, ArenaCharacter, ArenaRegistered};

    use cairo_arena::strategies::testing_strategies::Strategy;

    use cairo_arena::constants::COUNTER_ID;

    fn get_systems(world: IWorldDispatcher) -> (ContractAddress, IActionsDispatcher, ContractAddress, IFightDispatcher) {
        let actions_address = world
            .deploy_contract('salt1', actions::TEST_CLASS_HASH.try_into().unwrap());
        let mut actions_system = IActionsDispatcher { contract_address: actions_address };
        world.grant_writer(Model::<CharacterInfo>::selector(), actions_address);
        world.grant_writer(Model::<Arena>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCounter>::selector(), actions_address);
        world.grant_writer(Model::<ArenaCharacter>::selector(), actions_address);
        world.grant_writer(Model::<ArenaRegistered>::selector(), actions_address);

        let fight_system_address = world.deploy_contract('salt2', fight_system::TEST_CLASS_HASH.try_into().unwrap());
        let mut fight_system = IFightDispatcher { contract_address: fight_system_address };
        world.grant_writer(Model::<Arena>::selector(), fight_system_address);
        world.grant_writer(Model::<ArenaCounter>::selector(), fight_system_address);
        world.grant_writer(Model::<ArenaCharacter>::selector(), fight_system_address);
        world.grant_writer(Model::<ArenaRegistered>::selector(), fight_system_address);

        (actions_address, actions_system, fight_system_address, fight_system)
    }

    #[test]
    #[should_panic(expected: ('Arena is not ready', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_ready() {
        let world = spawn_test_world!();
        let (_, mut actions_system, _, mut fight_system) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena');

        let counter = get!(world, COUNTER_ID, (ArenaCounter));

        fight_system.play(counter.arena_count);
    }

    #[test]
    #[should_panic(expected: ('Arena does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_exist() {
        let world = spawn_test_world!();
        let (_, mut actions_system, _, fight_system) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        fight_system.play(1);
    }

    #[test]
    #[should_panic(expected: ('Arena is closed', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_already_closed() {
        let world = spawn_test_world!();
        let (_, mut actions_system, _, fight_system) = get_systems(world);

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.createArena('Sky Arena');
        let counter = get!(world, COUNTER_ID, (ArenaCounter));
        let mut arena = get!(world, counter.arena_count, (Arena));
        arena.is_closed = true;
        set!(world, (arena));

        fight_system.play(counter.arena_count);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_play() {

        let s: ClassHash = Strategy::TEST_CLASS_HASH.try_into().unwrap();

        println!("strategy hash {:?}", s);
        let world = spawn_test_world!();
        let (_, mut actions_system, _, mut fight_system) = get_systems(world);

        let player1 = starknet::contract_address_const::<0x1>();
        set_contract_address(player1);

        actions_system.createCharacter(
            'p1',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.createArena('Sky Arena');
        
        let player2 = starknet::contract_address_const::<0x2>();
        set_contract_address(player2);
        actions_system.createCharacter(
            'p2',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1);

        let player3 = starknet::contract_address_const::<0x3>();
        set_contract_address(player3);
        actions_system.createCharacter(
            'p3',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1);

        let player4 = starknet::contract_address_const::<0x4>();
        set_contract_address(player4);
        actions_system.createCharacter(
            'p4',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1);

        let player5 = starknet::contract_address_const::<0x5>();
        set_contract_address(player5);
        actions_system.createCharacter(
            'p5',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1);

        let player6 = starknet::contract_address_const::<0x6>();
        set_contract_address(player6);
        actions_system.createCharacter(
            'p6',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1);
 
        fight_system.play(1);

        let arena = get!(world, 1, (Arena));
        println!("Arena Winner {}", arena.winner);
    }
}
