use dojo_arena::models::io::{CharacterState, BattleAction};

#[starknet::interface]
trait IStrategy<TContractState> {
    fn determin_action(
        self: @TContractState, my_state: CharacterState, opponent_state: CharacterState
    ) -> BattleAction;
}

#[starknet::contract]
mod Strategy {
    use starknet::get_caller_address;
    use starknet::ContractAddress;

    use super::{CharacterState, BattleAction};

    #[storage]
    struct Storage {}

    #[external(v0)]
    impl Strategy of super::IStrategy<ContractState> {
        fn determin_action(
            self: @ContractState, my_state: CharacterState, opponent_state: CharacterState
        ) -> BattleAction {
            // Your Strategy goes here
            BattleAction::Rest
        }
    }
}
