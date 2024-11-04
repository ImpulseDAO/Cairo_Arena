#[cfg(test)]
mod tests {
    use core::starknet::contract_address::ContractAddress;
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::testing::set_contract_address;
    use starknet::ClassHash;

    use dojo::model::{ModelStorage, ModelValueStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{spawn_test_world, NamespaceDef, TestResource, ContractDefTrait};

    use cairo_arena::systems::fight::{fight_system, IFight, IFightDispatcher, IFightDispatcherTrait};
    use cairo_arena::systems::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use cairo_arena::models::Arena::{Arena, m_Arena, ArenaCounter, m_ArenaCounter, SetTier, ArenaCharacter, m_ArenaCharacter, ArenaRegistered, m_ArenaRegistered, Side};
    use cairo_arena::models::Character::{CharacterInfo, m_CharacterInfo, CharacterAttributes};

    use cairo_arena::strategies::{testing_strategies_walk_around, testing_strategies_focus_attack};

    use cairo_arena::constants::COUNTER_ID;

    fn namespace_def() -> NamespaceDef {
        let ndef = NamespaceDef {
            namespace: "arena", resources: [
                TestResource::Model(m_Arena::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaCounter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaCharacter::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_ArenaRegistered::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Model(m_CharacterInfo::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Event(fight_system::e_BattleLog::TEST_CLASS_HASH.try_into().unwrap()),
                TestResource::Contract(
                    ContractDefTrait::new(actions::TEST_CLASS_HASH, "actions")
                        .with_writer_of([dojo::utils::bytearray_hash(@"arena")].span())
                ),
                TestResource::Contract(
                    ContractDefTrait::new(fight_system::TEST_CLASS_HASH, "fight_system")
                        .with_writer_of([dojo::utils::bytearray_hash(@"arena")].span())
                )
            ].span()
        };
 
        ndef
    }

    #[test]
    #[should_panic(expected: ('Arena is not ready', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_ready() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (actions_contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address: actions_contract_address };

        let (fight_contract_address, _) = world.dns(@"fight_system").unwrap();
        let fight_system = IFightDispatcher { contract_address: fight_contract_address };

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );
        actions_system.createArena('Sky Arena');

        let counter: ArenaCounter = world.read_model(COUNTER_ID);

        fight_system.play(counter.arena_count);
    }

    #[test]
    #[should_panic(expected: ('Arena does not exist', 'ENTRYPOINT_FAILED'))]
    #[available_gas(3000000000000000)]
    fn test_play_arena_not_exist() {
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (actions_contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address: actions_contract_address };

        let (fight_contract_address, _) = world.dns(@"fight_system").unwrap();
        let fight_system = IFightDispatcher { contract_address: fight_contract_address };

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
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (actions_contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address: actions_contract_address };

        let (fight_contract_address, _) = world.dns(@"fight_system").unwrap();
        let fight_system = IFightDispatcher { contract_address: fight_contract_address };

        actions_system
            .createCharacter(
                'asten',
                CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
                starknet::class_hash_const::<0x123>()
            );

        actions_system.createArena('Sky Arena');
        let counter: ArenaCounter = world.read_model(COUNTER_ID);
        let mut arena: Arena = world.read_model(counter.arena_count);
        arena.is_closed = true;

        world.write_model(@arena);

        fight_system.play(counter.arena_count);
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn test_play() {
        let s: ClassHash = testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap();
        println!("strategy hash {:?}", s);
        
        let ndef = namespace_def();
        let mut world = spawn_test_world([ndef].span());

        let (actions_contract_address, _) = world.dns(@"actions").unwrap();
        let actions_system = IActionsDispatcher { contract_address: actions_contract_address };

        let (fight_contract_address, _) = world.dns(@"fight_system").unwrap();
        let fight_system = IFightDispatcher { contract_address: fight_contract_address };

        let player1 = starknet::contract_address_const::<0x1>();
        set_contract_address(player1);

        actions_system.createCharacter(
            'p1',
            CharacterAttributes { strength: 1, agility: 1, vitality: 2, stamina: 1 },
            testing_strategies_focus_attack::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.createArena('Sky Arena');
        
        let player2 = starknet::contract_address_const::<0x2>();
        set_contract_address(player2);
        actions_system.createCharacter(
            'p2',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1, Side::Red);

        let player3 = starknet::contract_address_const::<0x3>();
        set_contract_address(player3);
        actions_system.createCharacter(
            'p3',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1, Side::Red);

        let player4 = starknet::contract_address_const::<0x4>();
        set_contract_address(player4);
        actions_system.createCharacter(
            'p4',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1, Side::Blue);

        let player5 = starknet::contract_address_const::<0x5>();
        set_contract_address(player5);
        actions_system.createCharacter(
            'p5',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1, Side::Blue);

        let player6 = starknet::contract_address_const::<0x6>();
        set_contract_address(player6);
        actions_system.createCharacter(
            'p6',
            CharacterAttributes { strength: 1, agility: 2, vitality: 1, stamina: 1 },
            testing_strategies_walk_around::Strategy::TEST_CLASS_HASH.try_into().unwrap()
        );
        actions_system.register(1, Side::Blue);
 
        fight_system.play(1);

        let arena: Arena = world.read_model(1);
        println!("Arena Winner {}", arena.winner);
    }
}
