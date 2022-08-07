// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";

/**
 * Smart Data Access Contract
 *
 * @dev All S-DACs must implement this interface.  Any contract that implements this interface can be 
 * used to construct and manage a bubble on any compatible Bubble server.
 */
abstract contract SDAC is Context {

    string public constant DatonaProtocolVersion = "0.0.2";

    // constants describing the permissions-byte structure of the form d----rwa.
    bytes1 public constant NO_PERMISSIONS = 0x00;
    bytes1 public constant ALL_PERMISSIONS = 0x07;
    bytes1 public constant READ_BIT = 0x04;
    bytes1 public constant WRITE_BIT = 0x02;
    bytes1 public constant APPEND_BIT = 0x01;
    bytes1 public constant DIRECTORY_BIT = 0x80;
    
    address public owner = _msgSender();

    // File based d----rwa permissions.  Assumes the data vault has validated the requester's ID. 
    // Address(0) is a special file representing the vault's root
    function getPermissions( address requester, address file ) public virtual view returns (bytes1);

    // returns true if the contract has expired either automatically or has been manually terminated
    function hasExpired() public virtual view returns (bool);
    
    // terminates the contract if the sender is permitted and any termination conditions are met
    function terminate() public virtual;
    
}

