//
// MOCK CONTRACT
//
#[starknet::contract]
pub mod CairoLotoTicketMock {
    use cairo_loto_poc::interfaces::cairo_loto_ticket::ICairoLotoTicket;
    use cairo_loto_poc::components::cairo_loto_ticket::CairoLotoTicket;
    use cairo_loto_poc::components::cairo_loto_ticket::CairoLotoTicket::TicketInternalTrait;
    // use cairo_loto_poc::testing_utils::utils;
    use cairo_loto_poc::testing_utils::constants::{TEN_WITH_6_DECIMALS, fake_ERC20_asset,};
    use starknet::ContractAddress;use starknet::{contract_address_const,};


    component!(path: CairoLotoTicket, storage: cairo_loto_ticket, event: TicketEvent);


    #[abi(embed_v0)]
    impl CairoLotoTicketImpl = CairoLotoTicket::TicketExternals<ContractState>; // CairoLotoTicketComponent External/Public functions
    impl TicketInternalImpl = CairoLotoTicket::TicketInternalImpl<ContractState>; // CairoLotoTicketComponent Internal/Private functions


    #[storage]
    struct Storage {
        #[substorage(v0)]
        cairo_loto_ticket: CairoLotoTicket::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TicketEvent: CairoLotoTicket::Event,
    }


    #[constructor]
    fn constructor(ref self: ContractState, underlying_asset: ContractAddress,) {
        // let asset: ContractAddress = fake_ERC20_asset();
        let ticket_value: u256 = TEN_WITH_6_DECIMALS;

        self.cairo_loto_ticket.initializer(underlying_asset, ticket_value);

        self.cairo_loto_ticket.current_supply.write(1); // only needed for testing
        self.cairo_loto_ticket.total_supply.write(3); // only needed for testing
    }


    // CairoLotoTicketComponent External/Public functions
    #[abi(embed_v0)]
    impl CairoLotoTicketImpl = CairoLotoTicket::TicketExternals<ContractState>;

    // CairoLotoTicketComponent Internal/Private functions
    impl TicketInternalImpl = CairoLotoTicket::TicketInternalImpl<ContractState>;
}
