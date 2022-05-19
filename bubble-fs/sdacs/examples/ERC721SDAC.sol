// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Bubble controlled by ERC721 contract.  Owners of tokens are permitted read access to
 * files named after the token id.
 */

import "../SDAC.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";

contract ERC721ControlledBubble is SDAC {

    IERC721 nftContract;
    bool terminated = false;

    constructor(IERC721 nft) {
        nftContract = nft;
    }

    /**
     * @dev Each token has a corresponding file within the bubble named after the token id.
     * Requires token IDs to be restricted to 160 bits.
     *
     *   - Owner has rw access to all token files
     *   - Token holders have read access to a token file if they own the token
     */
    function getPermissions( address requester, address file ) public override view returns (bytes1) {
      if (requester == owner) return READ_BIT | WRITE_BIT | APPEND_BIT;
      if (nftContract.ownerOf(uint256(uint160(file))) == requester) return READ_BIT;
      else return NO_PERMISSIONS;
    }

    /**
     * @dev Returns true if the contract has been manually terminated
     */
    function hasExpired() public override view returns (bool) {
      return terminated;
    }

    /**
     * @dev Terminates the contract if the sender is the owner
     */
    function terminate() public override {
      require(msg.sender == owner, "permission denied");
      terminated = true;
    }
    
}