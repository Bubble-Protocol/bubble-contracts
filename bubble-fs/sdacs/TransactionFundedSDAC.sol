// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SDAC.sol";
import "../../utils/proxytx/TransactionFunded.sol";

/**
 * @dev An SDAC that can be constructed by a transaction proxy server.  
 */
abstract contract TransactionFundedSDAC is SDAC, TransactionFunded {

    /**
     * @dev Owner of the sdac is set based on the given signature of a packet constructed from
     * the given contractType string and the given nonce.
     *
     * Reverts if the signature has been used before on this chain.
     */
    constructor(string memory contractType, uint nonce, bytes memory ownerSignature) {
        bytes32 hash = keccak256(abi.encodePacked(contractType, nonce));
        owner = _recoverSigner(hash, ownerSignature);
        nonceRegistry.registerNonce(hash);
    }
    
}
