use starknet::ContractAddress;

#[starknet::contract]
mod Migrator {
    // Starknet deps
    use starknet::{get_caller_address, ContractAddress, ClassHash};

    // Ownable
    use openzeppelin::access::ownable::interface::IOwnable;
    use openzeppelin::access::ownable::ownable::Ownable;

    // Upgradable
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::upgrades::upgradeable::Upgradeable;

    // Migrate
    use migrator::components::migrate::interface::IMigrate;
    use migrator::components::migrate::module::Migrate;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(
        ref self: ContractState,
        source_address: ContractAddress,
        target_address: ContractAddress,
        slot: u256,
        value: u256,
        owner: ContractAddress
    ) {
        self.initializer(source_address, target_address, slot, value, owner);
    }

    // Upgradable

    #[external(v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            // [Check] Only owner
            let unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::assert_only_owner(@unsafe_state);
            // [Effect] Upgrade
            let mut unsafe_state = Upgradeable::unsafe_new_contract_state();
            Upgradeable::InternalImpl::_upgrade(ref unsafe_state, impl_hash)
        }
    }

    // Access control

    #[external(v0)]
    impl OwnableImpl of IOwnable<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::owner(@unsafe_state)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, new_owner)
        }

        fn renounce_ownership(ref self: ContractState) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::renounce_ownership(ref unsafe_state)
        }
    }

    #[external(v0)]
    impl MigrateImpl of IMigrate<ContractState> {
        fn source_address(self: @ContractState) -> ContractAddress {
            let unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::MigrateImpl::source_address(@unsafe_state)
        }

        fn target_address(self: @ContractState) -> ContractAddress {
            let unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::MigrateImpl::target_address(@unsafe_state)
        }

        fn slot(self: @ContractState) -> u256 {
            let unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::MigrateImpl::slot(@unsafe_state)
        }

        fn value(self: @ContractState) -> u256 {
            let unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::MigrateImpl::value(@unsafe_state)
        }

        fn migrate(ref self: ContractState, token_ids: Span<u256>) -> u256 {
            let mut unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::MigrateImpl::migrate(ref unsafe_state, token_ids)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(
            ref self: ContractState,
            source_address: ContractAddress,
            target_address: ContractAddress,
            slot: u256,
            value: u256,
            owner: ContractAddress
        ) {
            // Access control
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::InternalImpl::initializer(ref unsafe_state, owner);

            // Migrate
            let mut unsafe_state = Migrate::unsafe_new_contract_state();
            Migrate::InternalImpl::initializer(
                ref unsafe_state, source_address, target_address, slot, value
            );
        }
    }
}
