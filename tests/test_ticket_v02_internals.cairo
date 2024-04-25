use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract::PrivateImpl;
use cairo_loto_poc::interfaces::tickets_handler_v01::{
    TicketsHandlerABIDispatcher, TicketsHandlerABIDispatcherTrait,
};

use openzeppelin::token::erc721::ERC721Component::ERC721Impl;
use openzeppelin::tests::utils::constants::{OWNER, OTHER,// ZERO, DATA, SPENDER, RECIPIENT,  OPERATOR, CLASS_HASH_ZERO, PUBKEY, NAME, SYMBOL,
// BASE_URI
};

use starknet::testing;


// Token IDs
const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;

const NONEXISTENT: u256 = 9898;

const TOKENS_LEN: u256 = 3;


#[test]
fn test__free_mint() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    testing::set_caller_address(OTHER());

    state._free_mint();
    state._free_mint();

    assert_eq!(state.erc721.balance_of(OTHER()), 2);
}

#[test]
#[should_panic]
fn test_panic__free_mint() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    testing::set_caller_address(OTHER());

    let calldata: Array<u256> = array![1,2,3,4,5,6,7,8,9,10];
    state._mint_assets(OTHER(), calldata.span());

    // SHOULD PANIC HERE BECAUSE MAX TICKET LIMIT PER ACCOUNT IS 10
    state._free_mint();
}

#[test]
fn test__basic_burn() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();

    testing::set_caller_address(OTHER());

    state._free_mint();
    assert_eq!(state.erc721.balance_of(OTHER()), 1);

    state._basic_burn(1);
    assert_eq!(state.erc721.balance_of(OTHER()), 0);
}

#[test]
#[should_panic]
fn test_panic_burn() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3].span();
    state._mint_assets(OWNER(), token_ids);

    assert_eq!(state.erc721.balance_of(OWNER()), 3);

    testing::set_caller_address(OTHER());
    // NOW, TEST SHOULD PANIC BECAUSE "OTHER()" IS NOT THE OWNER
    state._basic_burn(1);
}