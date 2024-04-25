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
fn test__burn_not_ticketOwner() {
    let mut state = TicketsHandlerContract::contract_state_for_testing();
    let mut token_ids = array![TOKEN_1, TOKEN_2, TOKEN_3].span();
    state._mint_assets(OWNER(), token_ids);
    assert_eq!(state.erc721.balance_of(OWNER()), 3);

    // TEST PANICS BECAUSE "OTHER()" IS NOT THE OWNER OF THE TICKET
    testing::set_caller_address(OTHER());
    state._burn(1);
}