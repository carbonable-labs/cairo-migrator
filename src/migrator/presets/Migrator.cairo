// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from migrator.library import Migrator

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    source_address: felt, target_address: felt, slot: Uint256, value: Uint256
) {
    Migrator.initializer(source_address, target_address, slot, value);
    return ();
}

//
// Getters
//

@view
func source_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    let (address) = Migrator.source_address();
    return (address=address);
}

@view
func target_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    address: felt
) {
    let (address) = Migrator.target_address();
    return (address=address);
}

@view
func slot{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (slot: Uint256) {
    let (slot) = Migrator.slot();
    return (slot=slot);
}

@view
func value{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (value: Uint256) {
    let (value) = Migrator.value();
    return (value=value);
}

//
// Externals
//

@external
func migrate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: Uint256) -> (
    newTokenId: Uint256
) {
    let (new_token_id) = Migrator.migrate(token_id=tokenId);
    return (newTokenId=new_token_id);
}
