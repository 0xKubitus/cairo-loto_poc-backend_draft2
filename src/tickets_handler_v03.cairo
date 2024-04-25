// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.12.0 (presets/erc721.cairo)

/// # ERC721 Preset
///
/// The upgradeable ERC721 contract offers a batch-mint mechanism that
/// can only be executed once upon contract construction.
///
/// For more complex or custom contracts, use Wizard for Cairo
/// https://wizard.openzeppelin.com/cairo
#[starknet::contract]
mod TicketsHandlerContract {
    use cairo_loto_poc::components::cairo_loto_ticket::{CairoLotoTicketComponent, ICairoLotoTicket};
    use cairo_loto_poc::components::cairo_loto_ticket::CairoLotoTicketComponent::TicketInternalTrait;
    use openzeppelin::access::ownable::ownable::OwnableComponent::InternalTrait;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc20::interface::{IERC20, IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address, get_contract_address};


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
    ) {
        /// Sets the token `name` and `symbol` and sets the base URI.
        self.erc721.initializer(name, symbol, base_uri);
        /// Sets the ticket `underlying_asset` and its `value`.
        self.ticket.initializer(underlying_erc20, ticket_value);
        /// Assigns `owner` as the contract owner.
        self.ownable.initializer(owner);
        /// Mints the `token_ids` tokens to `recipient`
        self._mint_assets(recipient, token_ids);
    }

    //
    // External/Public functions
    //
    #[abi(per_item)]
    #[generate_trait]
    impl TicketsHandlerImpl of ITicketsHandlerTrait {
    //     #[external(v0)]
    //     fn free_mint(ref self: ContractState,) {
    //         // Set the caller's address and the ticket's token_id
    //         let caller = get_caller_address();
    //         let token_id = self.ticket.total_supply.read() + 1;
    //         // Mints ticket to the caller
    //         self._mint(caller, token_id);
    //     }

    //     #[external(v0)]
    //     fn basic_burn(ref self: ContractState, token_id: u256) {
    //         self._burn(token_id);
    //     }
    // }

        #[external(v0)]
        // To use this function, the `caller` must have `approved`
        // this contract to spend the right amount of underlying asset.
        fn mint(ref self: ContractState,) {
            // Define required contracts addresses
            let caller = get_caller_address();
            let ticket_handler = get_contract_address();
            // TODO: Add deposit system (of underlying ERC20 asset)
            // Get ticket's `underlying_asset` and `value`
            let underlying_erc20 = self.ticket.underlying_asset.read();
            let ticket_value = self.ticket.value.read();

            // Transfer `ticket_value` of `underlying_asset` from `caller` to this contract
            IERC20Dispatcher { contract_address: underlying_erc20 }.transfer_from(caller, ticket_handler, ticket_value);

            // Define next ticket's `token_id`
            let token_id = self.ticket.total_supply.read() + 1;

            // Mints ticket to the caller
            self._mint(caller, token_id);
        }

        #[external(v0)]
        fn burn(ref self: ContractState, token_id: u256) {
            self._burn(token_id);
            // TODO: Add retrieval system (of underlying ERC20 deposited amount)
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
        /// Mints `token_ids` to `recipient`.
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

        /// Mints one ticket/token to the `caller`.
        fn _mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            // Ensure that the caller's balance is < 10 tickets
            assert(self.erc721.balance_of(recipient) < 10_u256, 'Account already owns 10 tickets');
            // Mint the ticket
            self.erc721._mint(recipient, token_id);
            // Update current and total supply
            self.ticket._increase_circulating_supply();
            self.ticket._increase_total_tickets_emitted();
        }

        /// Burns one ticket/token from the `caller`.
        fn _burn(ref self: ContractState, token_id: u256) {
            // Ensure caller is the ticket's owner
            let caller = get_caller_address();
            let ticket_owner = self.erc721._owner_of(token_id);
            assert_eq!(caller, ticket_owner);
            
            // Burn ticket + decrease current supply
            self.erc721._burn(token_id);
            self.ticket._decrease_circulating_supply();
        }
    }


}
