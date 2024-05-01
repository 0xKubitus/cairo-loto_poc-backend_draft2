use starknet::ContractAddress;

#[starknet::interface]
trait IzkLendMarket<TState> {
    fn get_deposit_value_of(self: @TState, user: ContractAddress) -> u256;

    fn deposit(ref self: TState, erc20_token: ContractAddress, amount: felt252);
// fn withdraw(ref self: TState, token: ContractAddress, amount: felt252);
}


#[starknet::contract]
mod zkLendMarketMock {
    use cairo_loto_poc::testing_utils::constants::{fake_ERC20_asset,};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait,};
    use starknet::{ContractAddress, get_caller_address, get_contract_address,};


    #[storage]
    struct Storage {
        deposit_value: LegacyMap::<ContractAddress, u256>,
    }


    #[external(v0)]
    fn get_deposit_value_of(self: @ContractState, user: ContractAddress) -> u256 {
        self.deposit_value.read(user)
    }

    fn deposit(ref self: ContractState, erc20_token: ContractAddress, amount: u256,) {
        // Send `amount` of `erc20_token` from the caller to this contract
        // (caller must have "approved" this contract beforehand)
        let caller = get_caller_address();
        let underlying_asset_dispatcher = IERC20Dispatcher { contract_address: erc20_token };
        underlying_asset_dispatcher.transfer_from(caller, get_contract_address(), amount);

        // Send `amount` of `zkLend_proof_of_deposit` from this contract to the caller
        let zklend_PoD_erc20_dispatcher = IERC20Dispatcher { contract_address: fake_ERC20_asset() };
        zklend_PoD_erc20_dispatcher.transfer(caller, amount);

        // Update Storage state with the amount of the caller's deposit
        self.deposit_value.write(caller, amount);
    }
}
