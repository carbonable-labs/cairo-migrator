// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_mul
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

// Project dependencies
from openzeppelin.introspection.erc165.IERC165 import IERC165
from openzeppelin.token.erc721.IERC721 import IERC721
from openzeppelin.security.safemath.library import SafeUint256
from openzeppelin.utils.constants.library import IERC721_ID
from erc3525.IERC3525Full import IERC3525Full
from erc3525.utils.constants.library import IERC3525_ID

// Local dependencies
from migrator.IERC721Burnable import IERC721Burnable

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

        // [Check] Addresses are not null
        with_attr error_message("Migrator: source cannot be the null address") {
            assert_not_zero(source_address);
        }
        with_attr error_message("Migrator: target cannot be the null address") {
            assert_not_zero(target_address);
        }

        // [Check] Source is an ERC-721
        let (is_erc721) = IERC165.supportsInterface(
            contract_address=source_address, interfaceId=IERC721_ID
        );
        with_attr error_message("Migrator: source does not support EIP-721 interface") {
            assert_not_zero(is_erc721);
        }

        // [Check] Target is an ERC-3525
        let (is_erc3525) = IERC165.supportsInterface(
            contract_address=target_address, interfaceId=IERC3525_ID
        );
        with_attr error_message("Migrator: target does not support EIP-3525 interface") {
            assert_not_zero(is_erc3525);
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

    func _migrate_all{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_ids_len: felt,
        token_ids: Uint256*,
        slot: Uint256,
        new_token_id: Uint256,
        source: felt,
        caller: felt,
        migrator: felt,
        value: Uint256,
    ) {
        if (token_ids_len == 0) {
            return ();
        }

        let token_id = token_ids[0];

        // [Check] Uint256 compliance
        with_attr error_message("Migrator: token_id is not a valid Uint256") {
            uint256_check(token_id);
        }

        // [Interaction] Transfer token to the contract
        IERC721.transferFrom(contract_address=source, from_=caller, to=migrator, tokenId=token_id);

        // [Interaction] Burn the token
        IERC721Burnable.burn(contract_address=source, tokenId=token_id);

        // [Effect] Emit event
        Migration.emit(
            address=caller, tokenId=token_id, newTokenId=new_token_id, slot=slot, value=value
        );

        return _migrate_all(
            token_ids_len - 1,
            token_ids + Uint256.SIZE,
            slot,
            new_token_id,
            source,
            caller,
            migrator,
            value,
        );
    }

    func migrate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        token_ids_len: felt, token_ids: Uint256*
    ) -> (new_token_id: Uint256) {
        alloc_locals;

        // [Interaction] Mint new token with value
        let num_tokens = Uint256(low=token_ids_len, high=0);
        let (unit_value) = Migrator_value_.read();
        let (value) = SafeUint256.mul(num_tokens, unit_value);
        let (target_address) = Migrator_target_address_.read();
        let (slot) = Migrator_slot_.read();
        let (caller) = get_caller_address();
        let (new_token_id) = IERC3525Full.mintNew(
            contract_address=target_address, to=caller, slot=slot, value=value
        );

        // [Interaction] Transfer and burn old tokens
        let (source_address) = Migrator_source_address_.read();
        let (contract_address) = get_contract_address();

        _migrate_all(
            token_ids_len,
            token_ids,
            slot,
            new_token_id,
            source_address,
            caller,
            contract_address,
            unit_value,
        );

        return (new_token_id=new_token_id);
    }
}
