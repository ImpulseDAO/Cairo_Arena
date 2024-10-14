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

            let mut action = BattleAction::Move;
            if my_character.energy < 1 {
                return (BattleAction::Rest, my_character.direction);
            }

            let mut direction = Direction::Up;
            if my_character.position.y < GRID_HEIGHT - 1 {
                let new_grid = my_character.position.x
                    + (my_character.position.y + 1) * GRID_HEIGHT;
                if arenaGrid.get(new_grid.into()) != 0 {
                    direction = Direction::Right;
                }
            } else {
                direction = Direction::Right;
            }

            if direction == Direction::Right {
                if my_character.position.x < GRID_WIDTH - 1 {
                    let new_grid = my_character.position.x
                        + 1
                        + my_character.position.y * GRID_HEIGHT;
                    if arenaGrid.get(new_grid.into()) != 0 {
                        direction = Direction::Down;
                    }
                } else {
                    direction = Direction::Down;
                }
            }

            if direction == Direction::Down {
                if my_character.position.y > 0 {
                    let new_grid = my_character.position.x
                        + (my_character.position.y - 1) * GRID_HEIGHT;
                    if arenaGrid.get(new_grid.into()) != 0 {
                        direction = Direction::Left;
                    }
                } else {
                    direction = Direction::Left;
                }
            }

            if direction == Direction::Left {
                if my_character.position.x > 0 {
                    let new_grid = my_character.position.x
                        - 1
                        + my_character.position.y * GRID_HEIGHT;
                    if arenaGrid.get(new_grid.into()) != 0 {
                        direction = my_character.direction;
                        action = BattleAction::Rest;
                    }
                } else {
                    direction = my_character.direction;
                    action = BattleAction::Rest;
                }
            }

            (action, direction)
        }
    }
}
