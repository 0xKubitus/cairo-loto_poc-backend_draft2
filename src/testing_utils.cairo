mod access;
mod mocks;
mod constants;
mod presets;
mod token;
mod upgrades;


////////////////////////////////

use cairo_loto_poc::tickets_handler::tickets_handler::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler::interface::{
    TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,
};
use cairo_loto_poc::testing_utils::mocks::zklend_market_mock::{
    zkLendMarketMock, IzkLendMarketMockDispatcher, IzkLendMarketMockDispatcherTrait,
};
use cairo_loto_poc::testing_utils::constants::{
    TOKEN_1, TOKEN_2, TOKEN_3, TOKENS_LEN, NONEXISTENT, TEN_WITH_6_DECIMALS, ETH_ADDRS,
    ZKLEND_MKT_ADDRS, SOME_ERC20, COIN,
};
use cairo_loto_poc::testing_utils::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use cairo_loto_poc::testing_utils::mocks::erc20_mock::SnakeERC20Mock;
use cairo_loto_poc::testing_utils::mocks::erc721_mocks::SnakeERC721Mock;
use cairo_loto_poc::testing_utils::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, SnakeERC721ReceiverMock
};

use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::tests::utils::constants::{OWNER, NAME, SYMBOL, BASE_URI, PUBKEY, // ZERO, 
// DATA, 
// SPENDER, 
// RECIPIENT, 
// OTHER, 
// OPERATOR, 
// CLASS_HASH_ZERO, 
};

// use starknet::SyscallResultTrait;
use starknet::{testing, ContractAddress,};

////////////////////////////////

//? NOTES FOR SELF:
//?
//? NBER 1 = There might be too many setup functions in 'testing_utils.cairo':
//?          maybe I should make more generic/reusable functions?
//?
//? NBER 2 = Also, I should maybe group unit tests setup functions into their own "Impl",
//?          and do the same for integration tests setup functions and then
//?          import the relevant Trait & Impl into each test file? (rather than separately
//?          importing each function or importing this whole file for just a few functions)

//
// Unit tests Setup functions
//

fn setup_dispatcher_with_event() -> TicketsHandlerABIDispatcher {
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
    calldata.append_serde(ETH_ADDRS());
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(ZKLEND_MKT_ADDRS());

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> TicketsHandlerABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}

fn setup_dispatcher_with_event2() -> TicketsHandlerABIDispatcher {
    let mut calldata = array![];
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3];

    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(OWNER());
    calldata.append_serde(token_ids);
    calldata.append_serde(OWNER());
    calldata.append_serde(ETH_ADDRS());
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(ZKLEND_MKT_ADDRS());

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn setup_dispatcher2() -> TicketsHandlerABIDispatcher {
    let dispatcher = setup_dispatcher_with_event2();
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
    calldata.append_serde(ETH_ADDRS());
    calldata.append_serde(TEN_WITH_6_DECIMALS);

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    let dispatcher = TicketsHandlerABIDispatcher { contract_address: address };
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}

