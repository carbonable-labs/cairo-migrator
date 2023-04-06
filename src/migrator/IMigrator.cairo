// SPDX-License-Identifier: MIT

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IMigrator {
    func source_address() -> (address: felt) {
    }

    func target_address() -> (address: felt) {
    }

    func slot() -> (slot: Uint256) {
    }

    func value() -> (value: Uint256) {
    }

    func migrate(tokenIds_len: felt, tokenIds: Uint256*) -> (newTokenId: Uint256) {
    }
}
