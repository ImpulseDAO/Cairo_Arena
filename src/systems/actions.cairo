use cairo_arena::models::Arena::{BattleAction, ArenaCharacter, SetTier, Side};
use cairo_arena::models::Character::{CharacterAttributes};
use starknet::ClassHash;

#[starknet::interface]
pub trait IActions<T> {
    fn createCharacter(
        ref self: T,
        name: felt252,
        attributes: CharacterAttributes,
        strategy: ClassHash
    );
    fn createArena(ref self: T, name: felt252);
    fn closeArena(ref self: T, arena_id: u32);
    fn register(ref self: T, arena_id: u32, side: Side);
    fn level_up(ref self: T);
    fn assign_points(
        ref self: T, strength: u8, agility: u8, vitality: u8, stamina: u8
    );
    fn update_strategy(ref self: T, strategy: ClassHash);
}

#[dojo::contract]
pub mod actions {
    use super::{IActions};

    use starknet::{ContractAddress, get_caller_address, ClassHash};
    use starknet::{contract_address_const, class_hash_const};

    use cairo_arena::models::Arena::{
        Arena, ArenaCounter, ArenaCharacter, ArenaRegistered, SetTier, BattleAction, Position, Direction, Side
    };
    use cairo_arena::models::Character::{CharacterInfo, CharacterAttributes};

    use cairo_arena::constants::{
        HP_MULTIPLIER, BASE_HP, ENERGY_MULTIPLIER, BASE_ENERGY, COUNTER_ID,
        MAX_LEVEL, MAX_STRENGTH, MAX_AGILITY, MAX_VITALITY, MAX_STAMINA,
        FIRST_POS, SECOND_POS, THIRD_POS, FOURTH_POS, FIFTH_POS, SIXTH_POS,
        TIE, RED, BLUE
    };

    use cairo_arena::utils::{
        calculate_initiative, execute_action, get_gain_xp, get_level_xp
    };

    use dojo::model::{ModelStorage, ModelValueStorage};

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn createCharacter(
            ref self: ContractState,
            name: felt252,
            attributes: CharacterAttributes,
            strategy: ClassHash
        ) {
            let mut world = self.world(@"arena");

            let player = get_caller_address();

            let character_info: CharacterInfo = world.read_model(player);
            assert(character_info.name == '', 'Character already exists');

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

            let new_character_info = CharacterInfo {
                player,
                name,
                attributes,
                strategy,
                level: 0,
                experience: 0,
                points: 0,
                golds: 0,
            };
            world.write_model(@new_character_info);
        }

        fn createArena(ref self: ContractState, name: felt252) {
            let mut world = self.world(@"arena");

            let player = get_caller_address();

            let character_info: CharacterInfo = world.read_model(player);
            assert(character_info.name != '', 'Character does not exist');

            let current_tier = match character_info.level {
                0 => SetTier::Tier5,
                1 => SetTier::Tier4,
                2 | 3 | 4 => SetTier::Tier3,
                5 | 6 | 7| 8 => SetTier::Tier2,
                _ => SetTier::Tier1,
            };

            let mut counter: ArenaCounter = world.read_model(COUNTER_ID);
            counter.arena_count += 1;

            let arena = Arena {
                id: counter.arena_count,
                player,
                name,
                current_tier,
                characters_number: 1,
                winner: 0,
                is_closed: false,
                red_side_num: 1,
                blue_side_num: 0,
            };

            let hp = character_info.attributes.vitality.into() * HP_MULTIPLIER + BASE_HP;
            let energy = character_info.attributes.stamina.into() * ENERGY_MULTIPLIER + BASE_ENERGY;

            let (x, y): (u8, u8) = FIRST_POS;
            let position = Position { x, y };

            let character = ArenaCharacter {
                arena_id: arena.id,
                cid: arena.characters_number,
                name: character_info.name,
                level: character_info.level,
                hp,
                energy,
                attributes: character_info.attributes,
                character_owner: player,
                strategy: character_info.strategy,
                position,
                direction: Direction::Right,
                action: BattleAction::Rest,
                initiative: 0,
                consecutive_rest_count: 0,
                side: Side::Red,
            };

            let mut registered: ArenaRegistered = world.read_model((arena.id, player));
            registered.registered = true;

            world.write_model(@arena);
            world.write_model(@character);
            world.write_model(@registered);
            world.write_model(@counter);
        }

