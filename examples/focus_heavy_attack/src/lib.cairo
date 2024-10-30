mod io;
mod constants;
use io::{ArenaCharacter, BattleAction, Direction};
use constants::{GRID_WIDTH, GRID_HEIGHT};

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, characters: Span<ArenaCharacter>, active_cid: u8
    ) -> (BattleAction, Direction);
}

#[starknet::contract]
mod Strategy {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use core::dict::Felt252Dict;

    use super::{ArenaCharacter, BattleAction, Direction};
    use super::{GRID_WIDTH, GRID_HEIGHT};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Strategy of super::IStrategy<ContractState> {
        fn determin_action(
            self: @ContractState, characters: Span<ArenaCharacter>, active_cid: u8
        ) -> (BattleAction, Direction) {
            // Your Strategy goes here
            // Get you own character
            let my_character = *characters.at(active_cid.into() - 1);
            let characters_number = characters.len();

            let mut arenaGrid: Felt252Dict<u8> = Default::default();
            let mut i: u32 = 0;
            while i < characters_number {
                let c = *characters.at(i);
                let grid = c.position.x + c.position.y * GRID_HEIGHT;
                arenaGrid.insert(grid.into(), c.cid);
                i += 1;
            };

            let mut action = BattleAction::HeavyAttack;
            let mut direction = Direction::Up;
            let mut will_attack = false;
            if my_character.energy < 1 {
                return (BattleAction::Rest, my_character.direction);
            }

            let mut target_grid = my_character.position.x
                    + (my_character.position.y + 1) * GRID_HEIGHT;
            if arenaGrid.get(target_grid.into()) != 0 {
                will_attack = true;
            }

            if !will_attack {
                direction = Direction::Right;
                target_grid = my_character.position.x + 1
                    + my_character.position.y * GRID_HEIGHT;
                if arenaGrid.get(target_grid.into()) != 0 {
                    will_attack = true;
                }
            }

            if !will_attack && my_character.position.y > 0 {
                direction = Direction::Down;
                target_grid = my_character.position.x
                    + (my_character.position.y - 1) * GRID_HEIGHT;
                if arenaGrid.get(target_grid.into()) != 0 {
                    will_attack = true;
                }
            }

            if !will_attack && my_character.position.x > 0 {
                direction = Direction::Left;
                target_grid = my_character.position.x - 1
                    + my_character.position.y * GRID_HEIGHT;
                if arenaGrid.get(target_grid.into()) != 0 {
                    will_attack = true;
                }
            }
            
            if !will_attack {
                if my_character.position.x < GRID_WIDTH - 1 {
                    direction = Direction::Right;
                } else if my_character.position.y < GRID_HEIGHT - 1 {
                    direction = Direction::Up;
                } else if my_character.position.x > 0{
                    direction = Direction::Left;
                } else {
                    direction = Direction::Down;
                }
                action = BattleAction::Move;
            }

            (action, direction)
        }
    }
}
