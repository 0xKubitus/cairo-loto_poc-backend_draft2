use starknet::{ContractAddress,};
use starknet::{contract_address_const,};


//
// Token IDs
//

const TOKEN_1: u256 = 1;
const TOKEN_2: u256 = 2;
const TOKEN_3: u256 = 3;
const NONEXISTENT: u256 = 9898;
const TOKENS_LEN: u256 = 3;

//
// Decimal numbers
//

const TEN_WITH_6_DECIMALS: u256 = 10000000;
// const THOUSAND_WITH_18_DECIMALS: u256 = 1000000000000000000000;

//
// Contract Addresses
//

fn ZKLEND_MKT_ADDRS() -> ContractAddress {
    contract_address_const::<'ZKLEND_MKT_ADDRS'>()
}

fn ETH_ADDRS() -> ContractAddress {
    contract_address_const::<0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7>()
}

fn random_ERC20_token() -> ContractAddress {
    contract_address_const::<'random_ERC20_token'>()
}

//
// Byte Arrays
//

fn SOME_ERC20() -> ByteArray {
    "SOME ERC20"
}

fn COIN() -> ByteArray {
    "COIN"
}

