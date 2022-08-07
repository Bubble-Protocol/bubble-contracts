// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../proxyid/ProxyIdUtils.sol";
import "../../bubble-fs/sdacs/SDAC.sol";
import "../metatx/ERC2771Recipients/BubbleSingleRelayRecipient.sol";

/**
 * @dev General purpose SDAC for DApps.  It uses a general purpose permissions scheme that
 * allows the owner to set specific permissions for specific files and requesters or general
 * permissions for files.  See setPermissions for more details.
 *
 * Default permissions:
 *   - Administrators have full rwa access over all files and directories
 *   - Files 0..255 are directories.
 */

contract GenericApplicationBubble is SDAC, BubbleSingleRelayRecipient {

    bool terminated = false;
    address ownerId;
    address applicationId;
    mapping(bytes32=>bytes1) permissions;

    /**
     * Sender must have admin rights over the given proxyOwner.  The proxyOwner is designed to be 
     * a Persona ID so that the application bubble can be recovered from the genesis key.  The 
     * proxyApplication is the ProxyID contract address of the application.
     *
     * Reverts if the ownerSignature has been used before.
     */
    constructor(address trustedForwarder, address proxyOwner, address proxyApplication) 
        BubbleSingleRelayRecipient(trustedForwarder) 
    {
        require(ProxyIdUtils.isAuthorizedFor(_msgSender(), Roles.ADMIN_ROLE, proxyOwner), "permission denied");
        ownerId = proxyOwner;  // leave owner as signer so that they can create the vault
        applicationId = proxyApplication;
    }

    /**
     * @dev see _isAdmin
     */
    function isAdmin(address addressOrProxy) public view returns (bool) {
        return _isAdmin(addressOrProxy);
    }

    /**
     * @dev Returns true if the given account or ProxyId has admin rights over this bubble, which
     * will be true if it has admin rights over the proxyOwner of this contract or over the
     * application ID.
     */
    function _isAdmin(address addressOrProxy) internal view override returns (bool) {
        return 
            ProxyIdUtils.isAuthorizedFor(addressOrProxy, Roles.ADMIN_ROLE, ownerId) || 
            ProxyIdUtils.isAuthorizedFor(addressOrProxy, Roles.ADMIN_ROLE, applicationId);
    }

    /**
     * @dev Sets the drwa permissions of the given userFile hashes.  A userFile hash is either
     * keccak256(this, user, file) or keccak256(file).  It allows permissions to be set for a
     * specific user and file, or global permissions to be set for a file.  
     *
     * Requirements:
     *   - sender must have admin rights over this bubble.
     */
    function setPermissions(bytes32[] memory userFileHashes, bytes1 filePermissions) public onlyAdmin {
        for (uint i=0; i<userFileHashes.length; i++) {
            permissions[userFileHashes[i]] = filePermissions;
        }
    }

    /**
     * @dev SDAC function to return the drwa permissions for the given requester and file.  See
     * setPermissions for more details.  Administrators of this bubble have rwa rights over all files 
     * and directories. 
     */
    function getPermissions(address requester, address file) public view override returns (bytes1) {
        bytes32 fileHash = keccak256(abi.encodePacked(address(this), file));
        bytes1 directoryBit = file < address(256) || permissions[fileHash] & DIRECTORY_BIT > 0 ? DIRECTORY_BIT : bytes1(0);
        if (_isAdmin(requester)) return directoryBit | READ_BIT | WRITE_BIT | APPEND_BIT;
        bytes32 userFileHash = keccak256(abi.encodePacked(address(this), requester, file));
        return permissions[userFileHash];
    }

    /**
     * @dev Returns true if this SDAC has been terminated.
     */
    function hasExpired() public view override returns (bool) {
        return terminated;
    }

    /**
     * @dev Terminates this SDAC preventing all access to the bubble.  The bubble server is
     * obliged to delete the bubble and its data when it's SDAC is terminated.
     *
     * Requirements:
     *   - sender must have admin rights over this bubble.
     */
    function terminate() public override onlyAdmin {
        require(!terminated, "already terminated");
        terminated = true;
    }

    function _msgSender() internal view virtual override(Context, BubbleRelayRecipient) returns (address ret) {
        return BubbleRelayRecipient._msgSender();
    }

    function _msgData() internal view virtual override(Context, BubbleRelayRecipient) returns (bytes calldata ret) {
        return BubbleRelayRecipient._msgData();
    }

}