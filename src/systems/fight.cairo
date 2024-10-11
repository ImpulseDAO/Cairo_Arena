use dojo_arena::models::Arena::{BattleAction, ArenaCharacter, SetTier, Direction};
use starknet::ClassHash;

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

    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};

    use dojo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, ArenaRegistered, SetTier, BattleAction, Side
    };
    use dojo_arena::models::Character::{CharacterInfo, CharacterAttributes};

    use dojo_arena::constants::{
        GRID_WIDTH, GRID_HEIGHT, TIE, COUNTER_ID, RED, BLUE
    };

    use dojo_arena::utils::{
        calculate_initiative, execute_action, get_level_xp
    };

    #[derive(Copy, Drop, Serde)]
    #[dojo::model]
    #[dojo::event]
    struct BattleLog {
        #[key]
        arena_id: u32,
        logs: Span<Span<u32>>,
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

            let mut characters = ArrayTrait::new();
            let mut i: u8 = 0;
            loop {
                i += 1;
                if i > characters_number {
                    break;
                }
                let mut c = get!(world, (arena_id, i), ArenaCharacter);
                characters.append(c);

                let grid = c.position.x * GRID_WIDTH + c.position.y;
                arenaGrid.insert(grid.into(), i);
            };

            let mut turn: u8 = 0;
            let mut red_survivors: u8 = 0;
            let mut blue_survivors: u8 = 0;
            loop {
                turn += 1;

                let mut active_number: u8 = 0;
                let mut sequence: Felt252Dict<u8> = Default::default();
                let characters_span = characters.span();

                let mut c_index: u8 = 0;
                while c_index < characters_number {
                    let mut c = *characters.at(c_index.into());
                    // hit player 20 hp every 5 turns
                    if turn % 5 == 0 {
                        c.hp = if c.hp > 20 { c.hp - 20 } else { 0 };
                    }
                    if c.hp == 0 {
                        continue;
                    }
                    if c.side == Side::Red {
                        red_survivors += 1;
                    } else {
                        blue_survivors += 1;
                    }
                    active_number += 1;

                    let cid = c.cid;
                    let (action, direction) = IStrategyLibraryDispatcher {
                        class_hash: c.strategy
                    }.determin_action(characters_span, cid);
                    c.action = action;
                    c.direction = direction;

                    c.initiative = calculate_initiative(action, c.attributes.agility);
                    sequence.insert(active_number.into(), cid);

                    c_index += 1;
                };

                if red_survivors == 0 && blue_survivors == 0 {
                    arena.winner = TIE;
                    break;
                } else if blue_survivors == 0 {
                    arena.winner = RED;
                    break;
                } else if red_survivors == 0 {
                    arena.winner = BLUE;
                    break;
                }

                // bubble to sort characters by initiative
                let mut i: u8 = 0;
                loop {
                    i += 1;
                    if i > active_number{
                        break;
                    }
                    let mut j: u8 = 0;
                    loop {
                        j += 1;
                        if j > active_number - i {
                            break;
                        }
                        let c1 = characters.at(sequence.get(j.into()).into() - 1);
                        let c2 = characters.at(sequence.get((j+1).into()).into() - 1);
                        if c1.initiative > c2.initiative || (c1.initiative == c2.initiative && c1.attributes.agility < c2.attributes.agility) {
                            let temp = sequence.get(j.into());
                            sequence.insert(j.into(), sequence.get((j+1).into()));
                            sequence.insert((j+1).into(), temp);
                        }
                    };
                };

                let mut k: u8 = 0;
                while k < active_number {
                    k += 1;
                    let cid = sequence.get(k.into());
                    execute_action(ref characters, cid, ref arenaGrid);
                };
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

