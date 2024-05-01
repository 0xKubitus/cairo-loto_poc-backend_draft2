use starknet::{ContractAddress,};
use starknet::{contract_address_const,};


const TEN_WITH_6_DECIMALS: u256 = 10000000;
// const THOUSAND_WITH_18_DECIMALS: u256 = 1000000000000000000000;


fn ZKLEND_MKT_ADDRS() -> ContractAddress {
    contract_address_const::<'ZKLEND_MKT_ADDRS'>()
}

fn fake_ERC20_asset() -> ContractAddress {
    contract_address_const::<'fake_ERC20_asset'>()
}

fn ETH_ADDRS() -> ContractAddress {
    contract_address_const::<0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7>()
}

fn SOME_ERC20() -> ByteArray {
    "SOME ERC20"
}

fn COIN() -> ByteArray {
    "COIN"
}

