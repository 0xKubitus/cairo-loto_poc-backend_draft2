use openzeppelin::introspection::interface::ISRC5_ID;
use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract::{PrivateImpl, TicketsHandlerImpl, ITicketsHandlerTrait};
use cairo_loto_poc::interfaces::tickets_handler_v02::{
    TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,
};
use cairo_loto_poc::testing_utils::access::test_ownable::assert_event_ownership_transferred;
use cairo_loto_poc::testing_utils::mocks::account_mocks::{DualCaseAccountMock, CamelAccountMock};
use cairo_loto_poc::testing_utils::mocks::erc721_mocks::SnakeERC721Mock;
use cairo_loto_poc::testing_utils::mocks::erc721_receiver_mocks::{
    CamelERC721ReceiverMock, SnakeERC721ReceiverMock
};
use cairo_loto_poc::testing_utils::mocks::non_implementing_mock::NonImplementingMock;
use cairo_loto_poc::testing_utils::token::test_erc721::{
    assert_event_transfer, assert_only_event_transfer, assert_event_approval,
    assert_event_approval_for_all
};
use cairo_loto_poc::testing_utils::upgrades::test_upgradeable::assert_only_event_upgraded;
use openzeppelin::tests::utils::constants::{
    ZERO, DATA, OWNER, SPENDER, RECIPIENT, OTHER, OPERATOR, CLASS_HASH_ZERO, PUBKEY, NAME, SYMBOL,
    BASE_URI
};
use cairo_loto_poc::testing_utils::constants::{TEN_WITH_6_DECIMALS, fake_ERC20_asset, ETH_ADDRS,};
use openzeppelin::tests::utils;
use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
use openzeppelin::token::erc721::ERC721Component;
use openzeppelin::token::erc721::interface::{
    IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
};
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin::token::erc721::interface::{IERC721_ID, IERC721_METADATA_ID};
use openzeppelin::utils::serde::SerializedAppend;
use starknet::testing;
use starknet::{ContractAddress, ClassHash};


// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;

fn V2_CLASS_HASH() -> ClassHash {
    SnakeERC721Mock::TEST_CLASS_HASH.try_into().unwrap()
}

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

    let address = utils::deploy(TicketsHandlerContract::TEST_CLASS_HASH, calldata);
    TicketsHandlerABIDispatcher { contract_address: address }
}

fn setup_dispatcher() -> TicketsHandlerABIDispatcher {
    let dispatcher = setup_dispatcher_with_event();
    // `OwnershipTransferred` + `Transfer`s
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
// PRIVATE FUNCTIONS (ONLY FROM THIS CONTRACT, NOT ALL COMPONENTS INTERNALS)
//

#[test]
fn test__mint_assets() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3].span();

    state._mint_assets(OWNER(), token_ids);
    assert_eq!(state.erc721.balance_of(OWNER()), TOKENS_LEN);

    loop {
        if token_ids.len() == 0 {
            break;
        }
        let id = *token_ids.pop_front().unwrap();
        assert_eq!(state.erc721.owner_of(id), OWNER());
    };
}

#[test]
fn test__mint() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    testing::set_caller_address(OWNER()); //? is this necessary?

    state._mint(OWNER(), 1);
    state._mint(OWNER(), 2);

    assert_eq!(state.erc721.balance_of(OWNER()), 2);
}

#[test]
#[should_panic]
fn test__mint_11th_ticket() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    testing::set_caller_address(OWNER());

    let calldata: Array<u256> = array![1,2,3,4,5,6,7,8,9,10];
    state._mint_assets(OWNER(), calldata.span());

    // TEST PANICS HERE BECAUSE TICKET MAX LIMIT PER ACCOUNT = 10
    state._mint(OWNER(), 11);
}

#[test]
fn test__burn() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();

    testing::set_caller_address(OWNER());

    state._mint(OWNER(), 1);
    assert_eq!(state.erc721.balance_of(OWNER()), 1);

    state._burn(1);
    assert_eq!(state.erc721.balance_of(OWNER()), 0);
}

