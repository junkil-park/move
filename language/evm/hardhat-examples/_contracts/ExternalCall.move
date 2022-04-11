#[contract]
/// An implementation of the ERC-1155 Multi Token Standard.
module Evm::ExternalCall {
    #[external(sig=b"forty_two() returns (uint64)")]
    public native fun call_forty_two(contract: address): u64;

    #[external(sig=b"revertWithMessage(string)")]
    public native fun call_revertWithMessage(contract: address, message: vector<u8>);

    #[callable(sig=b"getFortyTwo(address) returns (uint64)"), view]
    public fun getFortyTwo(contract: address): u64 {
        call_forty_two(contract)
    }

    #[callable(sig=b"callRevertWithMessage(address,string)"), pure]
    public fun callRevertWithMessage(contract: address, message: vector<u8>) {
        call_revertWithMessage(contract, message);
    }
}