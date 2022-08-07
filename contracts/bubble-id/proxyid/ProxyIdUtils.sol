// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ProxyId.sol";

/**
 * Utility functions and constants for use with the ProxyId isAuthorized function.
 */

library ProxyIdUtils {
    
    // @dev see proxy-roles.txt
    uint constant ADMIN_ROLE = 1<<255;

    /**
     * @dev returns true if the given address is a contract deployed on chain.
     *
     * Warning: This function, and consequently isProxyId and canSignFor, will return false 
     * if called from the constructor of a contract with 'this' as the addr parameter.  
     * i.e. the following contract constructor will return false: 
     *      constructor() { require(isContract(this)) }
     */
    function _isContract(address addr) private view returns (bool) {
        uint32 size;
        assembly { size := extcodesize(addr) }
        return (size > 0);
    }

    /**
     * @dev Returns true if the given address is a contract and has an isAuthorized method.
     */
    function _isProxyId(address addr) private view returns (bool) {
        if (!_isContract(addr)) return false;
        try ProxyId(addr).isAuthorized(address(0), 0) returns (bool) {
            return true;
        }
        catch {
            return false;
        }
    }

    /**
     * @dev Returns true if the given signatory account is authorized to act on behalf of the given
     * Proxy ID (or if the proxy is the signatory).
     */
    function isAuthorizedFor(address signatory, uint role, address addressOrProxy) internal view returns (bool) {
        return isAuthorizedFor(signatory, role, addressOrProxy, role);
    }

    /**
     * @dev returns true if either:
     *   - the two addresses are the same, and the signatory has all the roles required by the proxy; 
     *   - the second address is a ProxyId and the first is authorized to sign as that proxy.
     */
    function isAuthorizedFor(address signatory, uint requiredRoles, address addressOrProxy, uint permittedRoles ) internal view returns (bool) {
        bool addr2IsProxy = _isProxyId(addressOrProxy);
        bool hasRoles = (permittedRoles & ADMIN_ROLE) == ADMIN_ROLE || (requiredRoles & permittedRoles) == requiredRoles;
        if (signatory == addressOrProxy) return hasRoles;
        else if (addr2IsProxy) return hasRoles && ProxyId(addressOrProxy).isAuthorized(signatory, requiredRoles);
        else return false;
    }
    
}
