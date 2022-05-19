// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Singleton contract that can be used by any contract function to assert that a 
 * nonce has not been used before on this chain.
 */
contract NonceRegistry {

    mapping (bytes32 => bool) private usedNonces;
    
    function registerNonce(bytes32 nonce) public {
        require(!usedNonces[nonce], "nonce already used");
        usedNonces[nonce] = true;
    }
    
}

