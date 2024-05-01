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
    zkLendMarketMock, IzkLendMarketDispatcher,IzkLendMarketDispatcherTrait,
};
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use cairo_loto_poc::testing_utils::constants::{TOKEN_1, TOKEN_2, TOKEN_3, TOKENS_LEN,
    TEN_WITH_6_DECIMALS, ETH_ADDRS, SOME_ERC20, COIN, fake_ERC20_asset, ZKLEND_MKT_ADDRS,
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
// Setup
//

fn light_setup_erc20_address(recipient: ContractAddress) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(SOME_ERC20());
    calldata.append_serde(COIN());
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(recipient);

    let address = utils::deploy(SnakeERC20Mock::TEST_CLASS_HASH, calldata);
    address
}

fn full_setup_erc20_address(
    name: ByteArray, symbol: ByteArray, recipient: ContractAddress
) -> ContractAddress {
    let mut calldata = array![];
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(recipient);

    let address = utils::deploy(SnakeERC20Mock::TEST_CLASS_HASH, calldata);
    address
}

fn setup_erc20_dispatcher(
    token_address: ContractAddress, recipient: ContractAddress
) -> IERC20Dispatcher {
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };

    utils::drop_events(erc20_dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);

    erc20_dispatcher
}

fn ticket_dispatcher_with_event(erc20_addrs: ContractAddress) -> TicketsHandlerABIDispatcher {
    let mut calldata = array![];
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];

    // Set caller as `OWNER`
    testing::set_contract_address(OWNER());

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(OWNER());
    calldata.append_serde(erc20_addrs);
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(ZKLEND_MKT_ADDRS());

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn ticket_dispatcher_with_event_bis(batch_mint_IDs: Array<u256>, erc20_addrs: ContractAddress, zklend_mkt_addrs: ContractAddress,) -> TicketsHandlerABIDispatcher {
    let mut calldata = array![];

    // Set caller as `OWNER`
    testing::set_contract_address(OWNER());

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(batch_mint_IDs);
    calldata.append_serde(OWNER());
    calldata.append_serde(erc20_addrs);
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(zklend_mkt_addrs);

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn setup_ticket_dispatcher(erc20_addrs: ContractAddress) -> TicketsHandlerABIDispatcher {
    let dispatcher = ticket_dispatcher_with_event(erc20_addrs);
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}

fn setup_max() -> TicketsHandlerABIDispatcher {
    let mut calldata = array![];
    let mut token_ids: Array<u256> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // Set caller as `OWNER`
    testing::set_contract_address(OWNER());

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(OWNER());
    calldata.append_serde(fake_ERC20_asset());
    calldata.append_serde(TEN_WITH_6_DECIMALS);

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    let dispatcher = TicketsHandlerABIDispatcher { contract_address: address };
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}


// #############################################################################

//
// TEST PRIVATE/INTERNAL FUNCTIONS
//

//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//! I DID NOT MANAGE TO TEST THIS FUNCTION USING THE "contract_state_for_testing()" METHOD,
//! LET'S TRY TO MAKE IT AN INTEGRATION TEST WHICH ACTUALLY DEPLOYS EACH REQUIRED CONTRACT
// #[test]
// fn test__deposit_on_zkLend() {
//     //step 1
//     // deployer un ERC20Mock = "token A" et donner la supply à "OWNER"
//     let underlying_erc20_addrs = full_setup_erc20_address("USDC contract", "USDC", OWNER());
//     let token_A_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());
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
//     let token_B_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());

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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());
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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());

    let batch_mint_IDs: Array<u256> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(batch_mint_IDs, underlying_erc20_addrs, ZKLEND_MKT_ADDRS());

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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());

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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());

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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OWNER());

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
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs, OTHER());

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
