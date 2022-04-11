#[contract]
/// An implementation of the ERC-721 Non-Fungible Token Standard.
module Evm::ERC721 {
    use Evm::Evm::{sender, self, sign, emit, isContract, tokenURI_with_baseURI, require};
    use Evm::Result;
    // use Evm::IERC721Receiver;
    // use Evm::IERC721Metadata;
    // use Evm::IERC721;
    // use Evm::IERC165;
    use Evm::Table::{Self, Table};
    use Evm::U256::{Self, U256};
    use Std::Errors;
    use Std::Vector;

    // ---------------------
    // Evm::IERC165
    // ---------------------
    public fun IERC165_interfaceId(): vector<u8> {
        // TODO: Eager evaulate this at the compile time for optimization.
        //bytes4(keccak256(b"supportsInterface(bytes4)"))
        x"01ffc9a7"
    }

    // ---------------------
    // Evm::IERC721
    // ---------------------
    public fun IERC721_interfaceId(): vector<u8> {
        x"80ac58cd"
    }

    // ---------------------
    // Evm::IERC721Metadata
    // ---------------------
    public fun IERC721Metadata_interfaceId(): vector<u8> {
        x"5b5e139f"
    }

    // ---------------------
    // For test only
    // ---------------------

    #[callable]
    public fun mint(to: address, tokenId: U256) acquires State {
        mint_(to, tokenId);
    }

    fun mint_(to: address, tokenId: U256) acquires State  {
        require(to != @0x0, b"ERC721: mint to the zero address");
        require(!exists_(tokenId), b"ERC721: token already minted");

        let s = borrow_global_mut<State>(self());
        let mut_balance_to = mut_balanceOf(s, to);
        *mut_balance_to = U256::add(*mut_balance_to, U256::one());

        let mut_ownerOf_to = mut_ownerOf(s, tokenId);
        *mut_ownerOf_to = to;

        emit(Transfer{from: @0x0, to, tokenId});
    }

    #[callable]
    public fun burn(tokenId: U256) acquires State {
        burn_(tokenId);
    }

    fun burn_(tokenId: U256) acquires State {
        let owner = ownerOf(tokenId);
        approve(@0x0, tokenId);
        let s = borrow_global_mut<State>(self());
        let mut_balance_owner = mut_balanceOf(s, owner);
        *mut_balance_owner = U256::sub(*mut_balance_owner, U256::one());
        let _ = Table::remove(&mut s.owners, &tokenId);
        emit(Transfer{from: owner, to: @0x0, tokenId});
    }

    fun exists_(tokenId: U256): bool acquires State {
        let s = borrow_global_mut<State>(self());
        tokenExists(s, tokenId)
    }

    #[event]
    struct Transfer {
        from: address,
        to: address,
        tokenId: U256,
    }

    #[event]
    struct Approval {
        owner: address,
        approved: address,
        tokenId: U256,
    }

    #[event]
    struct ApprovalForAll {
        owner: address,
        operator: address,
        approved: bool,
    }

    #[storage]
    /// Represents the state of this contract. This is located at `borrow_global<State>(self())`.
    struct State has key {
        name: vector<u8>,
        symbol: vector<u8>,
        owners: Table<U256, address>,
        balances: Table<address, U256>,
        tokenApprovals: Table<U256, address>,
        operatorApprovals: Table<address, Table<address, bool>>,
    }

    #[create(sig=b"constructor(string,string)")]
    /// Constructor of this contract.
    public fun create(name: vector<u8>, symbol: vector<u8>) {
        // Initial state of contract
        move_to<State>(
            &sign(self()),
            State {
                name,
                symbol,
                owners: Table::empty<U256, address>(),
                balances: Table::empty<address, U256>(),
                tokenApprovals: Table::empty<U256, address>(),
                operatorApprovals: Table::empty<address, Table<address, bool>>(),
            }
        );
    }

