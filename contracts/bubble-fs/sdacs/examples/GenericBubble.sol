// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../../bubble-id/metatx/ERC2771Recipients/BubbleSingleRelayRecipient.sol";
import "../../../bubble-id/proxyid/ProxyIdUtils.sol";
import "../SDAC.sol";

/**
 * @dev A general purpose bubble designed for use with Bubble ID.
 */
contract GenericBubble is SDAC, BubbleSingleRelayRecipient {

    // @dev Public file bit mask.  See setPermissions
    bytes1 private constant PUBLIC_BIT = 0x08;

    bool terminated = false;
    address ownerId;
    mapping(bytes32=>bytes1) permissions;

    /**
     * @dev Sender must have admin rights over the given proxyOwner (or be the proxyOwner).
     *
     * Note, At this time, a bubble server will only allow the sender account to construct the 
     * off-chain bubble.  Even an account with admin rights over the proxyOwner will be refused.
     * This will be changed in a future version of the protocol.
     */
    constructor(address trustedForwarder, address proxyOwner) 
    BubbleSingleRelayRecipient(trustedForwarder)
    {
        require(ProxyIdUtils.isAuthorizedFor(owner, Roles.ADMIN_ROLE, proxyOwner), "permission denied");
        ownerId = proxyOwner;  // leave owner as signer so that they can create the vault
    }

    /**
     * @dev see _isAdmin()
     */
    function isAdmin(address addressOrProxy) public view returns (bool) {
        return _isAdmin(addressOrProxy);
    }

    /**
     * @dev Returns true if the given account or ProxyId has admin rights over this bubble, which
     * will be true if it has admin rights over the proxyOwner of this contract.
     */
    function _isAdmin(address addressOrProxy) internal view override returns (bool) {
        return ProxyIdUtils.isAuthorizedFor(addressOrProxy, Roles.ADMIN_ROLE, ownerId);
    }

    /**
     * @dev Changes the proxy owner
     *
     * Requirements:
     *   - sender must have admin rights over this bubble.
     */
    function setProxyOwner(address proxyOwner) public {
        require(isAdmin(msg.sender), "permission denied");
        ownerId = proxyOwner;
    }

    /**
     * @dev Sets the drwa permissions of the given userFile hashes.  A userFile hash is either
     * keccak256(this, user, file) or keccak256(this, file).  It allows permissions to be set for
     * a specific user and file, or global permissions to be set for a file.  The PUBLIC_BIT
     * defined above can be set to indicate that the file or directory can be read publicly.
     *
     * Call this function with keccak256(this.address, file) to mark a file as public or as a 
     * directory.  If setting as public, you must also set rwa bits if you want it publicly 
     * readable, writable and/or appendable.
     *
     * i.e. 0x0C = public read-only
     *      0x0D = public read-append
     *      0x0F = public read-write-append
     *
     * Requirements:
     *   - sender must have admin rights over this bubble.
     */
    function setPermissions(bytes32[] memory userFileHashes, bytes1 filePermissions) public {
        require(isAdmin(msg.sender), "permission denied");
        for (uint i=0; i<userFileHashes.length; i++) {
            permissions[userFileHashes[i]] = filePermissions;
        }
    }

    /**
     * @dev SDAC function to return the drwa permissions for the given requester and file.  See
     * setPermissions for more details.  Administrators of this bubble have rwa rights over all files 
     * and directories. 
     *
     * - if requester has admin rights, returns rwa
     * - if file has public bit set, returns file permissions OR'd with any user-specific permissions for that file
     * - if not public, returns any user-specific permissions for that file.
     */
    function getPermissions(address requester, address file) public view override returns (bytes1) {
        // determine if this is a directory
        bytes32 fileHash = keccak256(abi.encodePacked(address(this), file));
        bytes1 filePermissions = permissions[fileHash];
        bytes1 directoryBit = filePermissions & DIRECTORY_BIT > 0 ? DIRECTORY_BIT : bytes1(0);
        // check if the requester has admin rights
        if (isAdmin(requester)) return directoryBit | READ_BIT | WRITE_BIT | APPEND_BIT;
        // check for specific requester/file permissions or for public permissions.  
        // if public, return OR of user-specific permissions and general file permissions
        bytes32 userFileHash = keccak256(abi.encodePacked(address(this), requester, file));
        bytes1 specificPermissions = permissions[userFileHash];
        if (filePermissions & PUBLIC_BIT > 0) return filePermissions | specificPermissions;
        else if (specificPermissions > 0) return directoryBit | specificPermissions;
        else return NO_PERMISSIONS;
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
    function terminate() public override {
        require(!terminated, "already terminated");
        require(isAdmin(msg.sender), "permission denied");
        terminated = true;
    }

    function _msgSender() internal view virtual override(Context, BubbleRelayRecipient) returns (address ret) {
        return BubbleRelayRecipient._msgSender();
    }

    function _msgData() internal view virtual override(Context, BubbleRelayRecipient) returns (bytes calldata ret) {
        return BubbleRelayRecipient._msgData();
    }

}