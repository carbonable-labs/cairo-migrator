#[starknet::contract]
mod Migrate {
    // Starknet imports

    use starknet::{ContractAddress, get_contract_address, get_caller_address};

    // External imports

    use cairo_erc_3525::interface::IERC3525_ID;
    use openzeppelin::introspection::interface::{
        ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5CamelDispatcher, ISRC5CamelDispatcherTrait
    };
    use openzeppelin::token::erc721::interface::{
        IERC721CamelOnlyDispatcher, IERC721CamelOnlyDispatcherTrait
    };

    // Internal imports

    use migrator::components::migrate::interface::{
        IMigrate, IERC721BurnableDispatcher, IERC721BurnableDispatcherTrait,
        IERC3525MintableDispatcher, IERC3525MintableDispatcherTrait
    };

    // Constants

    const IERC721_ID: felt252 = 0x80ac58cd;

    #[storage]
    struct Storage {
        _migrate_source_address: ContractAddress,
        _migrate_target_address: ContractAddress,
        _migrate_slot: u256,
        _migrate_value: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Migration: Migration,
    }

    #[derive(Drop, starknet::Event)]
    struct Migration {
        address: ContractAddress,
        token_id: u256,
        new_token_id: u256,
        slot: u256,
        value: u256,
    }

    #[external(v0)]
    impl MigrateImpl of IMigrate<ContractState> {
        fn source_address(self: @ContractState) -> starknet::ContractAddress {
            self._migrate_source_address.read()
        }

        fn target_address(self: @ContractState) -> starknet::ContractAddress {
            self._migrate_target_address.read()
        }

        fn slot(self: @ContractState) -> u256 {
            self._migrate_slot.read()
        }

        fn value(self: @ContractState) -> u256 {
            self._migrate_value.read()
        }

        fn migrate(ref self: ContractState, mut token_ids: Span<u256>) -> u256 {
            // [Interaction] Mint new token with value
            let target = self._migrate_target_address.read();
            let caller = get_caller_address();
            let slot = self._migrate_slot.read();
            let value = self._migrate_value.read();
            let erc3525 = IERC3525MintableDispatcher { contract_address: target };
            let new_token_id = erc3525.mint(caller, slot, value * token_ids.len().into());

            // [Interaction] Transfer and burn old tokens
            let source = self._migrate_source_address.read();
            let contract = get_contract_address();
            loop {
                match token_ids.pop_front() {
                    Option::Some(token_id) => {
                        self
                            ._migrate(
                                source, caller, contract, *token_id, new_token_id, slot, value
                            );
                    },
                    Option::None => {
                        break;
                    },
                };
            };
            new_token_id
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(
            ref self: ContractState,
            source_address: ContractAddress,
            target_address: ContractAddress,
            slot: u256,
            value: u256
        ) {
            // [Check] Inputs
            assert(!source_address.is_zero(), 'Source address cannot be zero');
            assert(!target_address.is_zero(), 'Target address cannot be zero');
            assert(source_address != target_address, 'Addresses cannot be the same');

            // [Check] Source is ERC721
            let erc721 = ISRC5CamelDispatcher { contract_address: source_address };
            assert(erc721.supportsInterface(IERC721_ID), 'Source must support ERC721');

            // [Check] Target is ERC3525
            let erc3525 = ISRC5Dispatcher { contract_address: target_address };
            assert(erc3525.supports_interface(IERC3525_ID), 'Target must support ERC3525');

            // [Check] Value
            assert(value > 0, 'Value must be positive');

            // [Effect] Store values
            self._migrate_source_address.write(source_address);
            self._migrate_target_address.write(target_address);
            self._migrate_slot.write(slot);
            self._migrate_value.write(value);
        }

        fn _migrate(
            ref self: ContractState,
            source: ContractAddress,
            caller: ContractAddress,
            contract: ContractAddress,
            token_id: u256,
            new_token_id: u256,
            slot: u256,
            value: u256
        ) {
            // [Interaction] Transfer token to the contract
            let erc721 = IERC721CamelOnlyDispatcher { contract_address: source };
            erc721.transferFrom(caller, contract, token_id);

            // [Interaction] Burn the token
            let erc721 = IERC721BurnableDispatcher { contract_address: source };
            erc721.burn(token_id);

            // [Event] Emit
            self
                .emit(
                    Migration {
                        address: caller,
                        token_id: token_id,
                        new_token_id: new_token_id,
                        slot: slot,
                        value: value
                    }
                );
        }
    }
}

#[cfg(test)]
mod Test {
    // Starknet deps
    use starknet::{
        ContractAddress, get_contract_address, get_caller_address, contract_address_const
    };
    use starknet::testing::{set_caller_address, set_contract_address};