#[test]
#[should_panic]
fn test_burn_not_ticketOwner() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3].span();
    state._mint_assets(OWNER(), token_ids);
    assert_eq!(state.erc721.balance_of(OWNER()), 3);

    // TEST PANICS BECAUSE "OTHER()" IS NOT THE OWNER OF THE TICKET
    testing::set_caller_address(OTHER());
    state._burn(1);
}


//
// constructor
//

#[test]
fn test_constructor() {
    let dispatcher = setup_dispatcher_with_event();

    // Check interface registration
    let mut interface_ids = array![ISRC5_ID, IERC721_ID, IERC721_METADATA_ID];
    loop {
        let id = interface_ids.pop_front().unwrap();
        if interface_ids.len() == 0 {
            break;
        }
        let supports_interface = dispatcher.supports_interface(id);
        assert!(supports_interface);
    };

    // Check token balance and owner
    let mut tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];
    assert_eq!(dispatcher.balance_of(OWNER()), TOKENS_LEN);

    loop {
        let token = tokens.pop_front().unwrap();
        if tokens.len() == 0 {
            break;
        }
        let current_owner = dispatcher.owner_of(token);
        assert_eq!(current_owner, OWNER());
    };
}

#[test]
fn test_constructor_events() {
    let dispatcher = setup_dispatcher_with_event();
    let mut tokens = array![TOKEN_1, TOKEN_2, TOKEN_3];

    assert_event_ownership_transferred(dispatcher.contract_address, ZERO(), OWNER());
    loop {
        let token = tokens.pop_front().unwrap();
        if tokens.len() == 0 {
            // Includes event queue check
            assert_only_event_transfer(dispatcher.contract_address, ZERO(), OWNER(), token);
            break;
        }
        assert_event_transfer(dispatcher.contract_address, ZERO(), OWNER(), token);
    };
}

//
// Getters
//

#[test]
fn test_balance_of() {
    let dispatcher = setup_dispatcher();
    assert_eq!(dispatcher.balance_of(OWNER()), TOKENS_LEN);
}

#[test]
#[should_panic(expected: ('ERC721: invalid account', 'ENTRYPOINT_FAILED'))]
fn test_balance_of_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.balance_of(ZERO());
}

#[test]
fn test_owner_of() {
    let dispatcher = setup_dispatcher();
    assert_eq!(dispatcher.owner_of(TOKEN_1), OWNER());
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_owner_of_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.owner_of(7);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_token_uri_non_minted() {
    let dispatcher = setup_dispatcher();
    dispatcher.token_uri(7);
}

#[test]
fn test_token_uri() {
    let dispatcher = setup_dispatcher();

    let uri = dispatcher.token_uri(TOKEN_1);
    let expected = format!("{}{}", BASE_URI(), TOKEN_1);
    assert_eq!(uri, expected);
}

#[test]
fn test_get_approved() {
    let dispatcher = setup_dispatcher();
    let spender = SPENDER();
    let token_id = TOKEN_1;

    let approved = dispatcher.get_approved(token_id);
    assert!(approved.is_zero());

    dispatcher.approve(spender, token_id);
    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, spender);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_get_approved_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.get_approved(NONEXISTENT);
}

//
// CairoLotoTicketComponent external functions (which are getters only)
//

#[test]
fn test_underlying_erc20_asset() {
    let tickets_handler = setup_dispatcher();
    assert_eq!(tickets_handler.underlying_erc20_asset(), ETH_ADDRS());
}

#[test]
fn test_ticket_value() {
    let tickets_handler = setup_dispatcher();
    assert_eq!(tickets_handler.ticket_value(), TEN_WITH_6_DECIMALS);
}

#[test]
fn test_circulating_supply() {
    let tickets_handler = setup_dispatcher();
    assert_eq!(tickets_handler.circulating_supply(), 3);
}

#[test]
fn test_total_tickets_emitted() {
    let tickets_handler = setup_dispatcher();
    assert_eq!(tickets_handler.total_tickets_emitted(), 3);
}

// =================================================================

// SETTERS (External/Public Functions)

//
// Test TicketsHandlerContract external functions (ICairoLotoTicket)
//

