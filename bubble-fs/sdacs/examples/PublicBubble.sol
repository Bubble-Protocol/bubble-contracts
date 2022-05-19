// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../SDAC.sol";

/**
 * @dev The simplest of all bubbles!  All files are public with rwa rights for all.
 */
contract PublicBubble is SDAC {

    bool terminated = false;

    function getPermissions(address requester, address file) public pure override returns (bytes1) {
        return READ_BIT | WRITE_BIT | APPEND_BIT;
    }

    function hasExpired() public view override returns (bool) {
        return terminated;
    }

    function terminate() public override {
        require(msg.sender == owner, "permission denied");
        terminated = true;
    }

}