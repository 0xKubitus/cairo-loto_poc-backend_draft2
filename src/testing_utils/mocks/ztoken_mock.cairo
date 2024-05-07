use starknet::ContractAddress;

#[starknet::interface]
trait IzTOKENMock<TState> {
    fn mint(ref self: TState, user: ContractAddress, amount: u256);
    fn burn(ref self: TState, user: ContractAddress, amount: u256);
    
    //! TO BE DELETED:
    fn whatever(self: @TState) -> ByteArray;
}


#[starknet::contract]
mod zTOKENMock {
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        initial_supply: u256,
        recipient: ContractAddress
    ) {
        self.erc20.initializer(name, symbol);
    // self.erc20._mint(recipient, initial_supply); // not needed for proof-of-deposit tokens
    }

    #[external(v0)]
    fn mint(ref self: ContractState, user: ContractAddress, amount: u256) {
        self.erc20._mint(user, amount);
    }

    #[external(v0)]
    fn burn(ref self: ContractState, user: ContractAddress, amount: u256) {
        self.erc20._burn(user, amount);
    }


    //! TO BE DELETED:
    fn whatever(self: @ContractState) -> ByteArray {
        "whatever"
    }
}
