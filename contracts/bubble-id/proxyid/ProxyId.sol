// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * Proxy for an ID
 *
 * @dev Provides the isAuthorized function that returns true if the given requester is
 * authorised to act as this identity in the given role(s)
 *
 * role is a 256-bit field where each bit represents a role
 */

abstract contract ProxyId {

    function isAuthorized( address requester, uint role ) public virtual view returns (bool);

}


