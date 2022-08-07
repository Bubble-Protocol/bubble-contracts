// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Base class for implementing ERC2771 recipients compatible with Bubble ID's meta transactions.
 *
 * Based on Open Zeppelin's ERC7221Recipient (v4.7.0).  Adds the _msgRoles() function to return the role(s) 
 * that the meta transaction signatory has over the Bubble ID or account returned by _msgSender().  Supports
 * Bubble ID meta transactions, meta transactions from ordinary accounts and non-meta transactions.
 *
 * Iff the sender is a trusted forwarder then the transaction is assumed to be a meta transaction.  The last 
 * 52-bytes of the call data is therefore expected to contain the 20-byte meta tx sender followed by the 32-byte roles
 * that the originating signatory has over the meta tx sender.
 *
 * If a Bubble ID meta transaction _msgSender() will return the Bubble ID Persona.
 * If an ordinary meta transaction _msgSender() will return the meta transaction signatory.
 * If not a meta transaction _msgSender() will return msg.sender.
 *
 * @notice The trusted forwarder must verify that the originating signatory is authorised for the address and roles
 * passed in the call data.
 * @notice The Trusted Forwarder must append the Bubble ID persona address to the call data followed by the authorised 
 * roles.
 * @notice A subclass must use `_msgSender()` instead of `msg.sender`.
 * @notice A subclass must use `_msgData()` instead of `msg.data`.
 */
abstract contract BubbleRelayRecipient {

    /**
     * @dev Returns true if the given address is a trusted forwarder and false otherwise.
     */
    function isTrustedForwarder(address forwarder) public virtual view returns(bool);

    /**
     * If this is a meta transaction then extract the sender from the first 20-bytes of the last 52-bytes of the
     * call data.  If not, just return msg.sender.
     */
    function _msgSender() internal view virtual returns (address ret) {
        if (msg.data.length >= 52 && isTrustedForwarder(msg.sender)) {
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),52)))
            }
        } else {
            ret = msg.sender;
        }
    }

    /**
     * If this is a meta transaction then remove the last 52-bytes of the call data.
     */
    function _msgData() internal view virtual returns (bytes calldata ret) {
        if (msg.data.length >= 52 && isTrustedForwarder(msg.sender)) {
            return msg.data[0:msg.data.length-52];
        } else {
            return msg.data;
        }
    }

    /**
     * If this is a meta transaction then extract the roles from the last 32-bytes of the call data.  If not, 
     * return all roles (all bits 1) since the sender implicitly has full permission over itself.
     */
    function _msgRoles() internal view virtual returns (uint ret) {
        if (msg.data.length >= 52 && isTrustedForwarder(msg.sender)) {
            assembly {
                ret := calldataload(sub(calldatasize(),32))
            }
        } else {
            ret = ALL_ROLES;
        }
    }

    function _requireRole(uint role) internal view {
        require(_msgRoles() & role > 0, "permission denied");
    }


}


// Authorisation for all roles has all bits high.
uint256 constant ALL_ROLES = 2**256 - 1;
