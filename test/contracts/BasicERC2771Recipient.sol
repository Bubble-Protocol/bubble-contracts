// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../contracts/utils/metatx/ERC2771Recipients/BubbleSingleRelayRecipient.sol";


contract BasicERC2771Recipient is BubbleSingleRelayRecipient {

    constructor(address forwarder) BubbleSingleRelayRecipient(forwarder) {}

    string public lastFunc;
    address public lastSender;
    uint256 public lastRoles;
    bytes public lastData;
    uint256 public lastValue;
    address public p1;
    bytes32 public p2;
    bytes public p3;

    fallback() external payable {
      _setCaller("fallback");
    }

    receive() external payable { 
      _setCaller("receive");
    }

    function externalFunc() external {
      _setCaller("externalFunc");
    }

    function publicFunc() public {
      _setCaller("publicFunc");
    }

    function internalFunc() internal {
      _setCaller("internalFunc");
    }

    function privateFunc() private {
      _setCaller("privateFunc");
    }

    function funcWithOneParam(address param1) external {
      _setCaller("funcWithOneParam");
      p1 = param1;
    }

    function funcWithTwoParams(address param1, bytes32 param2) external {
      _setCaller("funcWithTwoParams");
      p1 = param1;
      p2 = param2;
    }

    function funcWithManyParams(address param1, bytes32 param2, bytes memory param3) external {
      _setCaller("funcWithManyParams");
      p1 = param1;
      p2 = param2;
      p3 = param3;
    }

    function funcThatReverts() external {
      _setCaller("funcThatReverts");
      revert("funcThatReverts is reverting");
    }

    function _setCaller(string memory func) private {
      lastFunc = func;
      lastSender = _msgSender();
      lastRoles = _msgRoles();
      lastData = _msgData();
      lastValue = msg.value;
    }

}