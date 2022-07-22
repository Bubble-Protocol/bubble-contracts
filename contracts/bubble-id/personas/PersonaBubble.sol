// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PersonaSDAC.sol";
import "../../utils/proxytx/TransactionFunded.sol";
import "../proxyid/Proxyable.sol";


/**
 * @dev SDAC to control a persona's bubble.  It uses a general purpose permissions scheme that
 * allows the owner to set specific permissions for specific files and requesters or general
 * permissions for public files.  See setPermissions for more details.
 *
 * Default permissions:
 *   - Persona administrators have full rwa access to all files and directories
 *   - File 0x100 is public (holds the public persona did)
 *   - There are no directories unless explicitly set
 */

contract PersonaBubble is PersonaSDAC, TransactionFunded, Proxyable {

    bytes1 private constant PUBLIC_BIT = 0x08;

    bool terminated = false;
    address ownerId;
    address applicationId;
    mapping(bytes32=>bytes1) permissions;
    bytes32 vault;

    /**
     * Can be constructed by a transaction proxy server.  Owner is set to the account that produced
     * the ownerSignature and therefore must be key that constructs the vault.  Owner must have
     * admin rights over the given personaId contract.  VaultHash is the id of the vault server
     * that is holding the data (optional).
     *
     * Reverts if the ownerSignature has been used before.
     */
    constructor(address personaId, bytes32 vaultHash, uint nonce, bytes memory ownerSignature) {
        bytes32 hash = keccak256(abi.encodePacked("PersonaBubble", personaId, vaultHash, nonce));
        address signer = _recoverSigner(hash, ownerSignature);
        owner = signer;
        require(_isAuthorizedFor(owner, ADMIN_ROLE, personaId), "permission denied");
        ownerId = personaId;  // leave owner as signer so that they can create the vault
        vault = vaultHash;
        permissions[0x227a737497210f7cc2f464e3bfffadefa9806193ccdf873203cd91c8d3eab518] = PUBLIC_BIT;  // file 0x100
    }

    /**
     * @dev Sets the drwa permissions of the given userFile hashes.  A userFile hash is either
     * keccak256(this, user, file) or keccak256(file).  It allows permissions to be set for a
     * specific user and file, or global permissions to be set for a file.  
     *
     * By default all file addresses are considered files, not directories.  To make a file address
     * a directory, set the directory bit permission for keccak256(file).  To make a file or
     * directory publicly readable, set the PUBLIC_BIT (defined above) for keccak256(file).  For 
     * all other permissions use keccak256(this, user, file), where user is the requester address 
     * passed in getPermissions.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function setPermissions(bytes32[] memory userFileHashes, bytes1 filePermissions) public {
        _setPermissions(msg.sender, userFileHashes, filePermissions);
    }

    /**
     * @dev SDAC function to return the drwa permissions for the given requester and file.  See
     * setPermissions for more details.  Administrators of this ID have rwa rights over all files 
     * and directories. 
     */
    function getPermissions(address requester, address file) public view override returns (bytes1) {
        // determine if this is a directory
        bytes32 fileHash = keccak256(abi.encodePacked(file));
        bytes1 directoryBit = permissions[fileHash] & DIRECTORY_BIT > 0 ? DIRECTORY_BIT : bytes1(0);
        // check if the requester has admin rights
        if (_isAuthorizedFor(requester, ADMIN_ROLE, ownerId)) return directoryBit | READ_BIT | WRITE_BIT | APPEND_BIT;
        // check for specific requester/file permissions or for public read permissions
        bytes32 userFileHash = keccak256(abi.encodePacked(address(this), requester, file));
        bytes1 specificPermissions = permissions[userFileHash];
        if (permissions[fileHash] & PUBLIC_BIT > 0) return specificPermissions | directoryBit | READ_BIT;
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
     *   - sender must have admin rights over this ID.
     */
    function terminate() public override {
        _terminate(msg.sender);
    }

    /**
     * @dev Returns the hash (id) of the bubble server that is storing the bubble controlled by
     * this sdac.  Allows the caller to identify which bubble server is used.
     */
    function getVaultHash() public view override returns (bytes32) {
        return vault;
    }

    /**
     * @dev Sets the hash (id) of the bubble server that is storing the bubble controlled by this
     * sdac.
     *
     * Requirements:
     *   - sender must have admin rights over this ID.
     */
    function setVaultHash(bytes32 vaultHash) public {
        _setVaultHash(msg.sender, vaultHash);
    }

    // Proxy Functions

    function proxySetPermissions(bytes32[] memory userFileHashes, bytes1 filePermissions, uint nonce, bytes memory signature) public {
        bytes32 message = keccak256(abi.encodePacked("setPermissions", address(this), userFileHashes, filePermissions, nonce));
        address signer = _recoverSigner(message, signature);
        _assertTxIsOriginal(message);
        _setPermissions(signer, userFileHashes, filePermissions);
    }

    function proxyTerminate(bytes memory signature) public {
        bytes32 message = keccak256(abi.encodePacked("terminate", address(this)));
        address signer = _recoverSigner(message, signature);
        _terminate(signer);
    }

    function proxySetVaultHash(bytes32 vaultHash, uint nonce, bytes memory signature) public {
        bytes32 message = keccak256(abi.encodePacked("setVaultHash", address(this), vaultHash, nonce));
        address signer = _recoverSigner(message, signature);
        _assertTxIsOriginal(message);
        _setVaultHash(signer, vaultHash);
    }

    // Private Functions

    function _setPermissions(address sender, bytes32[] memory userFileHashes, bytes1 filePermissions) private {
        require(_isAuthorizedFor(sender, ADMIN_ROLE, ownerId), "permission denied");
        for (uint i=0; i<userFileHashes.length; i++) {
            permissions[userFileHashes[i]] = filePermissions;
        }
    }

    function _terminate(address sender) private {
        require(!terminated, "already terminated");
        require(_isAuthorizedFor(sender, ADMIN_ROLE, ownerId), "permission denied");
        terminated = true;
    }

    function _setVaultHash(address sender, bytes32 vaultHash) private {
        require(_isAuthorizedFor(sender, ADMIN_ROLE, ownerId), "permission denied");
        vault = vaultHash;        
    }

}