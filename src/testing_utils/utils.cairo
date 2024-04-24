use starknet::ContractAddress;
use starknet::SyscallResultTrait;
// use starknet::testing;

fn deploy(contract_class_hash: felt252, calldata: Array<felt252>) -> ContractAddress {
    deploy_with_salt(contract_class_hash, calldata, 0)
}

fn deploy_with_salt(
    contract_class_hash: felt252, calldata: Array<felt252>, salt: felt252
) -> ContractAddress {
    let (address, _) = starknet::deploy_syscall(
        contract_class_hash.try_into().unwrap(), salt, calldata.span(), false
    )
        .unwrap_syscall();
    address
}


trait SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T);
}

impl SerializedAppendImpl<T, impl TSerde: Serde<T>, impl TDrop: Drop<T>> of SerializedAppend<T> {
    fn append_serde(ref self: Array<felt252>, value: T) {
        value.serialize(ref self);
    }
}
