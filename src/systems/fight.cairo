use dojo_arena::models::Arena::{CharacterState, BattleAction, ArenaCharacter, SetTier};
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
        self: @TContractState, my_state: CharacterState, opponent_state: CharacterState
    ) -> BattleAction;
}

#[dojo::contract]
mod fight_system {
    use super::{IActions};
    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};

    use dojo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, ArenaRegistered, SetTier, CharacterState, BattleAction
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
            assert(
                arena.character_count > 0 && arena.character_count % 2 == 0, 'Arena is not ready'
            );

            let mut characters = ArrayTrait::new();
            let mut i: usize = 0;
            loop {
                i += 1;
                if i > arena.character_count {
                    break;
                }
                let c = get!(world, (arena_id, i), ArenaCharacter);
                characters.append(c);
            };

            let mut character_count = arena.character_count;
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

        fn battle(c1: ArenaCharacter, c2: ArenaCharacter) -> (ArenaCharacter, Span<Span<u32>>) {
            let mut logs = ArrayTrait::new();

            let mut c1_state = CharacterState {
                hp: c1.hp, position: FIRST_POS, energy: c1.energy, consecutive_rest_count: 0,
            };

            let mut c2_state = CharacterState {
                hp: c2.hp, position: SECOND_POS, energy: c2.energy, consecutive_rest_count: 0,
            };

            let mut c1_initiative: u32 = 0;
            let mut c2_initiative: u32 = 0;
            let mut turns: u32 = 0;

            let mut winner = c1.clone();
            loop {
                if turns >= 25 {
                    if c1_state.hp <= c2_state.hp {
                        winner = c2;
                    }
                    break;
                }
                turns += 1;

                let mut c1_action: BattleAction = IStrategyLibraryDispatcher {
                    class_hash: c1.strategy
                }
                    .determin_action(c1_state, c2_state);

                let mut c2_action: BattleAction = IStrategyLibraryDispatcher {
                    class_hash: c2.strategy
                }
                    .determin_action(c2_state, c1_state);

                // let mut c1_action: BattleAction = determin_action(c1_state, c2_state);
                // let mut c2_action: BattleAction = determin_action(c2_state, c1_state);

                if c1_action == BattleAction::Rest {
                    c1_state.consecutive_rest_count += 1;
                } else {
                    c1_state.consecutive_rest_count = 0;
                }

                if c2_action == BattleAction::Rest {
                    c2_state.consecutive_rest_count += 1;
                } else {
                    c2_state.consecutive_rest_count = 0;
                }

                c1_initiative = calculate_initiative(c1_action, c1.attributes.agility);
                c2_initiative = calculate_initiative(c2_action, c2.attributes.agility);

                let mut is_c1_first: bool = true;

                if c1_initiative > c2_initiative {
                    is_c1_first = false;
                } else if c1_initiative == c2_initiative {
                    if c1.attributes.agility < c2.attributes.agility {
                        is_c1_first = false;
                    }
                }

                let mut arr = array![
                    turns,
                    c1_state.hp,
                    c2_state.hp,
                    c1_state.position,
                    c2_state.position,
                    c1_state.energy,
                    c2_state.energy,
                    mirror_ation_to_int(c1_action),
                    mirror_ation_to_int(c2_action),
                    c1_initiative,
                    c2_initiative
                ];
                logs.append(arr.span());

                if is_c1_first {
                    execute_action(c1_action, ref c1_state, ref c2_state, @c1, @c2);
                    if c2_state.hp == 0 {
                        break;
                    }
                    execute_action(c2_action, ref c2_state, ref c1_state, @c2, @c1);
                    if c1_state.hp == 0 {
                        winner = c2;
                        break;
                    }
                } else {
                    execute_action(c2_action, ref c2_state, ref c1_state, @c2, @c1);

                    if c1_state.hp == 0 {
                        winner = c2;
                        break;
                    }
                    execute_action(c1_action, ref c1_state, ref c2_state, @c1, @c2);
                    if c2_state.hp == 0 {
                        break;
                    }
                }
            };

            let mut arr = array![
                turns + 1,
                c1_state.hp,
                c2_state.hp,
                c1_state.position,
                c2_state.position,
                c1_state.energy,
                c2_state.energy,
                0,
                0,
                0,
                0
            ];
            logs.append(arr.span());

            (winner, logs.span())
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