    // External deps
    use cairo_erc_3525::interface::{IERC3525Dispatcher, IERC3525DispatcherTrait};
    use openzeppelin::account::account::Account;
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    // Project deps
    use migrator::tests::mocks::erc721::{
        ERC721, IERC721MintableDispatcher, IERC721MintableDispatcherTrait
    };
    use migrator::tests::mocks::erc3525::ERC3525;
    use debug::PrintTrait;

    // Local deps
    use super::Migrate;

    // Constants
    const SLOT: u256 = 1;
    const VALUE: u256 = 10;
    const ONE: u256 = 1;
    const TWO: u256 = 2;
    const THREE: u256 = 3;

    #[derive(Drop)]
    struct Signers {
        anyone: ContractAddress,
        someone: ContractAddress,
    }

    #[derive(Drop)]
    struct Contracts {
        source: ContractAddress,
        target: ContractAddress,
    }

    fn deploy_account(
        class_hash: starknet::class_hash::ClassHash, public_key: felt252
    ) -> ContractAddress {
        let calldata: Array<felt252> = array![public_key];
        let (address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
        address
    }

    fn deploy_contract(class_hash: starknet::class_hash::ClassHash) -> ContractAddress {
        let calldata: Array<felt252> = array![];
        let (address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
        address
    }

    fn setup() -> (Signers, Contracts) {
        let source = deploy_contract(ERC721::TEST_CLASS_HASH.try_into().unwrap());
        let target = deploy_contract(ERC3525::TEST_CLASS_HASH.try_into().unwrap());
        let anyone = deploy_account(Account::TEST_CLASS_HASH.try_into().unwrap(), 'ANYONE');
        let someone = deploy_account(Account::TEST_CLASS_HASH.try_into().unwrap(), 'SOMEONE');
        let erc721 = IERC721MintableDispatcher { contract_address: source };
        erc721.mint(anyone, ONE);
        erc721.mint(anyone, TWO);
        erc721.mint(someone, THREE);
        set_contract_address(CONTRACT_ADDRESS());
        (Signers { anyone, someone }, Contracts { source, target })
    }

    fn STATE() -> Migrate::ContractState {
        Migrate::contract_state_for_testing()
    }

    fn CONTRACT_ADDRESS() -> ContractAddress {
        starknet::contract_address_const::<'CONTRACT_ADDRESS'>()
    }

    fn ZERO() -> ContractAddress {
        starknet::contract_address_const::<0>()
    }

    #[test]
    #[available_gas(20_000_000)]
    fn test_migrate_initializer() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(
            ref state, contracts.source, contracts.target, SLOT, VALUE
        );
        // [Assert]
        let source_address = Migrate::MigrateImpl::source_address(@state);
        assert(source_address == contracts.source, 'Source address is incorrect');
        let target_address = Migrate::MigrateImpl::target_address(@state);
        assert(target_address == contracts.target, 'Target address is incorrect');
        let slot = Migrate::MigrateImpl::slot(@state);
        assert(slot == SLOT, 'Slot is incorrect');
        let value = Migrate::MigrateImpl::value(@state);
        assert(value == VALUE, 'Value is incorrect');
    }

    #[test]
    #[available_gas(20_000_000)]
    #[should_panic(expected: ('Source address cannot be zero',))]
    fn test_migrate_initializer_revert_source_zero() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(ref state, ZERO(), contracts.target, SLOT, VALUE);
    }

    #[test]
    #[available_gas(20_000_000)]
    #[should_panic(expected: ('Target address cannot be zero',))]
    fn test_migrate_initializer_revert_target_zero() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(ref state, contracts.source, ZERO(), SLOT, VALUE);
    }

