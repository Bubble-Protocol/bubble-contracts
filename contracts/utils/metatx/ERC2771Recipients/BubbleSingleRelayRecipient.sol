// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../BubbleRelayRecipient.sol";

/**
 * @title Implementation of BubbleRelayRecipient for a single trusted forwarder.
 *
 * WARNING: trusted forwarders can have complete control over your contract.  Use only forwarder contracts that you
 * trust implicitly.
 *
 * @notice A subclass must ALWAYS use `_msgSender()` instead of `msg.sender`.
 */
contract BubbleSingleRelayRecipient is BubbleRelayRecipient {

    address private _trustedForwarder;

    constructor(address forwarder) {
        _trustedForwarder = forwarder;
    }

    function getTrustedForwarder() public view returns (address forwarder){
        return _trustedForwarder;
    }

    function _setTrustedForwarder(address forwarder) internal {
        _trustedForwarder = forwarder;
    }

    function isTrustedForwarder(address forwarder) public override view returns (bool) {
        return forwarder == _trustedForwarder;
    }

}