// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

// Project dependencies
from erc3525.IERC3525Full import IERC3525Full

//
// Events
//

@event
func Migration(
    address: felt, tokenId: Uint256, newTokenId: Uint256, slot: Uint256, value: Uint256
) {
}

//
// Storages
//

@storage_var
func Migrator_source_address_() -> (address: felt) {
}

@storage_var
func Migrator_target_address_() -> (address: felt) {
}

@storage_var
func Migrator_slot_() -> (slot: Uint256) {
}

@storage_var
func Migrator_value_() -> (value: Uint256) {
}

namespace Migrator {
    //
    // Constructor
    //

    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        source_address: felt, target_address: felt, slot: Uint256, value: Uint256
    ) {
        alloc_locals;

        // [Check] Uint256 compliance
        with_attr error_message("Migrator: slot is not a valid Uint256") {
            uint256_check(slot);
        }
        with_attr error_message("Migrator: value is not a valid Uint256") {
            uint256_check(value);
        }

        // [Check] addresses are not null
        with_attr error_message("Migrator: source cannot be the null address") {
            assert_not_zero(source_address);
        }
        with_attr error_message("Migrator: target cannot be the null address") {
            assert_not_zero(target_address);
        }

        // [Check] Value is not null
        let zero = Uint256(low=0, high=0);
        let (is_zero) = uint256_eq(value, zero);
        with_attr error_message("Migrator: value cannot be zero") {
            assert_not_zero(1 - is_zero);
        }

        // [Effect] Store values
        Migrator_source_address_.write(source_address);
        Migrator_target_address_.write(target_address);
        Migrator_slot_.write(slot);
        Migrator_value_.write(value);

        return ();
    }

    //
    // Getters
    //

    func source_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        source_address: felt
    ) {
        let (source_address) = Migrator_source_address_.read();
        return (source_address=source_address);
    }

    func target_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        target_address: felt
    ) {
        let (target_address) = Migrator_target_address_.read();
        return (target_address=target_address);
    }

    func slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        slot: Uint256
    ) {
        let (slot) = Migrator_slot_.read();
        return (slot=slot);
    }

    func value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
        value: Uint256
    ) {
        let (value) = Migrator_value_.read();
        return (value=value);
    }

    //
    // Externals
    //

    func migrate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_id: Uint256
    ) -> (new_token_id: Uint256) {
        alloc_locals;

        // [Check] Uint256 compliance
        with_attr error_message("Migrator: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }

        // [Interaction] Transfer token to the contract
        let (source_address) = Migrator_source_address_.read();
        let (caller) = get_caller_address();
        let (contract_address) = get_contract_address();
        IERC3525Full.transferFrom(
            contract_address=source_address, from_=caller, to=contract_address, tokenId=token_id
        );

        // [Interaction] Burn the token
        IERC3525Full.burn(contract_address=source_address, tokenId=token_id);

        // [Interaction] Mint the new token with the corresponding value
        let (target_address) = Migrator_target_address_.read();
        let (slot) = Migrator_slot_.read();
        let (value) = Migrator_value_.read();

        let (new_token_id) = IERC3525Full.mintNew(
            contract_address=target_address, to=caller, slot=slot, value=value
        );

        // [Effect] Emit event
        Migration.emit(
            address=caller, tokenId=token_id, newTokenId=new_token_id, slot=slot, value=value
        );

        return (new_token_id=new_token_id);
    }
}
