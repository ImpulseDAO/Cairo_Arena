use cairo_arena::models::Arena::{BattleAction, ArenaCharacter, Direction};

#[dojo::interface]
trait IFight {
    fn play(ref world: IWorldDispatcher, arena_id: u32);
    fn get_number_of_players(ref world: IWorldDispatcher, arena_id: u32) -> u8;
}

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, characters: Span<ArenaCharacter>, active_cid: u8
    ) -> (BattleAction, Direction);
}

#[dojo::contract]
mod fight_system {
    use super::{IFight};
    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

    use starknet::{ContractAddress, get_caller_address};
    use starknet::{contract_address_const, class_hash_const};

    use cairo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, Side, BattleAction, Direction
    };

    use cairo_arena::constants::{TIE, COUNTER_ID, RED, BLUE, GRID_WIDTH, GRID_HEIGHT};

    use cairo_arena::utils::{calculate_initiative, execute_action};

    #[derive(Drop, Serde)]
    #[dojo::model]
    #[dojo::event]
    struct BattleLog {
        #[key]
        arena_id: u32,
        #[key]
        turn: u8,
        log: Array<u32>,
    }

    #[derive(Copy, Drop, Serde, Introspect)]
    struct SurvivorNumber {
        red: u8,
        blue: u8,
        active: u8,
    }

    fn pre_fight(turn: u8, ref c: ArenaCharacter, ref survivors: SurvivorNumber, ref sequence: Felt252Dict<u8>, characters: Span<ArenaCharacter>) {
        // hit player 20 hp every 5 turns
        if turn % 5 == 0 {
            c.hp = if c.hp > 20 { c.hp - 20 } else { 0 };
        }

        if c.hp > 0 {
            if c.side == Side::Red {
                survivors.red += 1;
            } else {
                survivors.blue += 1;
            }
            survivors.active += 1;

            let (action, direction) = IStrategyLibraryDispatcher {
                class_hash: c.strategy
            }.determin_action(characters, c.cid);
            c.action = action;
            c.direction = direction;
    
            c.initiative = calculate_initiative(action, c.attributes.agility);
            sequence.insert(survivors.active.into(), c.cid);
        }
    }

    #[abi(embed_v0)]
    impl FightImpl of IFight<ContractState> {
        fn play(ref world: IWorldDispatcher, arena_id: u32) {
            let mut counter = get!(world, COUNTER_ID, ArenaCounter);
            assert(arena_id > 0 && arena_id <= counter.arena_count, 'Arena does not exist');

            let mut arena = get!(world, arena_id, Arena);
            assert(!arena.is_closed, 'Arena is closed');
            let characters_number = arena.characters_number;
            assert(characters_number == 6, 'Arena is not ready');

            let mut arenaGrid: Felt252Dict<u8> = Default::default();

            // as Felt252Dict and Array limits, don't support dynamic characters number
            let mut c1 = get!(world, (arena_id, 1), ArenaCharacter);
            let c1_grid = c1.position.x + c1.position.y * GRID_HEIGHT;
            arenaGrid.insert(c1_grid.into(), 1);
            let mut c2 = get!(world, (arena_id, 2), ArenaCharacter);
            let c2_grid = c2.position.x + c2.position.y * GRID_HEIGHT;
            arenaGrid.insert(c2_grid.into(), 2);
            let mut c3 = get!(world, (arena_id, 3), ArenaCharacter);
            let c3_grid = c3.position.x + c3.position.y * GRID_HEIGHT;
            arenaGrid.insert(c3_grid.into(), 3);
            let mut c4 = get!(world, (arena_id, 4), ArenaCharacter);
            let c4_grid = c4.position.x + c4.position.y * GRID_HEIGHT;
            arenaGrid.insert(c4_grid.into(), 4);
            let mut c5 = get!(world, (arena_id, 5), ArenaCharacter);
            let c5_grid = c5.position.x + c5.position.y * GRID_HEIGHT;
            arenaGrid.insert(c5_grid.into(), 5);
            let mut c6 = get!(world, (arena_id, 6), ArenaCharacter);
            let c6_grid = c6.position.x + c6.position.y * GRID_HEIGHT;
            arenaGrid.insert(c6_grid.into(), 6);

            let mut turn: u8 = 0;
            loop {
                let mut log: Array<u32> = ArrayTrait::new();
                turn += 1;
                // println!("Turn: {}", turn); 

                let mut survivors = SurvivorNumber {
                    red: 0,
                    blue: 0,
                    active: 0,
                };

                let mut sequence: Felt252Dict<u8> = Default::default();
                pre_fight(turn, ref c1, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                pre_fight(turn, ref c2, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                pre_fight(turn, ref c3, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                pre_fight(turn, ref c4, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                pre_fight(turn, ref c5, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                pre_fight(turn, ref c6, ref survivors, ref sequence, array![c1, c2, c3, c4, c5, c6].span());
                
                // println!("Red survivors: {}", survivors.red);
                // println!("Blue survivors: {}", survivors.blue);
                if survivors.red == 0 && survivors.blue == 0 {
                    arena.winner = TIE;
                    break;
                } else if survivors.blue == 0 {
                    arena.winner = RED;
                    break;
                } else if survivors.red == 0 {
                    arena.winner = BLUE;
                    break;
                }

                // bubble to sort characters by initiative
                let characters = array![c1, c2, c3, c4, c5, c6];
                let mut i: u8 = 0;
                loop {
                    i += 1;
                    if i > survivors.active {
                        break;
                    }
                    let mut j: u8 = 0;
                    loop {
                        j += 1;
                        if j > survivors.active - i {
                            break;
                        }
                        let c1 = *characters.at(sequence.get(j.into()).into() - 1);
                        let c2 = *characters.at(sequence.get((j+1).into()).into() - 1);
                        if c1.initiative > c2.initiative || (c1.initiative == c2.initiative && c1.attributes.agility < c2.attributes.agility) {
                            let temp = sequence.get(j.into());
                            sequence.insert(j.into(), sequence.get((j+1).into()));
                            sequence.insert((j+1).into(), temp);
                        }
                    };
                };

                let mut k: u8 = 0;
                while k < survivors.active {
                    k += 1;
                    let cid = sequence.get(k.into());
                    let c = *characters.at(cid.into() - 1);
                    let (fail_reason, target_cid) = match cid {
                        0 => {
                            assert(false, 'Character does not exist');
                            (0, 0)
                        },
                        1 => execute_action(ref c1, ref c2, ref c3, ref c4, ref c5, ref c6, ref arenaGrid),
                        2 => execute_action(ref c2, ref c1, ref c3, ref c4, ref c5, ref c6, ref arenaGrid),
                        3 => execute_action(ref c3, ref c1, ref c2, ref c4, ref c5, ref c6, ref arenaGrid),
                        4 => execute_action(ref c4, ref c1, ref c2, ref c3, ref c5, ref c6, ref arenaGrid),
                        5 => execute_action(ref c5, ref c1, ref c2, ref c3, ref c4, ref c6, ref arenaGrid),
                        6 => execute_action(ref c6, ref c1, ref c2, ref c3, ref c4, ref c5, ref arenaGrid),
                        _ => {
                            assert(false, 'Character does not exist');
                            (0, 0)
                        },
                    };

                    log.append(c.cid.into());
                    let action = match c.action {
                        BattleAction::QuickAttack => 1_u32,
                        BattleAction::PreciseAttack => 2_u32,
                        BattleAction::HeavyAttack => 3_32,
                        BattleAction::Move => 4_u32,
                        BattleAction::Rest => 5_u32,
                    };
                    log.append(action);
                    let direction = match c.direction {
                        Direction::Up => 1_u32,
                        Direction::Down => 2_u32,
                        Direction::Right => 3_u32,
                        Direction::Left => 4_u32,
                    };
                    log.append(direction);
                    log.append(c.hp);
                    log.append(c.energy);
                    log.append(c.position.x.into());
                    log.append(c.position.y.into());
                    log.append(fail_reason.into());
                    if target_cid != 0 {
                        let target = *characters.at(target_cid.into() - 1);
                        log.append(target_cid.into());
                        let action = match target.action {
                            BattleAction::QuickAttack => 1_u32,
                            BattleAction::PreciseAttack => 2_u32,
                            BattleAction::HeavyAttack => 3_32,
                            BattleAction::Move => 4_u32,
                            BattleAction::Rest => 5_u32,
                        };
                        log.append(action);
                        let direction = match target.direction {
                            Direction::Up => 1_u32,
                            Direction::Down => 2_u32,
                            Direction::Right => 3_u32,
                            Direction::Left => 4_u32,
                        };
                        log.append(direction);
                        log.append(target.hp);
                        log.append(target.energy);
                        log.append(target.position.x.into());
                        log.append(target.position.y.into());
                        log.append(0);
                    }
                };

                emit!(
                    world,
                    (BattleLog {
                        arena_id: arena_id,
                        turn: turn,
                        log: log,
                    })
                );
            };

            set!(world, (arena));
        }

        fn get_number_of_players(ref world: IWorldDispatcher, arena_id: u32) -> u8 {
            let world = self.world_dispatcher.read();
            let mut counter = get!(world, COUNTER_ID, ArenaCounter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let arena = get!(world, arena_id, Arena);
            arena.characters_number
        }
    }
}

