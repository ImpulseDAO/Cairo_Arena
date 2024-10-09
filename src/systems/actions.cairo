use dojo_arena::models::Arena::{CharacterState, BattleAction, ArenaCharacter, SetTier};
use dojo_arena::models::Character::{CharacterAttributes};
use starknet::ClassHash;

#[dojo::interface]
trait IActions {
    fn createCharacter(
        ref world: IWorldDispatcher,
        name: felt252,
        attributes: CharacterAttributes,
        strategy: ClassHash
    );
    fn createArena(ref world: IWorldDispatcher, name: felt252, current_tier: SetTier);
    fn register(ref world: IWorldDispatcher, arena_id: u32);
    fn level_up(ref world: IWorldDispatcher);
    fn assign_points(
        ref world: IWorldDispatcher, strength: u32, agility: u32, vitality: u32, stamina: u32
    );
    fn update_strategy(ref world: IWorldDispatcher, strategy: ClassHash);
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

    use dojo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, ArenaRegistered, SetTier, CharacterState, BattleAction
    };
    use dojo_arena::models::Character::{CharacterInfo, CharacterAttributes};

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

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn createCharacter(
            ref world: IWorldDispatcher,
            name: felt252,
            attributes: CharacterAttributes,
            strategy: ClassHash
        ) {
            let player = get_caller_address();

            assert(name != '', 'name cannot be empty');

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

            set!(
                world,
                (
                    CharacterInfo {
                        player,
                        name,
                        attributes,
                        strategy,
                        level: 0,
                        experience: 0,
                        points: 0,
                        golds: 0,
                        idle: true,
                    },
                )
            );
        }

        fn createArena(ref world: IWorldDispatcher, name: felt252, current_tier: SetTier) {
            let player = get_caller_address();

            let mut counter = get!(world, COUNTER_ID, ArenaCounter);
            counter.arena_count += 1;

            let arena = Arena {
                id: counter.arena_count,
                player,
                name,
                current_tier,
                character_count: 0,
                winner: contract_address_const::<0>(),
                is_closed: false,
            };

            set!(world, (arena, counter));
        }

        fn register(ref world: IWorldDispatcher, arena_id: u32) {
            let player = get_caller_address();

            let counter = get!(world, COUNTER_ID, ArenaCounter);
            assert(arena_id > 0 && arena_id <= counter.arena_count, 'Arena does not exist');

            let mut arena = get!(world, arena_id, (Arena));
            assert(!arena.is_closed, 'Arena is closed');
            assert(arena.character_count < 6, 'Arena is full');
            arena.character_count += 1;

            let character_info = get!(world, player, CharacterInfo);
            assert(character_info.name != '', 'Character does not exist');
            assert(character_info.idle, 'Character is not idle');

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
                attributes: character_info.attributes,
                character_owner: player,
                strategy: character_info.strategy,
            };

            set!(world, (arena, character, registered));
        }

        fn level_up(ref world: IWorldDispatcher) {
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
            let player = get_caller_address();

            // TODO: Consume XP / Experience Points to enable updates

            let mut character_info = get!(world, player, CharacterInfo);
            character_info.strategy = strategy;

            set!(world, (character_info));
        }
    }
}

