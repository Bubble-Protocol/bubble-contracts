// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PersonaSDAC.sol";
import "../proxyid/ProxyId.sol";
import "../proxyid/Proxyable.sol";
import "../../bubble-fs/sdacs/SDAC.sol";
import "../../bubble-fs/sdacs/TransactionFunded.sol";

/**
 * BubblePersona v0.0.3
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

contract BubblePersona is ProxyId, Proxyable, SDAC, TransactionFunded {
    
    PersonaSDAC public bubble;
    Proxy[] public proxies;
    bool public locked = false;

    /**
     * Can be constructed by a transaction proxy server.  Owner is set to the account that produced
     * the ownerSignature.  Both the owner key and the given proxyOwner are awarded admin rights over
     * this persona, as are any additional accounts or ProxyIds given in the adminProxies parameter.
     *
     * Reverts if the ownerSignature has been used before.
     */
    constructor(address proxyOwner, address[] memory adminProxies, uint nonce, bytes memory ownerSignature) {
        bytes32 hash = keccak256(abi.encodePacked("BubblePersona", nonce, proxyOwner, adminProxies));
        address signer = _recoverSigner(hash, ownerSignature);
        require(_isAuthorizedFor(signer, ADMIN_ROLE, proxyOwner), "permission denied");
        owner = signer;
        nonceRegistry.registerNonce(hash);
        proxies.push(Proxy(owner, ADMIN_ROLE));
        proxies.push(Proxy(proxyOwner, ADMIN_ROLE));
        for (uint i=0; i<adminProxies.length; i++) {
            proxies.push(Proxy(adminProxies[i], ADMIN_ROLE));
        }
    }

    /**
     * @dev Returns true if the given account or proxyID is authorised to act as the given role
     * and the ID is not locked.
     */
    function isAuthorized( address requester, uint role ) public view override returns (bool) {
        if (locked) return false;
        for (uint i=0; i<proxies.length; i++) {
            if (_isAuthorizedFor(requester, role, proxies[i].id, proxies[i].role)) return true;
        }
        return false;
    }
    
    /**
     * @dev Authorises the given account or ProxyId to act on behalf of this ID under the given
     * role.  If role is 0 then this account or ProxyId is deregistered.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function registerProxy(address proxy, uint role) public {
        _registerProxy(msg.sender, proxy, role); 
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
     * @dev Returns true if the given account or ProxyId has admin rights over this ID.
     */
    function isAdmin(address addressOrProxy) public view returns (bool) {
        for (uint i=0; i<proxies.length; i++) {
            if (_isAuthorizedFor(addressOrProxy, ADMIN_ROLE, proxies[i].id, proxies[i].role)) return true;
        }
        return false;
    }

    /**
     * @dev Allows a pre-signed packet to replace the persona owner if the genesis key is lost.
     * This function is available for future backup options.
     */
    function resetOwner(address newOwner, bytes memory signature) public {
        bytes32 message = keccak256(abi.encodePacked("resetOwner", address(this)));
        address signer = _recoverSigner(message, signature);
        require(signer == owner, "permission denied");
        owner = newOwner;
        proxies[0] = Proxy(owner, ADMIN_ROLE);
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
    function lock(bool enabled) public {
        _lock(msg.sender, enabled);
    }

    /**
     * @dev Sets the SDAC contract that controls the access permissions for this ID's bubble.
     * An ID does not need to control a bubble.  Also allows the SDAC to be upgraded.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function setBubble(PersonaSDAC bubbleSdac) public {
        _setBubble(msg.sender, bubbleSdac);
    }

    /**
     * @dev Returns the hash (id) of the bubble server that is storing the bubble controlled by
     * this id.  Allows the caller to identify which bubble server is used.
     */
    function getVaultHash() public returns (bytes32) {
        return bubble.getVaultHash();
    }


    // Proxy methods

    function proxyRegisterProxy(address proxy, uint role, uint nonce, bytes memory signature) public {
        _assertTxIsOriginal(bytes32(nonce));
        bytes32 message = keccak256(abi.encodePacked("registerProxy", address(this), proxy, role, nonce));
        address signer = _recoverSigner(message, signature);
        _registerProxy(signer, proxy, role);
    }

    function proxySetBubble(PersonaSDAC bubbleSdac, uint nonce, bytes memory signature) public {
        _assertTxIsOriginal(bytes32(nonce));
        bytes32 message = keccak256(abi.encodePacked("setBubble", address(this), bubbleSdac, nonce));
        address signer = _recoverSigner(message, signature);
        _setBubble(signer, bubbleSdac);
    }

    function proxyLock(bool enabled, uint nonce, bytes memory signature) public {
        _assertTxIsOriginal(bytes32(nonce));
        bytes32 message = keccak256(abi.encodePacked("lock", address(this), enabled, nonce));
        address signer = _recoverSigner(message, signature);
        _lock(signer, enabled);
    }

    // Private methods
    
    function _registerProxy(address sender, address proxy, uint role) private {
        require(isAdmin(sender), "permission denied");
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

    function _setBubble(address sender, PersonaSDAC bubbleSdac) private {
        require(isAdmin(sender), "permission denied");
        bubble = bubbleSdac;
    }

    function _lock(address sender, bool enabled) private {
        require(isAdmin(sender), "permission denied");
        locked = enabled;
    }

}
