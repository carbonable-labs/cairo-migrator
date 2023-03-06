// SPDX-License-Identifier: MIT

%lang starknet

// Starkware dependencies
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256

from openzeppelin.token.erc721.IERC721 import IERC721
from erc3525.IERC3525Full import IERC3525Full

from migrator.IMigrator import IMigrator

const OWNER = 0x1000;
const ANYONE = 0x1001;
const SLOT = 0x1;
const VALUE = 0x10;

@contract_interface
namespace IERC721Mintable {
    func mint(to: felt, tokenId: Uint256) {
    }
}

@view
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar source_address;
    tempvar contract_address;
    %{
        context.source_address = deploy_contract(
            contract="./lib/cairo_contracts/src/openzeppelin/token/erc721/presets/ERC721MintableBurnable.cairo",
            constructor_args={
                "name": 'name',
                "symbol": 'symbol',
                "owner": ids.OWNER,
            }
        ).contract_address
        context.target_address = deploy_contract(
            contract="./lib/cairo_erc_3525/src/erc3525/presets/ERC3525MintableBurnable.cairo",
            constructor_args={
                "name": 'name',
                "symbol": 'symbol',
                "decimals": 2,
            }
        ).contract_address
        context.contract_address = deploy_contract(
            contract="./src/migrator/presets/Migrator.cairo",
            constructor_args={
                "source_address": context.source_address,
                "target_address": context.target_address,
                "slot": dict(low=ids.SLOT, high=0),
                "value": dict(low=ids.VALUE, high=0)
            }
        ).contract_address
        ids.source_address = context.source_address
        ids.contract_address = context.contract_address
    %}

    let token_id = Uint256(low=1, high=0);

    %{ stop_prank = start_prank(caller_address=ids.OWNER, target_contract_address=context.source_address) %}
    IERC721Mintable.mint(contract_address=source_address, to=ANYONE, tokenId=token_id);
    %{ stop_prank() %}

    %{ stop_prank = start_prank(caller_address=ids.ANYONE, target_contract_address=context.source_address) %}
    IERC721.setApprovalForAll(
        contract_address=source_address, operator=contract_address, approved=1
    );
    %{ stop_prank() %}

    return ();
}

@view
func test_migrate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local contract_address;
    %{
        ids.contract_address = context.contract_address
        start_prank(caller_address=ids.ANYONE, target_contract_address=context.contract_address)
        start_prank(caller_address=context.contract_address, target_contract_address=context.source_address)
    %}

    let token_id = Uint256(low=1, high=0);
    let (new_token_id) = IMigrator.migrate(contract_address=contract_address, tokenId=token_id);

    return ();
}
