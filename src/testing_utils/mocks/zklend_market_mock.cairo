use starknet::ContractAddress;

#[starknet::interface]
trait IzkLendMarket<TState> {
    fn set_proof_of_deposit_token(ref self: TState, token: ContractAddress);
    fn get_proof_of_deposit_token(self: @TState) -> ContractAddress;

    fn deposit(ref self: TState, token: ContractAddress, amount: felt252);
    // fn withdraw(ref self: TState, token: ContractAddress, amount: felt252);

    fn get_deposit_value_of(self: @TState, user: ContractAddress) -> u256;
}


#[starknet::contract]
mod zkLendMarketMock {
    // use super::IzkLendMarket;
    use super::{IzkLendMarket, IzkLendMarketDispatcher, IzkLendMarketDispatcherTrait};
    use cairo_loto_poc::testing_utils::constants::{random_ERC20_token,};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait,};
    use starknet::{ContractAddress, get_caller_address, get_contract_address,};


    #[storage]
    struct Storage {
        deposit_value: LegacyMap::<ContractAddress, u256>,
        proof_of_deposit_token_addrs: ContractAddress,
    }


    #[external(v0)]
    fn get_deposit_value_of(self: @ContractState, user: ContractAddress) -> u256 {
        self.deposit_value.read(user)
    }

    #[external(v0)]
    fn get_proof_of_deposit_token(self: @ContractState) -> ContractAddress {
        self.proof_of_deposit_token_addrs.read()
    }

    #[external(v0)]
    fn set_proof_of_deposit_token(ref self: ContractState, token: ContractAddress) {
        self.proof_of_deposit_token_addrs.write(token);
    }


    #[external(v0)]
    fn deposit(ref self: ContractState, token: ContractAddress, amount: felt252) {
        // Send `amount` of `erc20_token` from the caller to this contract
        // (caller must have "approved" this contract beforehand)
        let caller = get_caller_address();
        let underlying_asset_dispatcher = IERC20Dispatcher { contract_address: token };
        //? zkLend's contract uses felt252 (not u256) to manage amounts.
        let u256_amount: u256 = amount.into();
        underlying_asset_dispatcher.transfer_from(caller, get_contract_address(), u256_amount);

        // Send `amount` of `zkLend_proof_of_deposit` from this contract to the caller
        let proof_of_deposit_token = self.proof_of_deposit_token_addrs.read();
        let zklend_PoD_erc20_dispatcher = IERC20Dispatcher {
            contract_address: proof_of_deposit_token
        };
        zklend_PoD_erc20_dispatcher.transfer(caller, u256_amount);

        // Update Storage state with the amount of the caller's deposit
        self.deposit_value.write(caller, u256_amount);
    }
}
