// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

// Local dependencies
from migrator.library import Migrator

// Global variables
const SOURCE = 0x123;
const TARGET = 0x456;
const SLOT = 0x1;
const VALUE = 0x10;

@external
func test_initialization{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    let slot = Uint256(low=SLOT, high=0);
    let value = Uint256(low=VALUE, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [1]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [1]) %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=slot, value=value);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}

@external
func test_initialization_revert_invalid_slot{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let invalid = Uint256(low=-1, high=-1);
    let value = Uint256(low=VALUE, high=0);
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: slot is not a valid Uint256") %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=invalid, value=value);
    return ();
}

@external
func test_initialization_revert_invalid_value{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let invalid = Uint256(low=-1, high=-1);
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: value is not a valid Uint256") %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=slot, value=invalid);
    return ();
}

@external
func test_initialization_revert_not_erc721{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let value = Uint256(low=VALUE, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [0]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [1]) %}
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: source does not support EIP-721 interface") %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=slot, value=value);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}

@external
func test_initialization_revert_not_erc3525{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let value = Uint256(low=VALUE, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [1]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [0]) %}
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: target does not support EIP-3525 interface") %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=slot, value=value);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}

@external
func test_initialization_revert_null_source{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let value = Uint256(low=VALUE, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [1]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [1]) %}
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: source cannot be the null address") %}
    Migrator.initializer(source_address=0, target_address=TARGET, slot=slot, value=value);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}

@external
func test_initialization_revert_null_target{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let value = Uint256(low=VALUE, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [1]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [1]) %}
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: target cannot be the null address") %}
    Migrator.initializer(source_address=SOURCE, target_address=0, slot=slot, value=value);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}

@external
func test_initialization_revert_null_value{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    let slot = Uint256(low=SLOT, high=0);
    let zero = Uint256(low=0, high=0);
    %{ stop_mock_source = mock_call(ids.SOURCE, "supportsInterface", [1]) %}
    %{ stop_mock_target = mock_call(ids.TARGET, "supportsInterface", [1]) %}
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: value cannot be zero") %}
    Migrator.initializer(source_address=SOURCE, target_address=TARGET, slot=slot, value=zero);
    %{ stop_mock_source() %}
    %{ stop_mock_target() %}
    return ();
}
