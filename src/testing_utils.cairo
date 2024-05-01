mod access;
mod mocks;
mod constants;
mod presets;
mod token;
mod upgrades;


////////////////////////////////


use cairo_loto_poc::tickets_handler::tickets_handler::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler::interface::{TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,};
use cairo_loto_poc::testing_utils::constants::{
    TOKEN_1, TOKEN_2, TOKEN_3, TOKENS_LEN, NONEXISTENT, TEN_WITH_6_DECIMALS, ETH_ADDRS, ZKLEND_MKT_ADDRS,
};
use cairo_loto_poc::testing_utils::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use cairo_loto_poc::testing_utils::mocks::erc20_mock::SnakeERC20Mock;
use cairo_loto_poc::testing_utils::mocks::erc721_mocks::SnakeERC721Mock;
use cairo_loto_poc::testing_utils::mocks::erc721_receiver_mocks::{CamelERC721ReceiverMock, SnakeERC721ReceiverMock};

use openzeppelin::tests::utils;
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::tests::utils::constants::{
    OWNER, 
    NAME, 
    SYMBOL, 
    BASE_URI,
    PUBKEY, 
    // ZERO, 
    // DATA, 
    // SPENDER, 
    // RECIPIENT, 
    // OTHER, 
    // OPERATOR, 
    // CLASS_HASH_ZERO, 
};

use starknet::{testing, ContractAddress,};
// use starknet::SyscallResultTrait;




//
// Setup
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