use starknet::ContractAddress;

#[starknet::interface]
pub trait ICairoLotoTicket<TContractState> {
    fn underlying_erc20_asset(self: @TContractState) -> ContractAddress;
    fn ticket_value(self: @TContractState) -> u256;
    fn circulating_supply(self: @TContractState) -> u256;
    fn total_tickets_emitted(self: @TContractState) -> u256;
}

#[starknet::component]
pub mod CairoLotoTicketComponent {
    use super::ICairoLotoTicket;
    use starknet::ContractAddress;


    #[storage]
    struct Storage {
        underlying_asset: ContractAddress,
        value: u256,
        current_supply: u256,
        total_supply: u256,
    }


    //
    // External/Public functions
    //
    #[embeddable_as(TicketExternals)]
    impl CairoLotoTicketImpl<
        TContractState, +HasComponent<TContractState>
    // > of super::ICairoLotoTicket<ComponentState<TContractState>> {
    > of ICairoLotoTicket<ComponentState<TContractState>> {
        fn underlying_erc20_asset(self: @ComponentState<TContractState>) -> ContractAddress {
            self.underlying_asset.read()
        }
        fn ticket_value(self: @ComponentState<TContractState>) -> u256 {
            self.value.read()
        }
        fn circulating_supply(self: @ComponentState<TContractState>) -> u256 {
            self.current_supply.read()
        }
        fn total_tickets_emitted(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply.read()
        }
    }


    //
    // Internal/Private functions
    //
    #[generate_trait]
    impl TicketInternalImpl<
        TContractState, +HasComponent<TContractState>
    > of TicketInternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>, asset: ContractAddress, ticket_value: u256,
        ) {
            self.underlying_asset.write(asset);
            self.value.write(ticket_value);
        }

        fn _underlying_erc20_asset(self: @ComponentState<TContractState>) -> ContractAddress {
            self.underlying_asset.read()
        }

        fn _ticket_value(self: @ComponentState<TContractState>) -> u256 {
            self.value.read()
        }

        // Current/circulating Supply
        fn _circulating_supply(self: @ComponentState<TContractState>) -> u256 {
            self.current_supply.read()
        }

        fn _increase_circulating_supply(ref self: ComponentState<TContractState>) {
            // self.current_supply.write(self.circulating_supply() + 1); //? DOES NOT WORK = variant 1 (using public/external function).
            self
                .current_supply
                .write(self._circulating_supply() + 1); //? variant 2 - using private method.
        // self.current_supply.write(self.current_supply.read() + 1); //? variant 3 - using: `self.<storage_value>.read()`.
        //? WHICH VARIANT IS USING THE LEAST AMOUNT OF GAS???
        }

        fn _decrease_circulating_supply(ref self: ComponentState<TContractState>) {
            self
                .current_supply
                .write(self._circulating_supply() - 1); // variant 2 - using private method.
        }

        // Total Supply / Total tickets emitted
        fn _total_tickets_emitted(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply.read()
        }

        fn _increase_total_tickets_emitted(ref self: ComponentState<TContractState>) {
            self
                .total_supply
                .write(
                    self.total_supply.read() + 1
                ); // variant 3 - using: `self.<storage_value>.read()`.
        }
    }
}
