// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Proxy for an ID
 */

abstract contract ProxyId {

    /**
     * @dev Client must return true if the given requester is authorised to act as this identity in the given role(s)
     *
     * A role is a 256-bit field where each bit represents a role
     */
    function isAuthorized( address requester, uint role ) public virtual view returns (bool);

}


