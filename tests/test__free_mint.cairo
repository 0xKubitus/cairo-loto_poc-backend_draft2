use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract;
use cairo_loto_poc::tickets_handler_v02::TicketsHandlerContract::InternalImpl;
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
fn test__basic_burn() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();

    testing::set_caller_address(OTHER());

    state._free_mint();
    assert_eq!(state.erc721.balance_of(OTHER()), 1);

    state._basic_burn(1);
    assert_eq!(state.erc721.balance_of(OTHER()), 0);
}