        fn closeArena(ref self: ContractState, arena_id: u32) {
            let mut world = self.world(@"arena");

            // let player = get_caller_address();

            let mut counter: ArenaCounter = world.read_model(COUNTER_ID);
            assert(arena_id > 0 && arena_id <= counter.arena_count, 'Arena does not exist');

            let mut arena: Arena = world.read_model(arena_id);
            // assert(arena.player == player, 'Only arena creator can close');
            assert(!arena.is_closed, 'Arena is already closed');
            assert(arena.winner != 0, 'Not ready to be closed');

            if arena.winner != TIE {
                let mut characters_number = arena.characters_number;
                let mut i = 0;
                while i < characters_number {
                    i += 1;
                    let c: ArenaCharacter = world.read_model((arena_id, i));

                    let side = match c.side {
                        Side::Red => RED,
                        Side::Blue => BLUE,
                    };
                    if side == arena.winner {
                        let mut character_info: CharacterInfo = world.read_model(c.character_owner);
                        character_info.golds += 2000;
                        character_info.experience += get_gain_xp(character_info.level);
                        world.write_model(@character_info);
                    }
                };
            }

            arena.is_closed = true;
            world.write_model(@arena);
        }

        fn register(ref self: ContractState, arena_id: u32, side: Side) {
            let mut world = self.world(@"arena");

            let player = get_caller_address();

            let counter: ArenaCounter = world.read_model(COUNTER_ID);
            assert(arena_id > 0 && arena_id <= counter.arena_count, 'Arena does not exist');

            let mut arena: Arena = world.read_model(arena_id);
            assert(!arena.is_closed, 'Arena is closed');

            let character_info: CharacterInfo = world.read_model(player);
            assert(character_info.name != '', 'Character does not exist');

            let mut registered: ArenaRegistered = world.read_model((arena_id, player));
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

            assert(arena.characters_number < 6, 'Arena is full');

            let (mut x, mut y, mut direction): (u8, u8, Direction) = (0, 0, Direction::Up);
            match side {
                Side::Red => {
                    assert(arena.red_side_num < 3, 'Red side is full');
                    arena.red_side_num += 1;
                    let (px, py) = match arena.red_side_num {
                        0 => (0, 0),
                        1 => FIRST_POS,
                        2 => SECOND_POS,
                        3 => THIRD_POS,
                        _ => (0, 0),
                    };
                    x = px;
                    y = py;

                    direction = Direction::Right;
                },
                Side::Blue => {
                    assert(arena.blue_side_num < 3, 'Blue side is full');
                    arena.blue_side_num += 1;
                    let (px, py) = match arena.blue_side_num {
                        0 => (0, 0),
                        1 => FOURTH_POS,
                        2 => FIFTH_POS,
                        3 => SIXTH_POS,
                        _ => (0, 0),
                    };
                    x = px;
                    y = py;
                    
                    direction = Direction::Left;
                },
            }
            arena.characters_number += 1;


            let hp = character_info.attributes.vitality.into() * HP_MULTIPLIER + BASE_HP;
            let energy = character_info.attributes.stamina.into() * ENERGY_MULTIPLIER + BASE_ENERGY;

            let position = Position { x, y };

            let character = ArenaCharacter {
                arena_id: arena.id,
                cid: arena.characters_number,
                name: character_info.name,
                level: character_info.level,
                hp,
                energy,
                attributes: character_info.attributes,
                character_owner: player,
                strategy: character_info.strategy,
                position,
                direction,
                action: BattleAction::Rest,
                initiative: 0,
                consecutive_rest_count: 0,
                side,
            };

            world.write_model(@arena);
            world.write_model(@character);
            world.write_model(@registered);
        }

        fn level_up(ref self: ContractState) {
            let mut world = self.world(@"arena");

            let player = get_caller_address();

            let mut character_info: CharacterInfo = world.read_model(player);
            assert(character_info.level < MAX_LEVEL, 'Max level reached');

            let level_xp = get_level_xp(character_info.level);
            assert(character_info.experience >= level_xp, 'Not enough experience');

            character_info.experience -= level_xp;
            character_info.level += 1;
            character_info.points += 1;

            world.write_model(@character_info);
        }

        fn assign_points(
            ref self: ContractState, strength: u8, agility: u8, vitality: u8, stamina: u8
        ) {
            let mut world = self.world(@"arena");
            
            let player = get_caller_address();

            let mut character_info: CharacterInfo = world.read_model(player);
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

            world.write_model(@character_info);
        }

        fn update_strategy(ref self: ContractState, strategy: ClassHash) {
            let mut world = self.world(@"arena");

            let player = get_caller_address();

            // TODO: Consume XP / Experience Points to enable updates
            let mut character_info: CharacterInfo = world.read_model(player);
            character_info.strategy = strategy;

            world.write_model(@character_info);
        }
    }
}

