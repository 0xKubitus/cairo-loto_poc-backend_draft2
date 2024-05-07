use cairo_loto_poc::tickets_handler::components::cairo_loto_ticket::CairoLotoTicketComponent::TicketInternalTrait;
use cairo_loto_poc::tickets_handler::tickets_handler::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler::tickets_handler::TicketsHandlerContract::{
    PrivateImpl, TicketsHandlerImpl,
};
use cairo_loto_poc::tickets_handler::interface::{
    TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,
};
use cairo_loto_poc::testing_utils::mocks::erc20_mock::SnakeERC20Mock;
use cairo_loto_poc::testing_utils::mocks::zklend_market_mock::{
    zkLendMarketMock, IzkLendMarketMockDispatcher, IzkLendMarketMockDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use cairo_loto_poc::testing_utils::{
    light_setup_erc20_address, full_setup_erc20_address, setup_erc20_dispatcher,
    ticket_dispatcher_with_event, ticket_dispatcher_with_event_bis, setup_ticket_dispatcher,
    setup_ticket_dispatcher_bis, setup_zkLend_market_mock_address,
    setup_zkLend_market_mock_dispatcher, setup_v04,
};
use cairo_loto_poc::testing_utils::constants::{
    TOKEN_1, TOKEN_2, TOKEN_3, TOKENS_LEN, TEN_WITH_6_DECIMALS, ETH_ADDRS, SOME_ERC20, COIN,
    random_ERC20_token, ZKLEND_MKT_ADDRS,
};
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, NAME, SYMBOL, BASE_URI,
};
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress,};


// #############################################################################

//
// Testing `tickets_handler_v03::TicketsHandlerImpl of ITicketsHandlerTrait` external/public functions
//

#[test]
fn test_mint() {
        let setup_data = setup_v04();
        
        let tickets_handler_dispatcher = setup_data.tickets_handler_disp;
        let underlying_erc20_dispatcher = setup_data.erc20_disp;
        assert_eq!(tickets_handler_dispatcher.ticket_value(), TEN_WITH_6_DECIMALS); // not mandatory
        assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not mandatory
    
        let tickets_handler = setup_data.tickets_handler_addrs;
        let amount = tickets_handler_dispatcher.ticket_value();
    
        underlying_erc20_dispatcher.approve(tickets_handler, amount);
        assert_eq!(underlying_erc20_dispatcher.balance_of(setup_data.zkLend_addrs), 0); // not mandatory
        assert_eq!(
            underlying_erc20_dispatcher.allowance(OWNER(), tickets_handler), TEN_WITH_6_DECIMALS
        ); // not mandatory
    
        // let ztoken = setup_data.zTOKEN_addrs; // is it required to declare this?
        let ztoken_dispatcher = setup_data.zTOKEN_disp;
        assert_eq!(ztoken_dispatcher.balance_of(tickets_handler), 0);

    setup_data.tickets_handler_disp.mint(OWNER());

    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 1);
    assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(setup_data.zkLend_addrs), TEN_WITH_6_DECIMALS);
    assert_eq!(ztoken_dispatcher.balance_of(tickets_handler), TEN_WITH_6_DECIMALS);
    
    // TODO: Control that the right event(s) are emitted?
}

#[test]
#[should_panic]
fn test_try_mint_11th_ticket() {
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    let batch_mint_IDs: Array<u256> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, underlying_erc20_addrs, ZKLEND_MKT_ADDRS()
    );

    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;
    let amount = tickets_handler_dispatcher.ticket_value();

    testing::set_caller_address(OWNER());

    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);

    // TEST PANICS HERE BECAUSE TICKET MAX LIMIT PER ACCOUNT = 10
    tickets_handler_dispatcher.mint(OWNER());
}

#[test]
#[should_panic]
fn test_try_mint_without_erc20_allowance() {
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());

    let batch_mint_IDs: Array<u256> = array![1, 2, 3,];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, underlying_erc20_addrs, ZKLEND_MKT_ADDRS(),
    );

    testing::set_caller_address(OWNER());

    // TEST PANICS HERE BECAUSE "OWNER" DID NOT APPROVE `tickets_handler_addrs` TO SPEND THEIR ERC20 TOKEN
    tickets_handler_dispatcher.mint(OWNER());
}

#[test]
#[should_panic]
fn test_try_mint_with_smaller_allowance() {
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    let batch_mint_IDs: Array<u256> = array![1, 2, 3,];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, underlying_erc20_addrs, ZKLEND_MKT_ADDRS(),
    );

    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;
    let amount = tickets_handler_dispatcher.ticket_value();

    testing::set_caller_address(OWNER());
    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount - 1);

    // TEST PANICS HERE BECAUSE "OWNER" DID NOT APPROVE `tickets_handler_addrs` TO SPEND THE RIGHT `amount` of ERC20 TOKEN
    tickets_handler_dispatcher.mint(OWNER());
}


