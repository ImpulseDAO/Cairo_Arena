#[dojo::interface]
trait IActions {
    fn createCharacter(
        ref self: TContractState, name: felt252, attributes: InitialAttributes, strategy: ClassHash
    );
    fn createArena(ref world: IWorldDispatcher, name: felt252, current_tier: SetTier);
    fn closeArena(ref world: IWorldDispatcher, arena_id: u32);
    fn register(ref world: IWorldDispatcher, arena_id: u32);
    fn play(ref world: IWorldDispatcher, arena_id: u32);
    fn level_up(ref world: IWorldDispatcher);
    fn assign_points(
        ref world: IWorldDispatcher, strength: u32, agility: u32, vitality: u32, stamina: u32
    );
    fn update_strategy(ref world: IWorldDispatcher, strategy: ClassHash);
    fn battle(
        ref world: IWorldDispatcher, c1: ArenaCharacter, c2: ArenaCharacter
    ) -> (ArenaCharacter, Span<Span<u32>>);
    fn get_number_of_players(ref world: IWorldDispatcher, arena_id: u32) -> u32;
}

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, my_state: CharacterState, opponent_state: CharacterState
    ) -> BattleAction;
}

#[dojo::contract]
mod actions {
    use super::{IActions};
    use super::{IStrategyDispatcherTrait, IStrategyLibraryDispatcher};

    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};

    use dojo_arena::models::io::{
        InitialAttributes, CharacterAttributes, SetTier, CharacterState, BattleAction
    };
    use dojo_arena::models::models::{
        CharacterInfo, Arena, Counter, ArenaCharacter, ArenaRegistered
    };
    use dojo_arena::models::io::{
        InitialAttributes, CharacterAttributes, SetTier, BattleAction, CharacterState, Direction
    };

    use dojo_arena::constants::{
        HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY, COUNTER_ID, FIRST_POS, SECOND_POS,
        RANGE_POS, MAX_TURNS, QUICK_ATC_ENERGY, PRECISE_ATC_ENERGY, HEAVY_ATC_ENERGY,
        QUICK_ATC_DAMAGE, PRECISE_ATC_DAMAGE, HEAVY_ATC_DAMAGE, AGI_INITIATIVE_MODIFIER,
        QUICK_ATC_INI, PRECISE_ATC_INI, HEAVY_ATC_INI, MOVE_INI, REST_INI, QUICK_HIT_CHANCE,
        PRECISE_HIT_CHANCE, HEAVY_HIT_CHANCE, REST_RECOVERY, MAX_LEVEL, MAX_STRENGTH, MAX_AGILITY,
        MAX_VITALITY, MAX_STAMINA
    };

    use dojo_arena::utils::{
        new_pos_and_hit, new_pos_and_steps, calculate_initiative, execute_action, get_gain_xp,
        get_level_xp, mirror_ation_to_int
    };

    use debug::PrintTrait;

    #[derive(Copy, Drop, Serde)]
    #[dojo::model]
    #[dojo::event]
    struct BattleLog {
        #[key]
        arena_id: u32,
        logs: Span<Span<u32>>,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn createCharacter(
            ref world: IWorldDispatcher,
            name: felt252,
            attributes: InitialAttributes,
            strategy: ClassHash
        ) {
            let world = self.world_dispatcher.read();

            assert(
                attributes.strength
                    + attributes.agility
                    + attributes.vitality
                    + attributes.stamina == 5,
                'Attributes must sum 5'
            );

            let attributes = CharacterAttributes {
                strength: 1 + attributes.strength,
                agility: 1 + attributes.agility,
                vitality: 1 + attributes.vitality,
                stamina: 1 + attributes.stamina,
            };

            let owner = get_caller_address();

            set!(
                world,
                (
                    CharacterInfo {
                        owner,
                        name,
                        attributes,
                        strategy,
                        level: 0,
                        experience: 0,
                        points: 0,
                        golds: 0,
                    },
                )
            );
        }

        fn createArena(ref world: IWorldDispatcher, name: felt252, current_tier: SetTier) {
            let world = self.world_dispatcher.read();
            let owner = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            counter.arena_count += 1;

            let arena = Arena {
                id: counter.arena_count,
                owner,
                name,
                current_tier,
                character_count: 0,
                winner: contract_address_const::<0>(),
                total_golds: 5000,
                total_rating: 0,
                is_closed: false,
            };

            set!(world, (arena, counter));
        }

        fn closeArena(ref world: IWorldDispatcher, arena_id: u32) {
            let world = self.world_dispatcher.read();
            let owner = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, Arena);
            assert(arena.owner == owner, 'Only owner can close arena');
            assert(!arena.is_closed, 'Arena is already closed');

            arena.is_closed = true;

            let mut character_count = arena.character_count;
            let mut i = 0;
            loop {
                i += 1;
                let mut character = get!(world, (arena_id, i), ArenaCharacter);
                let rewards = character.rating * arena.total_golds / arena.total_rating;

                let mut character_info = get!(world, character.character_owner, CharacterInfo);
                character_info.golds += rewards;
                set!(world, (character_info));

                if i == character_count {
                    break;
                }
            };

            set!(world, (arena));
        }

        fn register(ref world: IWorldDispatcher, arena_id: u32) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let mut arena = get!(world, arena_id, (Arena));
            arena.character_count += 1;

            let character_info = get!(world, player, CharacterInfo);
            assert(character_info.name != '', 'Character does not exist');

            let mut registered = get!(world, (arena_id, player), ArenaRegistered);
            assert(!registered.registered, 'Character already registered');
            registered.registered = true;

            let (min, max) = match arena.current_tier {
                SetTier::Tier5 => (0, 0),
                SetTier::Tier4 => (1, 1),
                SetTier::Tier3 => (2, 4),
                SetTier::Tier2 => (5, 8),
                SetTier::Tier1 => (8, 255),
            };
            assert(
                character_info.level >= min && character_info.level <= max,
                'Character tier is not allowed'
            );

            let hp = character_info.attributes.vitality * HP_MULTIPLIER + BASE_HP;
            let energy = character_info.attributes.stamina * ENERGY_MULTIPLIER + BASE_ENERGY;

            let character = ArenaCharacter {
                arena_id: arena.id,
                character_count: arena.character_count,
                name: character_info.name,
                hp,
                energy,
                position: 0,
                attributes: character_info.attributes,
                character_owner: player,
                strategy: character_info.strategy,
                rating: 0,
            };

            set!(world, (arena, character, registered));
        }

        fn play(ref world: IWorldDispatcher, arena_id: u32) {
            let world = self.world_dispatcher.read();

            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

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

            winner.rating += get_gain_xp(character_info.level);
            arena.total_rating += get_gain_xp(character_info.level);
            set!(world, (arena, character_info, winner));
        }

        fn level_up(ref world: IWorldDispatcher) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut character_info = get!(world, player, CharacterInfo);
            assert(character_info.level < MAX_LEVEL, 'Max level reached');

            let level_xp = get_level_xp(character_info.level);
            assert(character_info.experience >= level_xp, 'Not enough experience');

            character_info.experience -= level_xp;
            character_info.level += 1;
            character_info.points += 1;

            set!(world, (character_info));
        }

        fn assign_points(
            ref world: IWorldDispatcher, strength: u32, agility: u32, vitality: u32, stamina: u32
        ) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            let mut character_info = get!(world, player, CharacterInfo);
            assert(strength + agility + vitality + stamina > 0, 'No points to assign');
            assert(
                character_info.points >= strength + agility + vitality + stamina,
                'Not enough points'
            );

            let mut attributes = character_info.attributes;

            attributes.strength += strength;
            attributes.agility += agility;
            attributes.vitality += vitality;
            attributes.stamina += stamina;

            assert(
                attributes.strength <= MAX_STRENGTH
                    && attributes.agility <= MAX_AGILITY
                    && attributes.vitality <= MAX_VITALITY
                    && attributes.stamina <= MAX_STAMINA,
                'Attributes are not allowed'
            );

            character_info.attributes = attributes;
            character_info.points -= 1;

            set!(world, (character_info));
        }

        fn update_strategy(ref world: IWorldDispatcher, strategy: ClassHash) {
            let world = self.world_dispatcher.read();
            let player = get_caller_address();

            // TODO: Consume XP / Experience Points to enable updates

            let mut character_info = get!(world, player, CharacterInfo);
            character_info.strategy = strategy;

            set!(world, (character_info));
        }

        fn battle(
            ref world: IWorldDispatcher, c1: ArenaCharacter, c2: ArenaCharacter
        ) -> (ArenaCharacter, Span<Span<u32>>) {
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
            let mut counter = get!(world, COUNTER_ID, Counter);
            assert(counter.arena_count >= arena_id && arena_id > 0, 'Arena does not exist');

            let arena = get!(world, arena_id, Arena);
            arena.character_count
        }
    }
}

