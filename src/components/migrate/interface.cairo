#[starknet::interface]
trait IMigrate<TContractState> {
    fn source_address(self: @TContractState) -> starknet::ContractAddress;
    fn target_address(self: @TContractState) -> starknet::ContractAddress;
    fn slot(self: @TContractState) -> u256;
    fn value(self: @TContractState) -> u256;
    fn migrate(ref self: TContractState, token_ids: Span<u256>) -> u256;
}

#[starknet::interface]
trait IERC721Burnable<TContractState> {
    fn burn(ref self: TContractState, tokenId: u256);
}

#[starknet::interface]
trait IERC3525Mintable<TContractState> {
    fn mint(
        ref self: TContractState, to: starknet::ContractAddress, slot: u256, value: u256
    ) -> u256;
}
