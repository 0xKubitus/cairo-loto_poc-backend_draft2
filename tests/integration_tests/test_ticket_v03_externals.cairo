use cairo_loto_poc::tickets_handler_v03::TicketsHandlerContract;
use cairo_loto_poc::interfaces::tickets_handler_v03::{
    TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,
};
use cairo_loto_poc::testing_utils::constants::{TEN_WITH_6_DECIMALS, ETH_ADDRS, SOME_ERC20, COIN, fake_ERC20_asset};
use cairo_loto_poc::testing_utils::mocks::erc20_mock::SnakeERC20Mock;
use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin::tests::utils;
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, NAME, SYMBOL,
    BASE_URI
};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress,};







//
// Definition of Constant values
//
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
// const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;


// #############################################################################

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
    calldata.append_serde(fake_ERC20_asset());
    calldata.append_serde(TEN_WITH_6_DECIMALS);

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> TicketsHandlerABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    // `OwnershipTransferred` + `Transfer`s
    utils::drop_events(dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    dispatcher
}

fn setup_max() -> TicketsHandlerABIDispatcher {
    let mut calldata = array![];
    let mut token_ids: Array<u256> = array![1,2,3,4,5,6,7,8,9,10];

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

fn setup_erc20_dispatcher() -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(SOME_ERC20());
    calldata.append_serde(COIN());
    calldata.append_serde(TEN_WITH_6_DECIMALS);
    calldata.append_serde(OWNER());

    let address = utils::deploy(SnakeERC20Mock::TEST_CLASS_HASH, calldata);
    let erc20_dispatcher = IERC20Dispatcher { contract_address: address };
    utils::drop_events(erc20_dispatcher.contract_address, TOKENS_LEN.try_into().unwrap() + 1);
    erc20_dispatcher
}
// #############################################################################


#[test]
fn test_mint() {
    let tickets_handler_dispatcher = setup_dispatcher();
    let tickets_handler_ctrct_addrs = tickets_handler_dispatcher.contract_address;
    let underlying_asset_dispatcher = setup_erc20_dispatcher();
    let amount = tickets_handler_dispatcher.ticket_value();
    assert_eq!(tickets_handler_dispatcher.balance_of(OWNER()), TOKENS_LEN); // not needed
    assert_eq!(underlying_asset_dispatcher.balance_of(OWNER()), TEN_WITH_6_DECIMALS); // not needed

    testing::set_contract_address(OWNER());
    // testing::set_caller_address(OWNER()); // this one works as well

    underlying_asset_dispatcher.approve(tickets_handler_ctrct_addrs, amount);
    assert_eq!(underlying_asset_dispatcher.allowance(OWNER(), tickets_handler_ctrct_addrs), TEN_WITH_6_DECIMALS); // not needed

    tickets_handler_dispatcher.mint(OWNER());
    // assert_eq!(tickets_handler_dispatcher.owner_of(4), OWNER());
}