    #[test]
    #[available_gas(20_000_000)]
    #[should_panic(expected: ('Addresses cannot be the same',))]
    fn test_migrate_initializer_revert_same() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(
            ref state, contracts.source, contracts.source, SLOT, VALUE
        );
    }

    #[test]
    #[available_gas(20_000_000)]
    #[should_panic(expected: ('Value must be positive',))]
    fn test_migrate_initializer_revert_null_value() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(ref state, contracts.source, contracts.target, SLOT, 0);
    }

    #[test]
    #[available_gas(20_000_000)]
    fn test_migrate_single() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(
            ref state, contracts.source, contracts.target, SLOT, VALUE
        );
        let erc721 = IERC721Dispatcher { contract_address: contracts.source };
        let initial_balance = erc721.balance_of(signers.anyone);
        // [Assert] Approve and Migrate
        set_contract_address(signers.anyone);
        erc721.approve(CONTRACT_ADDRESS(), ONE);
        set_contract_address(CONTRACT_ADDRESS());
        set_caller_address(signers.anyone);
        let target_address = Migrate::MigrateImpl::target_address(@state);
        Migrate::MigrateImpl::migrate(ref state, array![ONE].span());
        // [Assert] Anyone has only one left token of source ERC721
        let balance = erc721.balance_of(signers.anyone);
        assert(balance == initial_balance - 1, 'Source balance is incorrect');
        // [Assert] Anyone has the token ONE of the target ERC3525
        let erc721 = IERC721Dispatcher { contract_address: contracts.target };
        let balance = erc721.balance_of(signers.anyone);
        assert(balance == 1, 'Target balance is incorrect');
        // [Assert] The token ONE has VALUE value of the target ERC3525
        let erc3525 = IERC3525Dispatcher { contract_address: contracts.target };
        let value = erc3525.value_of(ONE);
        assert(value == VALUE, 'Target value is incorrect');
        // [Assert] Events
        let event = starknet::testing::pop_log::<Migrate::Migration>(CONTRACT_ADDRESS()).unwrap();
        assert(event.address == signers.anyone, 'Event address is incorrect');
        assert(event.token_id == ONE, 'Event token_id is incorrect');
        assert(event.new_token_id == 1, 'Event new_token_id is incorrect');
        assert(event.slot == SLOT, 'Event slot is incorrect');
        assert(event.value == VALUE, 'Event value is incorrect');
    }

    #[test]
    #[available_gas(20_000_000)]
    fn test_migrate_multi() {
        // [Setup]
        let (signers, contracts) = setup();
        let mut state = STATE();
        Migrate::InternalImpl::initializer(
            ref state, contracts.source, contracts.target, SLOT, VALUE
        );
        let erc721 = IERC721Dispatcher { contract_address: contracts.source };
        let initial_balance = erc721.balance_of(signers.anyone);
        // [Assert] Approve and Migrate
        set_contract_address(signers.anyone);
        erc721.approve(CONTRACT_ADDRESS(), ONE);
        erc721.approve(CONTRACT_ADDRESS(), TWO);
        set_contract_address(CONTRACT_ADDRESS());
        set_caller_address(signers.anyone);
        let target_address = Migrate::MigrateImpl::target_address(@state);
        Migrate::MigrateImpl::migrate(ref state, array![ONE, TWO].span());
        // [Assert] Anyone has only one left token of source ERC721
        let balance = erc721.balance_of(signers.anyone);
        assert(balance == initial_balance - 2, 'Source balance is incorrect');
        // [Assert] Anyone has the token ONE of the target ERC3525
        let erc721 = IERC721Dispatcher { contract_address: contracts.target };
        let balance = erc721.balance_of(signers.anyone);
        assert(balance == 1, 'Target balance is incorrect');
        // [Assert] The token ONE has VALUE value of the target ERC3525
        let erc3525 = IERC3525Dispatcher { contract_address: contracts.target };
        let value = erc3525.value_of(ONE);
        assert(value == 2 * VALUE, 'Target value is incorrect');
    }
}
