// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./Roles.sol";
import "../bubble-id/proxyid/Proxyable.sol";
import "../bubble-fs/sdacs/SDAC.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";


// Default files
address constant PUBLIC_METADATA_FILE = 0xe0047D23eBC7c602468D22bEf8D6bFf7a6842E55;  // uint160(keccak256("ERC721ControlledBubble public metadata file"))
address constant PUBLIC_DIRECTORY = 0xAeEB01bd62dfd37A2d1C62162253b8BE68a5aE1B;  // uint160(keccak256("ERC721ControlledBubble public directory"))
address constant NFT_OWNERS_ONLY_DIRECTORY = 0xBF4F4053E48543ABeb77Cac2580d523E9Bf01f78;  // uint160(keccak256("ERC721ControlledBubble nft owners only directory"))


/**
 * @title Bubble NFT-controlled SDAC
 * @author Bubble Protocol
 *
 * Provides read access for owners of an NFT.  Each owner has read access to a file named after their token ID.
 * Each owner also has access to a global 
 */
contract ERC721ControlledBubble is SDAC, Proxyable {

    address private _proxyOwner;
    bool private terminated = false;
    IERC721 public nftContract;

    /**
     * @dev Constructs the SDAC controlled by the given NFT contract.  Sets the owner to proxyOwner
     */
    constructor(address proxyOwner, IERC721 nft) {
        _proxyOwner = proxyOwner;
        nftContract = nft;
    }

    /**
     * @dev Changes the owner of this contract
     *
     * Requirements:
     *
     * - accountOrProxy cannot be zero
     * - sender must have admin rights over the current proxy owner of the contract (or be the owner)
     */
    function changeContractOwner(address accountOrProxy) public {
        require(_isAuthorizedFor(msg.sender, ADMIN_ROLE, _proxyOwner), "permission denied");
        require(accountOrProxy != address(0), "invalid address");
        _proxyOwner = accountOrProxy;
    }
    
    /**
     * @dev Used by a vault server to get the drwa permissions for the given file and requester
     *
     * - Each token has a corresponding directory within the bubble named after the token id
     * - There is a single public metadata file and public directory at the addresses defined above
     * - Owner has rwa access to all files/directories
     * - Token holders have read access to a token directory if they own the token
     * - Token holders (of any series) have access to the single "owner's" directory defined above
     */
    function getPermissions( address requester, address file ) public override view returns (bytes1) {
        bytes1 directoryBit = (file == PUBLIC_METADATA_FILE) ? bytes1(0) : DIRECTORY_BIT;
        if (_isAuthorizedFor(requester, READ_WRITE_ROLE, _proxyOwner)) return directoryBit | READ_BIT | WRITE_BIT | APPEND_BIT;
        if (file == PUBLIC_METADATA_FILE) return READ_BIT;
        if (file == PUBLIC_DIRECTORY) return DIRECTORY_BIT | READ_BIT;
        if (file == NFT_OWNERS_ONLY_DIRECTORY && nftContract.balanceOf(requester) > 0) return DIRECTORY_BIT | READ_BIT;
        if (_isAuthorizedFor(requester, IDENTIFY_AS_ROLE, nftContract.ownerOf(uint160(file)))) return DIRECTORY_BIT | READ_BIT;
        return NO_PERMISSIONS;
    }

    /**
     * @dev returns true if the contract has expired either automatically or has been manually terminated
     * @custom:depreciated future versions of datona-lib will use getState() === 0
     */
    function hasExpired() public override view returns (bool) {
        return terminated;
    }

    /**
     * @dev terminates the contract if the sender is permitted and any termination conditions are met
     */
    function terminate() public override {
        require(_isAuthorizedFor(msg.sender, ADMIN_ROLE, _proxyOwner), "permission denied");
        terminated = true;
    }
    
}
