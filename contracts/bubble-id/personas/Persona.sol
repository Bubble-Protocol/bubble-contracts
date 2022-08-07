// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PersonaSDAC.sol";
import "../proxyid/ProxyId.sol";
import "../proxyid/ProxyIdUtils.sol";
import "../../bubble-fs/sdacs/SDAC.sol";
import "../metatx/ERC2771Recipients/BubbleSingleRelayRecipient.sol";

/** 
 * Persona v0.0.4
 *
 * @dev Bubble ID for a specific persona or application.  Implemented as a ProxyId to allow different 
 * keys or ProxyIds to sign as this persona.  This ID can also be used to control a bubble provided
 * an SDAC has been set via the setBubble function.
 *
 * WARNING: apps should give thought to whether they allow ProxyId contracts to be registered as proxies
 */

struct Proxy {
    address id;
    uint role;
}

contract Persona is ProxyId, SDAC, BubbleSingleRelayRecipient {
    
    PersonaSDAC public bubble;
    Proxy[] public proxies;
    bool public locked = false;

    /**
     * Gives the sender, and any given addresses, admin rights over this persona.  The sender is classed as the
     * owner and cannot be subsequently changed.
     */
    constructor(address trustedForwarder, address[] memory adminProxies) 
    BubbleSingleRelayRecipient(trustedForwarder)
    {
        proxies.push(Proxy(_msgSender(), Roles.ADMIN_ROLE));
        for (uint i=0; i<adminProxies.length; i++) {
            proxies.push(Proxy(adminProxies[i], Roles.ADMIN_ROLE));
        }
    }

    /**
     * @dev Authorises the given account or ProxyId to act on behalf of this ID under the given
     * role.  If role is 0 then this account or ProxyId is deregistered.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function registerProxy(address proxy, uint role) public onlyAdmin {
        require(proxy != proxies[0].id, "cannot change owner's role");
        uint index = proxies.length;
        for (uint i=0; i<proxies.length; i++) {
            if (proxy == proxies[i].id) index = i;
        }
        if (role > 0) {
          if (index == proxies.length) proxies.push(Proxy(proxy, role));
          else proxies[index].role = role;
        }
        else {
          require(index != proxies.length, "proxy does not exist");
          proxies[index] = proxies[proxies.length-1];
          proxies.pop();
        }
    }

    /**
     * @dev Changes the owner (normally the genesis key) of this persona
     */
    function changeOwner(address newOwner) public {
        require(_msgSender() == owner, "permission denied");
        owner = newOwner;
        proxies[0] = Proxy(owner, Roles.ADMIN_ROLE);
    }

    /**
     * @dev Does nothing.  The bubble SDAC must be terminated separately.
     */
    function terminate() public override {}

    /**
     * @dev Locks or unlocks the given ID.  If locked, no registered accounts or proxies will have
     * permission to act on its behalf.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function lock(bool enabled) public onlyAdmin {
        locked = enabled;
    }

    /**
     * @dev Sets the SDAC contract that controls the access permissions for this ID's bubble.
     * An ID does not need to control a bubble.  Also allows the SDAC to be upgraded.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function setBubble(PersonaSDAC bubbleSdac) public onlyAdmin {
        bubble = bubbleSdac;
    }

    /**
     * @dev Returns true if the given account or ProxyId has authorisation to act on behalf of
     * this ID in any role.
     */
    function isRegistered(address proxy) public view returns (bool) {
        for (uint i=0; i<proxies.length; i++) {
            if (proxy == proxies[i].id) return true;
        }
        return false;
    }

    /**
     * @dev Returns true if the given account or proxyID is authorised to act as the given role
     * and the ID is not locked.
     */
    function isAuthorized( address requester, uint role ) public view override returns (bool) {
        if (locked) return false;
        for (uint i=0; i<proxies.length; i++) {
            if (ProxyIdUtils.isAuthorizedFor(requester, role, proxies[i].id, proxies[i].role)) return true;
        }
        return false;
    }
    
    /**
     * @dev Returns true if the given account or ProxyId has admin rights over this ID.
     */
    function _isAdmin(address addressOrProxy) internal view override returns (bool) {
        for (uint i=0; i<proxies.length; i++) {
            if (ProxyIdUtils.isAuthorizedFor(addressOrProxy, Roles.ADMIN_ROLE, proxies[i].id, proxies[i].role)) return true;
        }
        return false; 
    }

    /**
     * @dev SDAC function to return the drwa permissions for the given requester and file.
     * 
     * Reverts if no SDAC has been set via the setBubble function.
     */
    function getPermissions(address requester, address file) public view override returns (bytes1) {
        return bubble.getPermissions(requester, file);
    }

    /**
     * @dev Returns true if this ID has been locked and it's bubble has expired.  If this ID does
     * have a bubble then returns true if the ID has been locked.
     */
    function hasExpired() public view override returns (bool) {
        return address(bubble) == address(0) ? locked : locked && bubble.hasExpired();
    }

    /**
     * @dev Returns the hash (id) of the bubble server that is storing the bubble controlled by
     * this id.  Allows the caller to identify which bubble server is used.
     */
    function getVaultHash() public returns (bytes32) {
        return bubble.getVaultHash();
    }

    function _msgSender() internal view virtual override(Context, BubbleRelayRecipient) returns (address ret) {
        return BubbleRelayRecipient._msgSender();
    }

    function _msgData() internal view virtual override(Context, BubbleRelayRecipient) returns (bytes calldata ret) {
        return BubbleRelayRecipient._msgData();
    }

}
