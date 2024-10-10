use dojo_arena::models::Arena::{BattleAction, ArenaCharacter, SetTier};
use starknet::ClassHash;

#[dojo::interface]
trait IFight {
    fn play(ref world: IWorldDispatcher, arena_id: u32);
    fn battle(c1: ArenaCharacter, c2: ArenaCharacter) -> (ArenaCharacter, Span<Span<u32>>);
    fn get_number_of_players(ref world: IWorldDispatcher, arena_id: u32) -> u32;
}

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, characters: Span<ArenaCharacter>, active_index: u32,
    ) -> BattleAction;
}

#[dojo::contract]
mod fight_system {
    use super::{IActions};
    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};

    use dojo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, ArenaRegistered, SetTier, BattleAction
    };
    use dojo_arena::models::Character::{CharacterInfo, CharacterAttributes};

    use dojo_arena::constants::{
        GRID_WIDTH, GRID_HEIGHT
    };

    use dojo_arena::utils::{
        new_pos_and_hit, new_pos_and_steps, calculate_initiative, execute_action, get_gain_xp,
        get_level_xp, mirror_ation_to_int
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
            let character_count = arena.character_count;
            assert(character_count == 6, 'Arena is not ready');

            let mut winner: felt252 = 0;

            let mut arenaGrid: Felt252Dict<u32> = Default::default();

            let mut characters = ArrayTrait::new();
            let mut i: usize = 0;
            loop {
                i += 1;
                if i > character_count {
                    break;
                }
                let c = get!(world, (arena_id, i), ArenaCharacter);
                characters.append(c);

                let grid = c.position.x * GRID_WIDTH + c.position.y;
                arenaGrid.insert(grid.into(), i);
            };

            let mut sequence: Felt252Dict<u32> = Default::default();
            for c in characters {
                let cid = c.character_count;
                c.action = IStrategyLibraryDispatcher {
                    class_hash: c.strategy
                }.determin_action();
                c.initiative = calculate_initiative(action, c.attributes.agility);
                sequence.insert(cid.into(), cid);
            }

            let mut active_character = characters.at(0);
            // bubble to sort characters by initiative
            let mut i: usize = 0;
            loop {
                i += 1;
                if i > character_count{
                    break;
                }
                let mut j: usize = 0;
                loop {
                    j += 1;
                    if j > character_count - i {
                        break;
                    }
                    if characters.at(sequence.get(j.into()) - 1).initiative > characters.at(sequence.get((j+1).into()) - 1).initiative {
                        let temp = sequence.get(j.into());
                        sequence.insert(j.into(), sequence.get((j+1).into()));
                        sequence.insert((j+1).into(), temp);
                    }
                };
            };

            for sid in 1..character_count+1 {
                let cid = sequence.get(sid.into());
                let mut c = characters.at(cid - 1);
                execute_action();
            };
            
            loop {
                i = 0;
                let mut winner_count = 0;
                loop {
                    i += 1;
                    if i > character_count / 2 {
                        break;
                    }
                    let c1 = characters.pop_front().unwrap();
                    let c2 = characters.pop_front().unwrap();
                    let (winner, logs) = self.battle(c1, c2);

                    emit!(world, BattleLog { arena_id: arena_id, logs: logs });

                    characters.append(winner);
                    winner_count += 1;
                };
                if winner_count == 1 {
                    break;
                }
                character_count = winner_count;
            };

            // winner is of ArenaCharacter
            let mut winner = characters.pop_front().unwrap();

            arena.winner = winner.character_owner;

            let mut character_info = get!(world, winner.character_owner, CharacterInfo);
            character_info.experience += get_gain_xp(character_info.level);

            set!(world, (arena, character_info, winner));
        }

        fn get_number_of_players(ref world: IWorldDispatcher, arena_id: u32) -> u32 {
            let world = self.world_dispatcher.read();
            let mut counter = get!(world, COUNTER_ID, ArenaCounter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let arena = get!(world, arena_id, Arena);
            arena.character_count
        }
    }
}

