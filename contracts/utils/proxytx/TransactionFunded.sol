// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../registries/NonceRegistry.sol";

/**
 * @dev Provides internal functions to support proxy transactions
 *
 * TODO: include chain id to prevent replay attacks
 */
abstract contract TransactionFunded {

    NonceRegistry internal nonceRegistry = NonceRegistry(address(0xd39A1a26d04a0Af8FF334c6d98c2E4D328F45ece));

    function _assertTxIsOriginal(bytes32 hash) internal {
        nonceRegistry.registerNonce(hash);
    }
    
    function _recoverSigner(bytes32 hash, bytes memory signature) internal pure returns (address) {
        if (signature.length != 65) revert("ECDSA: invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
         assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        if (v < 27) v += 27;
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");
        return signer;
    }

}
