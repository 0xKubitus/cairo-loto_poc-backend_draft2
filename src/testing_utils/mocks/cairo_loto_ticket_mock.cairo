//
// MOCK CONTRACT
//
#[starknet::contract]
pub mod CairoLotoTicketMock {
    use cairo_loto_poc::tickets_handler::components::cairo_loto_ticket::{
        CairoLotoTicketComponent, ICairoLotoTicket,
    };
    use cairo_loto_poc::tickets_handler::components::cairo_loto_ticket::CairoLotoTicketComponent::TicketInternalTrait;
    // use cairo_loto_poc::testing_utils;
    use cairo_loto_poc::testing_utils::constants::{TEN_WITH_6_DECIMALS, fake_ERC20_asset,};
    use starknet::ContractAddress;
    use starknet::{contract_address_const,};


    component!(path: CairoLotoTicketComponent, storage: cairo_loto_ticket, event: TicketEvent);


    // Implementing CairoLotoTicketComponent's external/public functions
    #[abi(embed_v0)]
    impl CairoLotoTicketImpl =
        CairoLotoTicketComponent::TicketExternals<
            ContractState
        >; // CairoLotoTicketComponent External/Public functions
    // Implementing CairoLotoTicketComponent's internal/private methods
    impl TicketInternalImpl =
        CairoLotoTicketComponent::TicketInternalImpl<
            ContractState
        >; // CairoLotoTicketComponent Internal/Private functions


    #[storage]
    struct Storage {
        #[substorage(v0)]
        cairo_loto_ticket: CairoLotoTicketComponent::Storage,
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TicketEvent: CairoLotoTicketComponent::Event,
    }


    #[constructor]
    fn constructor(ref self: ContractState, underlying_asset: ContractAddress,) {
        // let asset: ContractAddress = fake_ERC20_asset();
        let ticket_value: u256 = TEN_WITH_6_DECIMALS;

        self.cairo_loto_ticket.initializer(underlying_asset, ticket_value);

        self.cairo_loto_ticket.current_supply.write(1); // only needed for testing
        self.cairo_loto_ticket.total_supply.write(3); // only needed for testing
    }
}