    #[callable(sig=b"supportsInterface(bytes4) returns (bool)"), pure]
    // Query if this contract implements a certain interface.
    public fun supportsInterface(interfaceId: vector<u8>): bool {
        // 33279
        // let b0 = *Vector::borrow(&interfaceId, 0);
        // let b1 = *Vector::borrow(&interfaceId, 1);
        // let b2 = *Vector::borrow(&interfaceId, 2);
        // let b3 = *Vector::borrow(&interfaceId, 3);

        let b3 = Vector::pop_back(&mut interfaceId);
        let b2 = Vector::pop_back(&mut interfaceId);
        let b1 = Vector::pop_back(&mut interfaceId);
        let b0 = Vector::pop_back(&mut interfaceId); // appox. 440 gas

        // 33737
        // ERC165
        (b0 == 1 &&
            b1 == 255 &&
            b2 == 201 &&
            b3 == 167
        ) ||
        // ERC721
        (b0 == 128 &&
            b1 == 172 &&
            b2 == 88 &&
            b3 == 205
        ) ||
        // ERC721Metadata (5b5e139f)
        (b0 == 91 &&
            b1 == 94 &&
            b2 == 19 &&
            b3 == 159
        )

        // TODO: Exceeds the gas limit (33834 > 30000)
        // // ERC721Metadata (5b5e139f)
        // (*Vector::borrow(&interfaceId, 0) == 91 &&
        //     *Vector::borrow(&interfaceId, 1) == 94 &&
        //     *Vector::borrow(&interfaceId, 2) == 19 &&
        //     *Vector::borrow(&interfaceId, 3) == 159
        // ) ||
        // // ERC165
        // (*Vector::borrow(&interfaceId, 0) == 1 &&
        //     *Vector::borrow(&interfaceId, 1) == 255 &&
        //     *Vector::borrow(&interfaceId, 2) == 201 &&
        //     *Vector::borrow(&interfaceId, 3) == 167
        // ) ||
        // // ERC721
        // (*Vector::borrow(&interfaceId, 0) == 128 &&
        //     *Vector::borrow(&interfaceId, 1) == 172 &&
        //     *Vector::borrow(&interfaceId, 2) == 88 &&
        //     *Vector::borrow(&interfaceId, 3) == 205
        // )
    }

    #[callable(sig=b"name() returns (string)"), view]
    /// Get the name.
    public fun name(): vector<u8> acquires State {
        let s = borrow_global<State>(self());
        *&s.name
    }

    #[callable(sig=b"symbol() returns (string)"), view]
    /// Get the symbol.
    public fun symbol(): vector<u8> acquires State {
        let s = borrow_global<State>(self());
        *&s.symbol
    }

    #[callable(sig=b"tokenURI(uint256) returns (string)"), view]
    /// Get the name.
    public fun tokenURI(tokenId: U256): vector<u8> acquires State {
        require(exists_(tokenId), b"ERC721Metadata: URI query for nonexistent token");
        let baseURI = b""; // TODO: Add a proper base URI.
        tokenURI_with_baseURI(baseURI, tokenId)
    }

    #[callable(sig=b"balanceOf(address) returns (uint256)"), view]
    /// Count all NFTs assigned to an owner.
    public fun balanceOf(owner: address): U256 acquires State {
        require(owner != @0x0, b"ERC721: balance query for the zero address");
        let s = borrow_global_mut<State>(self());
        *mut_balanceOf(s, owner)
    }

    #[callable(sib=b"ownerOf(uint256) returns (address)"), view]
    /// Find the owner of an NFT.
    public fun ownerOf(tokenId: U256): address acquires State {
        require(exists_(tokenId), b"ERC721: owner query for nonexistent token");
        let s = borrow_global_mut<State>(self());
        *mut_ownerOf(s, tokenId)
    }

    #[callable(sig=b"safeTransferFrom(address,address,uint256,bytes)")] // Overloading `safeTransferFrom`
    /// Transfers the ownership of an NFT from one address to another address.
    public fun safeTransferFrom_with_data(from: address, to: address, tokenId: U256, data: vector<u8>) acquires State {
        transferFrom(from, to, tokenId);
        //doSafeTransferAcceptanceCheck(from, to, tokenId, data);
    }

    #[callable(sig=b"safeTransferFrom(address,address,uint256)")]
    /// Transfers the ownership of an NFT from one address to another address.
    public fun safeTransferFrom(from: address, to: address, tokenId: U256) acquires State {
        safeTransferFrom_with_data(from, to, tokenId, b"");
    }

    #[callable]
    /// Transfer ownership of an NFT. THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    public fun transferFrom(from: address, to: address, tokenId: U256) acquires State {
        require(isApprovedOrOwner(sender(), tokenId), b"ERC721: transfer caller is not owner nor approved");

        require(ownerOf(tokenId) == from, b"ERC721: transfer from incorrect owner");
        require(to != @0x0, b"ERC721: transfer to the zero address");

        // Clear approvals from the previous owner
        approve_(@0x0, tokenId);

        let s = borrow_global_mut<State>(self());

        let mut_balance_from = mut_balanceOf(s, from);
        *mut_balance_from = U256::sub(*mut_balance_from, U256::one());

        let mut_balance_to = mut_balanceOf(s, to);
        *mut_balance_to = U256::add(*mut_balance_to, U256::one());

        let mut_owner_token = mut_ownerOf(s, tokenId);
        *mut_owner_token = to;