//! WHICH KIND OF TEST IS BETTER/MORE SUITABLE?
//? OPTION 1: deploying the contract with `starknet::deploy_syscall()`
#[test]
fn test_mint_type1() {
    let tickets_handler = setup_dispatcher();

    // using `set_contract_address()` in this case because
    // `set_caller_address()` makes the test fail.
    testing::set_contract_address(OTHER());
    //? => I suppose that means that it is mandatory
    //?    when using the `deploy_syscall()` method?

    tickets_handler.free_mint();
    assert_eq!(tickets_handler.balance_of(OTHER()), 1);
}
//? OR, OPTION 2: testing without deploying using `contract_state_for_testing()`
#[test]
fn test_mint_type2() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();

    // In this case, it is now mandatory to use
    // `set_caller_address()`, not `set_contract_address()` !
    testing::set_caller_address(OWNER());

    state.free_mint();
    state.free_mint();

    assert_eq!(state.erc721.balance_of(OWNER()), 2);
}

// //TODO: test mint() that panics for exceeding limit
// #[test]
// fn test_() {
//     let loto_tickets = setup_dispatcher();
//     assert_eq!(a, b);
// }

// //TODO: test burn()
// #[test]
// fn test_() {
//     let loto_tickets = setup_dispatcher();
//     assert_eq!(a, b);
// }

// //TODO: test burn() that panics for wrong owner
// #[test]
// fn test_() {
//     let loto_tickets = setup_dispatcher();
//     assert_eq!(a, b);
// }


//
// Functions from OZ's ERC721Upgradeable Preset
//

//
// approve
//

#[test]
fn test_approve_from_owner() {
    let dispatcher = setup_dispatcher();

    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    let approved = dispatcher.get_approved(TOKEN_1);
    assert_eq!(approved, SPENDER());
}

