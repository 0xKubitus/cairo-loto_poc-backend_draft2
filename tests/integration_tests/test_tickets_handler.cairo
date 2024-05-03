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
    zkLendMarketMock, IzkLendMarketDispatcher, IzkLendMarketDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use cairo_loto_poc::testing_utils::{
    light_setup_erc20_address, full_setup_erc20_address, setup_erc20_dispatcher,
    ticket_dispatcher_with_event, ticket_dispatcher_with_event_bis, setup_ticket_dispatcher,
    setup_ticket_dispatcher_bis, setup_zkLend_market_mock_address,
    setup_zkLend_market_mock_dispatcher,
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
    // STEP 1: zkLend market and the proof of deposit token
    // A: Deploy the zkLend market mock - without initializing the proof of deposit token address in storage during deployment.
    let zkLend_market_addrs = utils::deploy(zkLendMarketMock::TEST_CLASS_HASH, array![]);

    // B: Deploy the proof of deposit token - provide the supply to the zkLend market mock during deployment.
    // // let mut zkLend_calldata = array![];
    // // zkLend_calldata.append_serde("zkLend Market proof-of-deposit ERC20");
    // // zkLend_calldata.append_serde("zCOIN");
    // // zkLend_calldata.append_serde(TEN_WITH_6_DECIMALS);
    // // zkLend_calldata.append_serde(zkLend_market_addrs);

    // // let zTOKEN_addrs = 

    let proof_of_deposit_token_addrs = full_setup_erc20_address(
        "zkLend Market proof-of-deposit ERC20", "zCOIN", zkLend_market_addrs
    );
    let pod_token_dispatcher = setup_erc20_dispatcher(proof_of_deposit_token_addrs);

    // C: Register the proof of deposit token address in the storage of the zkLend market mock.
    let zkLend_market_dispatcher = IzkLendMarketDispatcher {
        contract_address: zkLend_market_addrs
    };
    zkLend_market_dispatcher.set_proof_of_deposit_token(proof_of_deposit_token_addrs);

    testing::set_contract_address(OWNER());

    // STEP 2: Tickets handler and underlying ERC20 token
    // A: Deploy an ERC20 mock contract for the underlying asset -> provide the initial supply to "OWNER".
    let underlying_erc20_addrs = full_setup_erc20_address("some ERC20 token", "COIN", OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    // B: Deploy the tickets handler contract -> define the underlying ERC20 token.
    let mut calldata = array![];
    let token_ids = ArrayTrait::<u256>::new().span();

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(OWNER());
    calldata.append_serde(underlying_erc20_addrs);
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(zkLend_market_addrs);

    let tickets_handler_addrs = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    let tickets_handler_dispatcher = TicketsHandlerABIDispatcher {
        contract_address: tickets_handler_addrs
    };

    let amount = tickets_handler_dispatcher.ticket_value();
    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 0); // not needed
    assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not needed
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0); // not needed

    // testing::set_contract_address(OWNER());

    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);

    assert_eq!(
        underlying_erc20_dispatcher.allowance(OWNER(), tickets_handler_addrs), TEN_WITH_6_DECIMALS
    ); // not needed
    assert_eq!(
        zkLend_market_addrs, tickets_handler_dispatcher.get_zkLend_market_address()
    ); // not mandatory + does not check if contract is deployed or not

    tickets_handler_dispatcher.mint(OWNER());

    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 1);
    assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0);
    assert_eq!(underlying_erc20_dispatcher.balance_of(zkLend_market_addrs), TEN_WITH_6_DECIMALS);
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
fn test_mint_and_burn() {// OLD FUNCTION:
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

// tickets_handler_dispatcher.burn(1);
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
    tickets_handler_dispatcher.burn(5);
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
    tickets_handler_dispatcher.burn(1);
}