#[test]
fn test_mint_and_burn() {
    //? =================================================================
    //? NEW MINT FUNCTION
    let setup_data = setup_v04();
        
    let tickets_handler_dispatcher = setup_data.tickets_handler_disp;
    let underlying_erc20_dispatcher = setup_data.erc20_disp;
    assert_eq!(tickets_handler_dispatcher.ticket_value(), TEN_WITH_6_DECIMALS); // not mandatory
    assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not mandatory

    let tickets_handler = setup_data.tickets_handler_addrs;
    let amount = tickets_handler_dispatcher.ticket_value();

    underlying_erc20_dispatcher.approve(tickets_handler, amount);
    assert_eq!(underlying_erc20_dispatcher.balance_of(setup_data.zkLend_addrs), 0); // not mandatory
    assert_eq!(
        underlying_erc20_dispatcher.allowance(OWNER(), tickets_handler), TEN_WITH_6_DECIMALS
    ); // not mandatory

    // let ztoken = setup_data.zTOKEN_addrs; // is it required to declare this?
    let ztoken_dispatcher = setup_data.zTOKEN_disp;
    assert_eq!(ztoken_dispatcher.balance_of(tickets_handler), 0);

    tickets_handler_dispatcher.mint(OWNER());

    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 1);
    assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(setup_data.zkLend_addrs), TEN_WITH_6_DECIMALS);
    assert_eq!(ztoken_dispatcher.balance_of(tickets_handler), TEN_WITH_6_DECIMALS);
    //? =================================================================    

    // TODO: fix method + implement verifications
    tickets_handler_dispatcher.burn(1, OWNER());

    // assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 0);
    // assert_eq!(tickets_handler_dispatcher.circulating_supply(), 0);
    // assert_eq!(tickets_handler_dispatcher.total_tickets_emitted(), 1);
    // assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler), 0);
    // assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS);
    // assert_eq!(ztoken_dispatcher.balance_of(tickets_handler), 0);
    //? =================================================================



    // ////////////////////////////////////////////////////////////////////////////
    // // OLD FUNCTION:
    // let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    // let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    // let tickets_handler_dispatcher = setup_ticket_dispatcher(underlying_erc20_addrs);
    // let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;
    // let amount = tickets_handler_dispatcher.ticket_value();

    // // testing::set_caller_address(OWNER()); // (NOTE FOR SELF: this one works as well)
    // testing::set_contract_address(OWNER());

    // // First, a ticket must be minted because TicketsHandlerContract does not own 
    // // any underlying asset at deployment (so it cant giveback a deposit that does not exist)
    // underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);
    // tickets_handler_dispatcher.mint(OWNER());
    // assert_eq!(
    //     underlying_erc20_dispatcher.balance_of(tickets_handler_addrs),
    //     tickets_handler_dispatcher.ticket_value()
    // ); // not needed
    

    // tickets_handler_dispatcher.burn(1, OWNER());
    // assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 3);
    // assert_eq!(tickets_handler_dispatcher.circulating_supply(), 3);
    // assert_eq!(tickets_handler_dispatcher.total_tickets_emitted(), 4);
    // // make sure that the ticketsHandler contract does not own
    // // anymore of the underlying asset after the "burn()" transaction
    // assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0);

// TODO: Control that the right event(s) are emitted

}

#[test]
#[should_panic]
fn test_try_burn_wrong_ticket() {
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    let tickets_handler_dispatcher = setup_ticket_dispatcher(underlying_erc20_addrs);
    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;
    let amount = tickets_handler_dispatcher.ticket_value();

    // testing::set_caller_address(OWNER()); // (NOTE FOR SELF: this one works as well)
    testing::set_contract_address(OWNER());

    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);
    tickets_handler_dispatcher.mint(OWNER());
    assert_eq!(
        underlying_erc20_dispatcher.balance_of(tickets_handler_addrs),
        tickets_handler_dispatcher.ticket_value()
    ); // not needed

    // TEST PANICS BECAUSE THE `token_id` IS NOT VALID (TICKET NOT MINTED)
    tickets_handler_dispatcher.burn(5, OWNER());
}


#[test]
#[should_panic]
fn test_try_burn_not_owner() {
    // Deploy an ERC20 contract that transfers the initial supply to "OTHER"
    let underlying_erc20_addrs = light_setup_erc20_address(OTHER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    // Deploy TicketsHandlerContract with ERC20 as the `underlying_asset` and mint 1 ticket to "OWNER"
    let batch_mint_IDs: Array<u256> = array![1, 2, 3];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, underlying_erc20_addrs, ZKLEND_MKT_ADDRS(),
    );
    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;

    // Use "OTHER" to perform the tests
    testing::set_caller_address(OTHER());

    // "OTHER" transfers its ERC20 tokens to the "tickets_handler" (necessary to do so
    // because I cannot deploy the "tickets_handler" without knowing the address
    // of the ERC20 contract, which itself needs to know the recipient address for the supply...)
    let amount = tickets_handler_dispatcher.ticket_value();
    underlying_erc20_dispatcher.transfer(tickets_handler_addrs, amount);

    // TEST PANICS BECAUSE "OTHER" IS NOT THE OWNER OF `token_id`
    assert_eq!(tickets_handler_dispatcher.owner_of(1), OWNER());
    tickets_handler_dispatcher.burn(1, OTHER());
}


////////////////////////////////////////////////////////////////////////////////
//! TESTING `testing_utils::setup_v04` TO BE DELETED
#[test]
fn test_setup_v04() {
    let setup_data = setup_v04();
    
    assert_eq!(setup_data.tickets_handler_disp.ticket_value(), TEN_WITH_6_DECIMALS); // not mandatory
    assert_eq!(setup_data.erc20_disp.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not mandatory

    let tickets_handler = setup_data.tickets_handler_addrs;
    let amount = setup_data.tickets_handler_disp.ticket_value();

    setup_data.erc20_disp.approve(tickets_handler, amount);

    assert_eq!(
        setup_data.erc20_disp.allowance(OWNER(), tickets_handler), TEN_WITH_6_DECIMALS
    ); // not mandatory
}
