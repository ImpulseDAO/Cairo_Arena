use cairo_arena::models::Arena::{ArenaCharacter, BattleAction, Direction};

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

    use super::{ArenaCharacter, BattleAction, Direction};

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Strategy of super::IStrategy<ContractState> {
        fn determin_action(
            self: @ContractState, characters: Span<ArenaCharacter>, active_cid: u8
        ) -> (BattleAction, Direction) {
            // Your Strategy goes here
           (BattleAction::PreciseAttack, Direction::Up) 
        }
    }
}