        emit(Transfer{from, to, tokenId});
    }

    #[callable]
    /// Change or reaffirm the approved address for an NFT.
    public fun approve(approved: address, tokenId: U256) acquires State {
        let owner = ownerOf(tokenId);
        require(approved != owner, b"ERC721: approval to current owner");
        require((sender() == owner) || isApprovedForAll(owner, sender()), b"ERC721: approve caller is not owner nor approved for all");
        approve_(approved, tokenId);
    }

    fun approve_(approved: address, tokenId: U256) acquires State {
        let s = borrow_global_mut<State>(self());
        *mut_tokenApproval(s, tokenId) = approved;
        emit(Approval{owner: ownerOf(tokenId), approved, tokenId})
    }

    #[callable]
    /// Enable or disable approval for a third party ("operator") to manage
    ///  all of the sender's assets.
    public fun setApprovalForAll(operator: address, approved: bool) acquires State {
        setApprovalForAll_(sender(), operator, approved);
    }

    fun setApprovalForAll_(owner: address, operator: address, approved: bool) acquires State {
        require(owner != operator, b"ERC721: approve to caller");
        let s = borrow_global_mut<State>(self());
        *mut_operatorApproval(s, owner, operator) = approved;
        emit(ApprovalForAll{owner, operator, approved})
    }

    #[callable, view]
    /// Get the approved address for a single NFT.
    public fun getApproved(tokenId: U256): address acquires State {
        let s = borrow_global_mut<State>(self());
        require(tokenExists(s, tokenId), b"ERC721: approved query for nonexistent token");
        *mut_tokenApproval(s, tokenId)
    }

    #[callable, view]
    /// Query if an address is an authorized operator for another address.
    public fun isApprovedForAll(owner: address, operator: address): bool acquires State {
        let s = borrow_global_mut<State>(self());
        *mut_operatorApproval(s, owner, operator)
    }

    /// Helper function to return true iff `spender` is the owner or an approved one for `tokenId`.
    fun isApprovedOrOwner(spender: address, tokenId: U256): bool acquires State {
        let s = borrow_global_mut<State>(self());
        require(tokenExists(s, tokenId), b"ERC721: operator query for nonexistent token");
        let owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender))
    }

    /// Helper function to return a mut ref to the balance of a owner.
    fun mut_balanceOf(s: &mut State, owner: address): &mut U256 {
        Table::borrow_mut_with_default(&mut s.balances, &owner, U256::zero())
    }

    /// Helper function to return a mut ref to the balance of a owner.
    fun mut_ownerOf(s: &mut State, tokenId: U256): &mut address {
        Table::borrow_mut_with_default(&mut s.owners, &tokenId, @0x0)
    }

    /// Helper function to return a mut ref to the balance of a owner.
    fun mut_tokenApproval(s: &mut State, tokenId: U256): &mut address {
        Table::borrow_mut_with_default(&mut s.tokenApprovals, &tokenId, @0x0)
    }

    /// Helper function to return a mut ref to the operator approval.
    fun mut_operatorApproval(s: &mut State, owner: address, operator: address): &mut bool {
        if(!Table::contains(&s.operatorApprovals, &owner)) {
            Table::insert(
                &mut s.operatorApprovals,
                &owner,
                Table::empty<address, bool>()
            )
        };
        let approvals = Table::borrow_mut(&mut s.operatorApprovals, &owner);
        Table::borrow_mut_with_default(approvals, &operator, false)
    }

    /// Helper function to return true iff the token exists.
    fun tokenExists(s: &mut State, tokenId: U256): bool {
        let mut_ownerOf_tokenId = mut_ownerOf(s, tokenId);
        *mut_ownerOf_tokenId != @0x0
    }

    // /// Helper function for the acceptance check.
    // fun doSafeTransferAcceptanceCheck(from: address, to: address, tokenId: U256, data: vector<u8>) {
    //     if (isContract(to)) {
    //         let result = IERC721Receiver::try_call_onERC721Received(to, sender(), from, tokenId, data);
    //         if (Result::is_ok(&result)) {
    //             let retval = Result::unwrap(result);
    //             let expected = IERC721Receiver::selector_onERC721Received();
    //             assert!(retval == expected, Errors::custom(0));
    //         }
    //         else {
    //             let error_reason = Result::unwrap_err(result);
    //             if(Vector::length(&error_reason) == 0) {
    //                 abort(Errors::custom(1)) // ERC721: transfer to non ERC721Receiver implementer
    //             }
    //             else {
    //                 abort(Errors::custom(2)) // TODO: abort with the `_error` value.
    //             }
    //         }
    //     }
    // }
}
