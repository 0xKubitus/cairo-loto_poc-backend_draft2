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
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use cairo_loto_poc::components::cairo_loto_ticket::{CairoLotoTicketComponent, ICairoLotoTicket};
    use cairo_loto_poc::components::cairo_loto_ticket::CairoLotoTicketComponent::TicketInternalTrait;
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address,};


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
    impl InternalImpl of InternalTrait {
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

        /// Mints one ticket/token to the `caller` (for free).
        fn _free_mint(ref self: ContractState,) {
            let caller = get_caller_address();
            let id = self.ticket.total_supply.read() + 1;

            self.erc721._mint(caller, id);

            self.ticket._increase_circulating_supply();
            self.ticket._increase_total_tickets_emitted();
        }

        /// Burns one ticket/token from the `caller` (no retrieval system).
        fn _basic_burn(ref self: ContractState, token_id: u256) {
            //? I think there is no need to make sure that `caller` is the ticket's owner
            //? because this verification is made in the ERC721 component's function
            //? that is called just below:
            self.erc721._burn(token_id);

            self.ticket._decrease_circulating_supply();
        }
    }


}
