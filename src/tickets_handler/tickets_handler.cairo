// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (presets/erc721.cairo)

/// # ERC721 Preset
///
/// The upgradeable ERC721 contract offers a batch-mint mechanism that
/// can only be executed once upon contract construction.
///
/// For more complex or custom contracts, use Wizard for Cairo
/// https://wizard.openzeppelin.com/cairo

use starknet::ContractAddress;

#[starknet::interface]
trait IzkLendMarket<TState> {
    fn deposit(ref self: TState, token: ContractAddress, amount: felt252);
    fn withdraw(ref self: TState, token: ContractAddress, amount: felt252);
}


#[starknet::contract]
mod TicketsHandlerContract {
    use cairo_loto_poc::tickets_handler::components::cairo_loto_ticket::{
        CairoLotoTicketComponent, ICairoLotoTicket
    };
    use cairo_loto_poc::tickets_handler::components::cairo_loto_ticket::CairoLotoTicketComponent::TicketInternalTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use super::IzkLendMarket;
    use super::{IzkLendMarketDispatcher, IzkLendMarketDispatcherTrait};
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address, get_contract_address};
    use core::option::OptionTrait;
    use core::traits::{Into, TryInto};


    // const MAINNET_ZKLEND_MARKET_ADRS: felt252 =
    //     0x04c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: CairoLotoTicketComponent, storage: ticket, event: TicketEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable Component
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721 Component
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // Cairo Loto Ticket Component
    #[abi(embed_v0)]
    impl CairoLotoTicketImpl =
        CairoLotoTicketComponent::TicketExternals<ContractState>;
    impl TicketInternalImpl = CairoLotoTicketComponent::TicketInternalImpl<ContractState>;

    // Upgradeable Component
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;


    #[storage]
    struct Storage {
        zkLend_mkt_addrs: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ticket: CairoLotoTicketComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        TicketEvent: CairoLotoTicketComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }


    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        recipient: ContractAddress,
        token_ids: Span<u256>,
        owner: ContractAddress,
        underlying_erc20: ContractAddress,
        ticket_value: u256,
        zkLend_market: ContractAddress,
    ) {
        /// Sets the token `name` and `symbol` and sets the base URI.
        self.erc721.initializer(name, symbol, base_uri);
        /// Sets the ticket `underlying_asset` and its `value`.
        self.ticket.initializer(underlying_erc20, ticket_value);
        /// Assigns `owner` as the contract owner.
        self.ownable.initializer(owner);
        /// Mints the `token_ids` tokens to `recipient`
        self._mint_assets(recipient, token_ids);
        /// Keep in Storage the address of zkLend's Market contract
        self._initializer(zkLend_market);
    }

    //
    // External/Public functions
    //
    #[abi(per_item)]
    #[generate_trait]
    impl TicketsHandlerImpl of ITicketsHandlerTrait {
        #[external(v0)]
        /// To use this function, the `user` must have `approved`
        /// this contract to use/spend `ticket_value` of `underlying asset`.
        /// The user's deposit is directly sent for yield generation into matching zkLend vault.
        fn mint(ref self: ContractState, user: ContractAddress,) {
            let ticket_handler = get_contract_address();

            // Get ticket's `underlying_asset` and `value`
            let underlying_erc20 = self.ticket.underlying_asset.read();
            let ticket_value = self.ticket.value.read();

            // Transfer `ticket_value` of `underlying_asset` from `user` to this contract
            IERC20Dispatcher { contract_address: underlying_erc20 }
                .transfer_from(user, ticket_handler, ticket_value);

            // ERC20 deposit into zkLend's vault
            /// use the newly created private function to deposit
            /// `ticket_value` into zkLend's `underlying asset` vault
            self._deposit_to_zkLend(underlying_erc20, ticket_value);

            // Define next ticket's `token_id`
            let token_id = self.ticket.total_supply.read() + 1;

            // Mints one ticket to the `user`
            self._mint(user, token_id);
        }

        #[external(v0)]
        fn burn(ref self: ContractState, token_id: u256) {
            // TODO: Implementing ERC20 withdrawal from zkLend's vault
            //! Step 1:
            //! Create a private function withdrawing a given erc20 "asset" and "amount".
            //! => implement unit test of this private function

            //! Step 2:
            // use the newly created private function 

            //! Step 3:
            // Update tests of this public function 

            // Destroy ticket
            self._burn(token_id);
            // Send deposit back to the `caller`
            IERC20Dispatcher { contract_address: self.ticket.underlying_asset.read() }
                .transfer(get_caller_address(), self.ticket.value.read());
        }
        //! Step 4: CONVERT THE ABOVE FUNCTION SO THAT THE USER IS NOT NECESSARILY THE CALLER
        //!   -->   fn burn(ref self: ContractState, token_id: u256,) {...}

        #[external(v0)]
        fn get_zkLend_market_address(self: @ContractState) -> ContractAddress {
            self
                .zkLend_mkt_addrs
                .read() //! to be turned into a private function (which will also need to be tested) because it's being used several times in this contract
        }

        #[external(v0)]
        fn set_zkLend_market_address(ref self: ContractState, address: ContractAddress) {
            self.ownable.assert_only_owner();
            self.zkLend_mkt_addrs.write(address);
        }
    }


    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the contract class hash to `new_class_hash`.
        /// This may only be called by the contract owner.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    //
    // Internal/Private functions
    //
    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _initializer(ref self: ContractState, zkLend_market_addrs: ContractAddress,) {
            self.zkLend_mkt_addrs.write(zkLend_market_addrs);
        }

        /// Batch-Minting `token_ids` to `recipient`.
        fn _mint_assets(
            ref self: ContractState, recipient: ContractAddress, mut token_ids: Span<u256>
        ) {
            loop {
                if token_ids.len() == 0 {
                    break;
                }
                let id = *token_ids.pop_front().unwrap();
                self.erc721._mint(recipient, id);

                self.ticket._increase_circulating_supply();
                self.ticket._increase_total_tickets_emitted();
            }
        }

        /// Mints given ticket/token_id to `recipient`.
        fn _mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            // Ensure that the caller's balance is < 10 tickets
            assert(self.erc721.balance_of(recipient) < 10_u256, 'Account already owns 10 tickets');
            // TODO! instead of using a hardcoded value for the maximum nber of
            //! tickets that an account can own, create a storage value for it
            //! in the "ticket" component, and use that storage value here instead of "10_u256"!

            // Mint the ticket
            self.erc721._mint(recipient, token_id);
            // Update current and total supply
            self.ticket._increase_circulating_supply();
            self.ticket._increase_total_tickets_emitted();
        }

        /// Burns given ticket/token from the `caller`.
        fn _burn(ref self: ContractState, token_id: u256) {
            // Ensure caller is the ticket's owner
            let caller = get_caller_address();
            let ticket_owner = self.erc721._owner_of(token_id);
            assert(caller == ticket_owner, 'caller must own the ticket');

            // Burn ticket + decrease current supply
            self.erc721._burn(token_id);
            self.ticket._decrease_circulating_supply();
        }

        fn _approve_zkLend_for(
            ref self: ContractState, erc20_asset: ContractAddress, amount: u256
        ) {
            let zkLend_market = self.zkLend_mkt_addrs.read();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: erc20_asset };

            erc20_dispatcher.approve(zkLend_market, amount);
            assert(
                erc20_dispatcher.allowance(get_contract_address(), zkLend_market) == amount,
                'approval error'
            ); // not mandatory
        }

        /// Deposits given amount of `underlying_asset` from this contract into matching erc20 vault from zkLend.
        fn _deposit_to_zkLend(ref self: ContractState, erc20_asset: ContractAddress, amount: u256) {
            // Step 1: allow "zkLend Market" contract to
            // spend given amount of the `underlying_asset` from this contract
            self._approve_zkLend_for(erc20_asset, amount);

            // Step 2: Make a deposit of the given amount
            // of `underlying_asset` into zkLend Market contract
            let zkLend_market: ContractAddress = self.zkLend_mkt_addrs.read();
            let zkLend_dispatcher = IzkLendMarketDispatcher { contract_address: zkLend_market };
            //? zkLend's contract uses felt252 (not u256) to manage amounts ->
            let felt_amount: felt252 = amount.try_into().unwrap();

            //TODO: FIX BELOW ERROR:
            // (most likely in the test rather than here because the unit test of this function is successful)
            //! Error = 
            //! cairo_loto_poc_tests::integration_tests::test_tickets_handler::test_mint
            //! - Panicked with (0x434f4e54524143545f4e4f545f4445504c4f594544 ('CONTRACT_NOT_DEPLOYED'),
            //! 0x454e545259504f494e545f4641494c4544 ('ENTRYPOINT_FAILED')).
            zkLend_dispatcher.deposit(erc20_asset, felt_amount);
        ////////////////////////////////////////////////////////////////////
        //? Step 3: (optionnal - only to be used for "degen" vaults in later versions)
        // Enable ETH as collateral and create a leveraged position
        // by lending the deposited ETH and borrowing a fraction
        // of the deposit to lend it again -> TO BE IMPLEMENTED LATER ON
        // zkLend_market_dispatcher.borrow(underlying_asset, felt_borrow_amount);
        ////////////////////////////////////////////////////////////////////
        }

        /// Withdraws given amount of `underlying_asset` from this contract into matching erc20 vault from zkLend
        fn _withdraw_from_zkLend(ref self: ContractState, amount: u256) { // (...)
        }
    }
}