fn setup_receiver() -> ContractAddress {
    utils::deploy(SnakeERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_camel_receiver() -> ContractAddress {
    utils::deploy(CamelERC721ReceiverMock::TEST_CLASS_HASH, array![])
}

fn setup_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(DualCaseAccountMock::TEST_CLASS_HASH, calldata)
}

fn setup_camel_account() -> ContractAddress {
    let mut calldata = array![PUBKEY];
    utils::deploy(CamelAccountMock::TEST_CLASS_HASH, calldata)
}


//
// Integration tests Setup functions
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

fn setup_erc20_dispatcher(token_address: ContractAddress) -> IERC20Dispatcher {
    let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };

    //? there's probably something wrong below because I copy/pasted the process 
    //? for setting up an erc721 but erc20 constructor is different and does not use token_ids nor tokens_len...
    //? => I suppose dropping a single a event should be enough ->     utils::drop_events(erc20_dispatcher.contract_address, 1);
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

fn ticket_dispatcher_with_event_bis(
    batch_mint_IDs: Array<u256>, erc20_addrs: ContractAddress, zklend_mkt_addrs: ContractAddress,
) -> TicketsHandlerABIDispatcher {
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

fn setup_ticket_dispatcher_bis(
    batch_mint_IDs: Array<u256>, erc20_addrs: ContractAddress, zklend_mkt_addrs: ContractAddress,
) -> TicketsHandlerABIDispatcher {
    let dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, erc20_addrs, zklend_mkt_addrs
    );
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}

fn setup_zkLend_market_mock_address() -> ContractAddress {
    let no_calldata = array![];
    let zkLend_market_addrs = utils::deploy(zkLendMarketMock::TEST_CLASS_HASH, no_calldata);
    zkLend_market_addrs
}

fn setup_zkLend_market_mock_dispatcher(address: ContractAddress) -> IzkLendMarketMockDispatcher {
    let dispatcher = IzkLendMarketMockDispatcher { contract_address: address };
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(
        dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1
    ); //? most likely incorect? but is it even useful/necessary?
    dispatcher
}


// =============================================================================

// NEW SETUP FOR INTEGRATION TESTS Tickets Handler v0.4

#[derive(Drop)]
struct SetupData {
    zkLend_addrs: ContractAddress,
    zkLend_disp: IzkLendMarketMockDispatcher,
    zTOKEN_addrs: ContractAddress,
    zTOKEN_disp: IERC20Dispatcher,
    tickets_handler_addrs: ContractAddress,
    tickets_handler_disp: TicketsHandlerABIDispatcher,
    erc20_addrs: ContractAddress,
    erc20_disp: IERC20Dispatcher,
}

fn setup_v04() -> SetupData {
    let zkLend_market_addrs = utils::deploy(zkLendMarketMock::TEST_CLASS_HASH, array![]);

    //TODO: REWORK THIS USING zTOKEN Mock instead of ERC20
    //! ------------------------------------------------------------------------
    let proof_of_deposit_token_addrs = full_setup_erc20_address(
        "zkLend Market proof-of-deposit ERC20", "zCOIN", zkLend_market_addrs
    );
    let pod_token_dispatcher = setup_erc20_dispatcher(proof_of_deposit_token_addrs);
    //! ------------------------------------------------------------------------

    let zkLend_market_dispatcher = IzkLendMarketMockDispatcher {
        contract_address: zkLend_market_addrs
    };
    zkLend_market_dispatcher.set_proof_of_deposit_token(proof_of_deposit_token_addrs);

    testing::set_contract_address(OWNER());

    let underlying_erc20_addrs = full_setup_erc20_address("some ERC20 token", "COIN", OWNER());
    let underlying_erc20_dispatcher = setup_erc20_dispatcher(underlying_erc20_addrs);

    let batch_mint_IDs: Array<u256> = array![];
    let tickets_handler_dispatcher = ticket_dispatcher_with_event_bis(
        batch_mint_IDs, underlying_erc20_addrs, zkLend_market_addrs
    );
    let tickets_handler_addrs = tickets_handler_dispatcher.contract_address;

    // assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), 0); // not mandatory
    // assert_eq!(underlying_erc20_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not mandatory
    // assert_eq!(underlying_erc20_dispatcher.balance_of(tickets_handler_addrs), 0); // not mandatory
    // assert_eq!(underlying_erc20_dispatcher.balance_of(zkLend_market_addrs), 0); // not mandatory

    let setup_data = SetupData {
        zkLend_addrs: zkLend_market_addrs,
        zkLend_disp: zkLend_market_dispatcher,
        zTOKEN_addrs: proof_of_deposit_token_addrs,
        zTOKEN_disp: pod_token_dispatcher,
        tickets_handler_addrs: tickets_handler_addrs,
        tickets_handler_disp: tickets_handler_dispatcher,
        erc20_addrs: underlying_erc20_addrs,
        erc20_disp: underlying_erc20_dispatcher,
    };

    setup_data
}