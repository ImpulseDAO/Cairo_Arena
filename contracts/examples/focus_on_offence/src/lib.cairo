mod io;

use io::{CharacterState, BattleAction};

#[starknet::interface]
trait IBattleActionLibrary<TContractState> {
    fn determin_action(
        self: @TContractState, my_state: CharacterState, opponent_state: CharacterState
    ) -> BattleAction;
}

#[starknet::contract]
mod BattleActionLibrary {
    use starknet::get_caller_address;
    use starknet::ContractAddress;

    use super::io::{CharacterState, BattleAction};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl BattleActionLibrary of super::IBattleActionLibrary<ContractState> {
        fn determin_action(
            self: @ContractState, my_state: CharacterState, opponent_state: CharacterState
        ) -> BattleAction {
            // Your Strategy goes here
            BattleAction::QuickAttack
        }
    }
}