#[test]
fn test_approve_from_operator() {
    let dispatcher = setup_dispatcher();

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.approve(SPENDER(), TOKEN_1);
    assert_event_approval(dispatcher.contract_address, OWNER(), SPENDER(), TOKEN_1);

    let approved = dispatcher.get_approved(TOKEN_1);
    assert_eq!(approved, SPENDER());
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_approve_from_unauthorized() {
    let dispatcher = setup_dispatcher();

    testing::set_contract_address(OTHER());
    dispatcher.approve(SPENDER(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: approval to owner', 'ENTRYPOINT_FAILED'))]
fn test_approve_to_owner() {
    let dispatcher = setup_dispatcher();

    dispatcher.approve(OWNER(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_approve_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.approve(SPENDER(), NONEXISTENT);
}

//
// set_approval_for_all
//

#[test]
fn test_set_approval_for_all() {
    let dispatcher = setup_dispatcher();

    let is_not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_not_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), true);

    let is_approved_for_all = dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_approved_for_all);

    dispatcher.set_approval_for_all(OPERATOR(), false);
    assert_event_approval_for_all(dispatcher.contract_address, OWNER(), OPERATOR(), false);

    let is_not_approved_for_all = !dispatcher.is_approved_for_all(OWNER(), OPERATOR());
    assert!(is_not_approved_for_all);
}

#[test]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_true() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_approval_for_all(OWNER(), true);
}

#[test]
#[should_panic(expected: ('ERC721: self approval', 'ENTRYPOINT_FAILED'))]
fn test_set_approval_for_all_owner_equal_operator_false() {
    let dispatcher = setup_dispatcher();
    dispatcher.set_approval_for_all(OWNER(), false);
}

//
// transfer_from & transferFrom
//

#[test]
fn test_transfer_from_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    // set approval to check reset
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, OTHER());

    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    // set approval to check reset
    dispatcher.approve(OTHER(), token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    let approved = dispatcher.get_approved(token_id);
    assert_eq!(approved, OTHER());

    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(OWNER(), RECIPIENT(), NONEXISTENT);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.transferFrom(OWNER(), RECIPIENT(), NONEXISTENT);
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.transfer_from(OWNER(), ZERO(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.transferFrom(OWNER(), ZERO(), TOKEN_1);
}

#[test]
fn test_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
    dispatcher.transfer_from(OWNER(), OWNER(), TOKEN_1);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
fn test_transferFrom_to_owner() {
    let dispatcher = setup_dispatcher();

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
    dispatcher.transferFrom(OWNER(), OWNER(), TOKEN_1);
    assert_only_event_transfer(dispatcher.contract_address, OWNER(), OWNER(), TOKEN_1);

    assert_state_transfer_to_self(dispatcher, OWNER(), TOKEN_1, TOKENS_LEN);
}

#[test]
fn test_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();
    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transfer_from(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
fn test_transferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let owner = OWNER();
    let recipient = RECIPIENT();

    assert_state_before_transfer(dispatcher, owner, recipient, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.transferFrom(owner, recipient, token_id);
    assert_only_event_transfer(dispatcher.contract_address, owner, recipient, token_id);

    assert_state_after_transfer(dispatcher, owner, recipient, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_from(OWNER(), RECIPIENT(), TOKEN_1);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_transferFrom_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferFrom(OWNER(), RECIPIENT(), TOKEN_1);
}

//
// safe_transfer_from & safeTransferFrom
//

#[test]
fn test_safe_transfer_from_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safeTransferFrom_to_account() {
    let dispatcher = setup_dispatcher();
    let account = setup_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safe_transfer_from_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safe_transfer_from(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safeTransferFrom_to_account_camel() {
    let dispatcher = setup_dispatcher();
    let account = setup_camel_account();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, account, token_id);

    dispatcher.safeTransferFrom(owner, account, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, account, token_id);

    assert_state_after_transfer(dispatcher, owner, account, token_id);
}

#[test]
fn test_safe_transfer_from_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_to_receiver() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_to_receiver_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ERC721: safe transfer failed', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_receiver_failure_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(false));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safe_transfer_from(owner, recipient, token_id, DATA(true));
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_non_receiver() {
    let dispatcher = setup_dispatcher();
    let recipient = utils::deploy(NonImplementingMock::TEST_CLASS_HASH, array![]);
    let token_id = TOKEN_1;
    let owner = OWNER();

    dispatcher.safeTransferFrom(owner, recipient, token_id, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), NONEXISTENT, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_nonexistent() {
    let dispatcher = setup_dispatcher();
    dispatcher.safeTransferFrom(OWNER(), RECIPIENT(), NONEXISTENT, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.safe_transfer_from(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: invalid receiver', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_to_zero() {
    let dispatcher = setup_dispatcher();
    dispatcher.safeTransferFrom(OWNER(), ZERO(), TOKEN_1, DATA(true));
}

#[test]
fn test_safe_transfer_from_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safeTransferFrom_to_owner() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safe_transfer_from_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safe_transfer_from(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safeTransferFrom_to_owner_camel() {
    let dispatcher = setup_dispatcher();
    let token_id = TOKEN_1;
    let receiver = setup_camel_receiver();

    dispatcher.transfer_from(OWNER(), receiver, token_id);
    utils::drop_event(dispatcher.contract_address);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);

    testing::set_contract_address(receiver);
    dispatcher.safeTransferFrom(receiver, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, receiver, receiver, token_id);

    assert_state_transfer_to_self(dispatcher, receiver, token_id, 1);
}

#[test]
fn test_safe_transfer_from_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.approve(OPERATOR(), token_id);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_for_all() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safe_transfer_from_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safe_transfer_from(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
fn test_safeTransferFrom_approved_for_all_camel() {
    let dispatcher = setup_dispatcher();
    let receiver = setup_camel_receiver();
    let token_id = TOKEN_1;
    let owner = OWNER();

    assert_state_before_transfer(dispatcher, owner, receiver, token_id);

    dispatcher.set_approval_for_all(OPERATOR(), true);
    utils::drop_event(dispatcher.contract_address);

    testing::set_contract_address(OPERATOR());
    dispatcher.safeTransferFrom(owner, receiver, token_id, DATA(true));
    assert_only_event_transfer(dispatcher.contract_address, owner, receiver, token_id);

    assert_state_after_transfer(dispatcher, owner, receiver, token_id);
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safe_transfer_from_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safe_transfer_from(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller', 'ENTRYPOINT_FAILED'))]
fn test_safeTransferFrom_unauthorized() {
    let dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.safeTransferFrom(OWNER(), RECIPIENT(), TOKEN_1, DATA(true));
}

//
// transfer_ownership & transferOwnership
//

#[test]
fn test_transfer_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transfer_ownership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transfer_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transfer_ownership(OTHER());
}

#[test]
fn test_transferOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(OTHER());

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), OTHER());
    assert_eq!(dispatcher.owner(), OTHER());
}

#[test]
#[should_panic(expected: ('New owner is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_to_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.transferOwnership(ZERO());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_zero() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.transferOwnership(OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_transferOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.transferOwnership(OTHER());
}

//
// renounce_ownership & renounceOwnership
//

#[test]
fn test_renounce_ownership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounce_ownership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounce_ownership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounce_ownership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounce_ownership();
}

#[test]
fn test_renounceOwnership() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OWNER());
    dispatcher.renounceOwnership();

    assert_event_ownership_transferred(dispatcher.contract_address, OWNER(), ZERO());
    assert!(dispatcher.owner().is_zero());
}

#[test]
#[should_panic(expected: ('Caller is the zero address', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_zero_address() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(ZERO());
    dispatcher.renounceOwnership();
}

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED'))]
fn test_renounceOwnership_from_nonowner() {
    let mut dispatcher = setup_dispatcher();
    testing::set_contract_address(OTHER());
    dispatcher.renounceOwnership();
}

//
// upgrade
//

#[test]
#[should_panic(expected: ('Caller is not the owner', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_unauthorized() {
    let v1 = setup_dispatcher();
    testing::set_contract_address(OTHER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
#[should_panic(expected: ('Class hash cannot be zero', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_with_class_hash_zero() {
    let v1 = setup_dispatcher();

    testing::set_contract_address(OWNER());
    v1.upgrade(CLASS_HASH_ZERO());
}

#[test]
fn test_upgraded_event() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    assert_only_event_upgraded(v1.contract_address, v2_class_hash);
}

#[test]
#[should_panic(expected: ('ENTRYPOINT_NOT_FOUND',))]
fn test_v2_missing_camel_selector() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.upgrade(v2_class_hash);

    let dispatcher = IERC721CamelOnlyDispatcher { contract_address: v1.contract_address };
    dispatcher.ownerOf(TOKEN_1);
}

#[test]
fn test_state_persists_after_upgrade() {
    let v1 = setup_dispatcher();
    let v2_class_hash = V2_CLASS_HASH();

    testing::set_contract_address(OWNER());
    v1.transferFrom(OWNER(), RECIPIENT(), TOKEN_1);

    // Check RECIPIENT balance v1
    let camel_balance = v1.balanceOf(RECIPIENT());
    assert_eq!(camel_balance, 1);

    v1.upgrade(v2_class_hash);

    // Check RECIPIENT balance v2
    let v2 = IERC721Dispatcher { contract_address: v1.contract_address };
    let snake_balance = v2.balance_of(RECIPIENT());
    assert_eq!(snake_balance, camel_balance);
}


//
// Helpers
//

fn assert_state_before_transfer(
    dispatcher: TicketsHandlerABIDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    assert_eq!(dispatcher.owner_of(token_id), owner);
    assert_eq!(dispatcher.balance_of(owner), TOKENS_LEN);
    assert!(dispatcher.balance_of(recipient).is_zero());
}

fn assert_state_after_transfer(
    dispatcher: TicketsHandlerABIDispatcher,
    owner: ContractAddress,
    recipient: ContractAddress,
    token_id: u256
) {
    let current_owner = dispatcher.owner_of(token_id);
    assert_eq!(current_owner, recipient);
    assert_eq!(dispatcher.balance_of(owner), TOKENS_LEN - 1);
    assert_eq!(dispatcher.balance_of(recipient), 1);

    let approved = dispatcher.get_approved(token_id);
    assert!(approved.is_zero());
}

fn assert_state_transfer_to_self(
    dispatcher: TicketsHandlerABIDispatcher,
    target: ContractAddress,
    token_id: u256,
    token_balance: u256
) {
    assert_eq!(dispatcher.owner_of(token_id), target);
    assert_eq!(dispatcher.balance_of(target), token_balance);
}
