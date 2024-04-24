use starknet::{ContractAddress,};
use starknet::{contract_address_const,};


const TEN_WITH_6_DECIMALS: u256 = 10000000;


fn fake_ERC20_asset() -> ContractAddress {
    contract_address_const::<'fake_ERC20_asset'>()
}

fn ETH_ADDRS() -> ContractAddress {
    contract_address_const::<0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7>()
}

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}
