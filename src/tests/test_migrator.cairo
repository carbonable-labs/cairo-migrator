// Starknet deps
use starknet::ContractAddress;
use starknet::testing::set_contract_address;

// External deps
use cairo_erc_3525::interface::{IERC3525Dispatcher, IERC3525DispatcherTrait};
use openzeppelin::account::account::Account;
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

// Project deps
use migrator::tests::mocks::erc721::{
    ERC721, IERC721MintableDispatcher, IERC721MintableDispatcherTrait
};
use migrator::tests::mocks::erc3525::ERC3525;
use migrator::components::migrate::interface::{IMigrateDispatcher, IMigrateDispatcherTrait};
use migrator::contracts::migrator::Migrator;

// Constants
const SLOT: u256 = 1;
const VALUE: u256 = 10;
const ONE: u256 = 1;
const TWO: u256 = 2;
const THREE: u256 = 3;

#[derive(Drop)]
struct Signers {
    owner: ContractAddress,
    anyone: ContractAddress,
}

#[derive(Drop)]
struct Contracts {
    source: ContractAddress,
    target: ContractAddress,
    migrator: ContractAddress,
}

fn deploy_account(
    class_hash: starknet::class_hash::ClassHash, public_key: felt252
) -> ContractAddress {
    let calldata: Array<felt252> = array![public_key];
    let (address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
    address
}

fn deploy_mock(class_hash: starknet::class_hash::ClassHash) -> ContractAddress {
    let calldata: Array<felt252> = array![];
    let (address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
    address
}

fn deploy_migrator(
    class_hash: starknet::class_hash::ClassHash,
    source: ContractAddress,
    target: ContractAddress,
    slot: u256,
    value: u256,
    owner: ContractAddress
) -> ContractAddress {
    let calldata: Array<felt252> = array![
        source.into(),
        target.into(),
        slot.low.into(),
        slot.high.into(),
        value.low.into(),
        value.high.into(),
        owner.into()
    ];
    let (address, _) = starknet::deploy_syscall(class_hash, 0, calldata.span(), false).unwrap();
    address
}

fn setup() -> (Signers, Contracts) {
    let source = deploy_mock(ERC721::TEST_CLASS_HASH.try_into().unwrap());
    let target = deploy_mock(ERC3525::TEST_CLASS_HASH.try_into().unwrap());
    let owner = deploy_account(Account::TEST_CLASS_HASH.try_into().unwrap(), 'OWNER');
    let anyone = deploy_account(Account::TEST_CLASS_HASH.try_into().unwrap(), 'ANYONE');
    let migrator = deploy_migrator(
        Migrator::TEST_CLASS_HASH.try_into().unwrap(), source, target, SLOT, VALUE, owner
    );
    let erc721 = IERC721MintableDispatcher { contract_address: source };
    erc721.mint(anyone, ONE);
    erc721.mint(anyone, TWO);
    erc721.mint(anyone, THREE);
    (Signers { owner, anyone }, Contracts { source, target, migrator })
}

#[test]
#[available_gas(20_000_000)]
fn test_migrator_migrate() {
    // [Setup]
    let (signers, contracts) = setup();
    // [Assert] Approve and Migrate
    set_contract_address(signers.anyone);
    let erc721 = IERC721Dispatcher { contract_address: contracts.source };
    erc721.set_approval_for_all(contracts.migrator, true);
    let migrator = IMigrateDispatcher { contract_address: contracts.migrator };
    let token_id = migrator.migrate(array![ONE, TWO, THREE].span());
    // [Assert] Value
    let erc3525 = IERC3525Dispatcher { contract_address: contracts.target };
    let value = erc3525.value_of(token_id);
    assert(value == 3 * VALUE, 'Wrong value');
}
