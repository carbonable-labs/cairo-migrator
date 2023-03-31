// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, assert_uint256_eq

// Local dependencies
from migrator.library import Migrator

// Global variables
const SOURCE = 0x123;
const TARGET = 0x456;
const SLOT = 0x1;
const VALUE = 0x10;
const TOKEN = 1;
const NEW_TOKEN = 2;
const ANYONE = 0x1000;

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
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
func test_migration{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let token_id = Uint256(low=TOKEN, high=0);
    let expected_token_id = Uint256(low=NEW_TOKEN, high=0);

    %{ mock_call(ids.SOURCE, "transferFrom", []) %}
    %{ mock_call(ids.SOURCE, "burn", []) %}
    %{ mock_call(ids.TARGET, "mintNew", [ids.NEW_TOKEN, 0]) %}
    %{
        expect_events(dict(name="Migration", data=dict(
                   address=ids.ANYONE,
                   tokenId=dict(low=ids.TOKEN, high=0),
                   newTokenId=dict(low=ids.NEW_TOKEN, high=0),
                   slot=dict(low=ids.SLOT, high=0),
                   value=dict(low=ids.VALUE, high=0),
               )))
    %}
    %{ start_prank(ids.ANYONE) %}
    tempvar tokens = new (token_id);
    let (new_token_id) = Migrator.migrate(token_ids_len=1, token_ids=tokens);
    with_attr error_message("TestMigration: unexpect token id") {
        assert_uint256_eq(new_token_id, expected_token_id);
    }

    return ();
}

@external
func test_migration_multiple{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    alloc_locals;

    let token1 = Uint256(low=TOKEN + 0, high=0);
    let token2 = Uint256(low=TOKEN + 1, high=0);
    let token3 = Uint256(low=TOKEN + 2, high=0);
    let expected_token_id = Uint256(low=NEW_TOKEN, high=0);

    %{ mock_call(ids.SOURCE, "transferFrom", []) %}
    %{ mock_call(ids.SOURCE, "burn", []) %}
    %{ mock_call(ids.TARGET, "mintNew", [ids.NEW_TOKEN, 0]) %}
    %{
        expect_events(dict(name="Migration", data=dict(
                   address=ids.ANYONE,
                   tokenId=dict(low=ids.TOKEN, high=0),
                   newTokenId=dict(low=ids.NEW_TOKEN, high=0),
                   slot=dict(low=ids.SLOT, high=0),
                   value=dict(low=ids.VALUE, high=0),
               )))
    %}
    %{ start_prank(ids.ANYONE) %}
    tempvar tokens: Uint256* = cast(new (token1, token2, token3), Uint256*);
    let (new_token_id) = Migrator.migrate(token_ids_len=3, token_ids=tokens);
    with_attr error_message("TestMigration: unexpect token id") {
        assert_uint256_eq(new_token_id, expected_token_id);
    }

    return ();
}

@external
func test_migration_revert_invalid_token{
    syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*
}() {
    alloc_locals;

    let token_id = Uint256(low=-1, high=-1);
    %{ expect_revert("TRANSACTION_FAILED", "Migrator: token_id is not a valid Uint256") %}
    %{ mock_call(ids.TARGET, "mintNew", [ids.NEW_TOKEN, 0]) %}
    tempvar tokens = new (token_id);
    let (new_token_id) = Migrator.migrate(token_ids_len=1, token_ids=tokens);

    return ();
}
