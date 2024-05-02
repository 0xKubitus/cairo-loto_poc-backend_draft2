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
};
use cairo_loto_poc::testing_utils::constants::{
    TOKEN_1, TOKEN_2, TOKEN_3, TOKENS_LEN, TEN_WITH_6_DECIMALS, ETH_ADDRS, SOME_ERC20, COIN,
    fake_ERC20_asset, ZKLEND_MKT_ADDRS,
};
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, NAME, SYMBOL, BASE_URI,
};
use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress,};


// #############################################################################

// TO BE DELETED (because implemented in unit tests)

//
// TEST PRIVATE/INTERNAL FUNCTIONS
//

// #[test]
// fn test__deposit_on_zkLend() {
//     //step 1
//     // deployer un ERC20Mock = "token A" et donner la supply à "OWNER"
//     let underlying_erc20_addrs = full_setup_erc20_address("USDC contract", "USDC", OWNER());
//     let token_A_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);
//     // verifier deploiement
//     let owner_tokenA_balance_before = token_A_dispatcher.balance_of(OWNER());
//     assert_eq!(owner_tokenA_balance_before, TEN_WITH_6_DECIMALS);

//     //step 2
//     // deployer un zkLendMarketMock avec une fonction "deposit()"
//     let calldata: Array<felt252> = array![];
//     let zklend_market_addrs = utils::deploy(zkLendMarketMock::TEST_CLASS_HASH, calldata);
//     let zkLendMarketMock_dispatcher = IzkLendMarketDispatcher { contract_address: zklend_market_addrs };

//     //step 3
//     // deployer un 2eme ERC20Mock => fake zUSDC et donner la supply au zkLendMarketMock contrat
//     let zklend_PoD_token_addrs = full_setup_erc20_address( "zkLend USDC proof of deposit", "zUSDC", zklend_market_addrs );
//     let token_B_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

//     //step 4
//     // deployer tickets_handler
//     let batch_mint_IDs: Array<u256> = array![]; //? OPTION --> (checker si je peux faire en sorte de ne pas avoir de batch-mint au deploiement)
//     let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(batch_mint_IDs, underlying_erc20_addrs, zklend_market_addrs);
//     let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;

//     //? NOTE FOR SELF: I CANNOT USE THE BELOW LINE (PRIVATE FUNCTIONS SEEM NOT TO BE ACCESSIBLE THIS WAY)
//     //? tickets_handler_dispatcher._deposit_on_zkLend(underlying_erc20_addrs, TEN_WITH_6_DECIMALS); // => "Method `_deposit_on_zkLend` could not be called on type `cairo_loto_poc::tickets_handler::interface::TicketsHandlerABIDispatcher`".

//     // utiliser "set_contract_for_testing" avec tickets_handler pour tester la fonction interne `fn _deposit_on_zkLend()`
//     let mut state = TicketsHandlerContract::contract_state_for_testing();
//     //! AJOUTER L'ADDRESSE DU CONTRAT ZKLEND MARKET DANS UN 2ND INITIALIZER() CI-DESSOUS !!!
//     state.ticket.initializer(underlying_erc20_addrs, TEN_WITH_6_DECIMALS);

//     // noter le montant des depots de tickets_handler sur zklend market avant le depot
//     let deposit_value_before = zkLendMarketMock_dispatcher.get_deposit_value_of(tickets_handler_addrs);

//     // effectuer le depot sur zklend_market avec la fonction privée à tester
//     state._deposit_on_zkLend(TEN_WITH_6_DECIMALS);

//     // verifier que desormais tickets_handler ne possede plus aucun token_A

//     // verifier que desormais tickets_handler possede "TEN_WITH_6_DECIMALS" token_B

//     //! verifier que desormais zkLendMarketMock ne possede plus aucun token_B

//     //! verifier que desormais zkLendMarketMock possede "TEN_WITH_6_DECIMALS" token_A

// }
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

//
// Testing `tickets_handler_v03::TicketsHandlerImpl of ITicketsHandlerTrait` external/public functions
//

#[test]
fn test_mint() {
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);
    // NOTE FOR SELF: below line also works (".contract_address")
    // let underlying_erc20_addrs = underlying_erc20_dispatcher.contract_address;

    let tickets_handler_dispatcher = setup_ticket_dispatcher(underlying_erc20_addrs);
    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;

    let amount = tickets_handler_dispatcher.ticket_value();
    // assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), TOKENS_LEN); // not needed
    // assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not needed
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0);

    testing::set_contract_address(OWNER());
    // testing::set_caller_address(OWNER()); // this one works as well

    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);
    // assert_eq!(underlying_erc20_dispatcher.allowance(OWNER(), tickets_handler_addrs), TEN_WITH_6_DECIMALS); // not needed

    tickets_handler_dispatcher.mint(OWNER());
    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 4);
    assert_eq!(tickets_handler_dispatcher.owner_of(4), OWNER());
    assert_eq!(tickets_handler_dispatcher.circulating_supply(), 4);
    assert_eq!(tickets_handler_dispatcher.total_tickets_emitted(), 4);
    // make sure that now, ticketsHandler contract owns the value of 1 ticket in `underlying_erc20_asset`
    assert_eq!(
        underlying_erc20_dispatcher.balance_of(tickets_handler_addrs),
        tickets_handler_dispatcher.ticket_value()
    );
// TODO: Control that the right event(s) are emitted
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
    let underlying_erc20_addrs = light_setup_erc20_address(OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    let tickets_handler_dispatcher = setup_ticket_dispatcher(underlying_erc20_addrs);
    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;
    let amount = tickets_handler_dispatcher.ticket_value();

    // testing::set_caller_address(OWNER()); // (NOTE FOR SELF: this one works as well)
    testing::set_contract_address(OWNER());

    // First, a ticket must be minted because TicketsHandlerContract does not own 
    // any underlying asset at deployment (so it cant giveback a deposit that does not exist)
    underlying_erc20_dispatcher.approve(tickets_handler_addrs, amount);
    tickets_handler_dispatcher.mint(OWNER());
    assert_eq!(
        underlying_erc20_dispatcher.balance_of(tickets_handler_addrs),
        tickets_handler_dispatcher.ticket_value()
    ); // not needed

    tickets_handler_dispatcher.burn(1);
    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 3);
    assert_eq!(tickets_handler_dispatcher.circulating_supply(), 3);
    assert_eq!(tickets_handler_dispatcher.total_tickets_emitted(), 4);
    // make sure that the ticketsHandler contract does not own
    // anymore of the underlying asset after the "burn()" transaction
    assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0);
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
