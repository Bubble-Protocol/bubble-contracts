// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../proxyid/ProxyIdUtils.sol";
import "../../utils/registries/NonceRegistry.sol";
import "hardhat/console.sol";

/**
 * @title ERC2771 Trusted Forwarder implementation for Bubble ID.
 *
 * Can be used to send pre-paid meta transactions to a contract inheriting from BubbleRelayRecipient.  Bubble ID meta
 * transactions allow a DApp to use it's own private key to act on behalf of a user's Bubble ID Persona, where the Dapp
 * is limited to specific 'roles' authorised by the Persona smart contract.  This forwarder passes both the sender of 
 * the meta transaction (Persona ID or request signatory) and the authorised roles to the recipient contract.
 *
 * This forwarder supports Bubble ID meta transactions and meta transactions from ordinary accounts.  To transact on 
 * behalf of a Persona the client must include the Persona smart contract address in req.onBehalfOf and must include
 * the roles it wishes to act under in req.roles.  To transact as an ordinary account set req.onBehalfOf to zero.  
 *
 * This forwarder can optionally restrict meta transactions to those whose signatory has at least one of a set of 
 * permitted roles.  This allows the recipient contract to trust that the sender at least meets one of the roles in
 * the permitted set.  Set the permittedRolesMask bitmask on construction.
 *
 * The pseudocode for the public execute function is as follows:
 *
 *   1) Revert if: 
 *       - signatory != req.from
 *       - req.nonce has been used before
 *       - req.validUntilTime < block.timestamp  (if req.validUntilTime is not zero)
 *   2) If (req.onBehalfOf == 0) then 
 *       - sender = req.from
 *       - roles = permittedRoles
 *      If (req.onBehalfOf != 0) then 
 *       - Revert if req.from is not authrosied for req.onBehalfOf under req.roles
 *       - sender = req.onBehalfOf
 *       - roles = req.roles & permittedRoles
 *   3) Call target contract at req.to with req.data::sender::roles passing limiting it to req.gas and req.value
 *   4) Refund any remaining transaction value to the sender
 *
 *   Note, the sender in step (3) is 20-bytes and roles is 32-bytes, appended in that order to req.data and packed.
 */
contract BubbleForwarder {

    using ECDSA for bytes32;

    struct ForwardRequest {
        address from;
        address onBehalfOf;
        uint256 roles;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
        uint256 validUntilTime;
    }

    /**
     * The id of the blockchain network.  Used in the signed request packet with block.chainid to prevent cross-chain 
     * replay attacks.
     */
    uint public networkId;

    /**
     * Registry for recording request nonces to prevent replay attacks.
     */
    NonceRegistry public nonceRegistry;

    /**
     * @dev Bitmask holding the maximum permissions allowed by this forwarder.  The roles passed to the target contract
     * will be filtered (bitwise AND) by this mask.
     */
    uint public permittedRoles;


    constructor(uint network, NonceRegistry nonceReg, uint permittedRoleMask) {
        networkId = network;
        nonceRegistry = nonceReg;
        permittedRoles = permittedRoleMask;
    }

    /**
     * @dev Executes a Bubble ID compatible meta transaction.  If the request is valid and the meta tx signatory is 
     * authorised to act on behalf of any Bubble ID Persona specified in the request then the target contract method 
     * is called with the gas, value and call data given in the request.  The call data is appended with a 52-byte
     * packet containing the sender (20-byte Persona ID or meta tx signatory) and the authorised roles 
     * (32-byte bitmask).
     */
    function execute(ForwardRequest calldata req, bytes calldata sig) external payable 
    returns (bool success, bytes memory ret) 
    {
        // Verify the reqest signature matches req.from
        _verifySig(req, sig);

        // Check for replay attacks
        nonceRegistry.registerNonce(bytes32(req.nonce));

        // Check the request has not expired
        require(req.validUntilTime == 0 || req.validUntilTime >= block.timestamp, "FWD: request expired");

        // Verify req.from is authorised to act on behalf of req.onBehalfOf under req.roles.
        (address sender, uint senderRoles) = _verifyBubbleId(req);

        // Check the gas allocated in the request is sufficient.  Reserve a gas buffer if the request has value 
        // in case we need to move eth after the transaction.
        uint256 gasForTransfer = 0;
        if ( req.value != 0 ) {
            gasForTransfer = 40000;
        }
        require(gasleft()*63/64 >= req.gas + gasForTransfer, "FWD: insufficient gas");

        // Check the target contract exists
        require(_isContract(req.to), "FWD: contract does not exist");

        // Append the meta tx sender and authorised roles to the call data in the request and call the target 
        // contract with the gas limit and value specified in the request.
        bytes memory callData = abi.encodePacked(req.data, sender, senderRoles);
        (success,ret) = req.to.call{gas : req.gas, value : req.value}(callData);

        // If unsuccessful then the call must have reverted.  Revert the whole transaction.
        if (!success) revert(_getRevertMessage(ret));

        // Return any remaining value to the meta tx sender (Persona or account).
        if ( req.value != 0 && address(this).balance>0 ) {
            payable(sender).transfer(address(this).balance);
        } 

        return (success,ret);
    }

    /**
     * @dev Verifies the signatory is authorised to act on behalf of the Bubble ID Persona specified in the request. 
     *
     * If the request originates from a standard account then req.onBehalfOf will be zero so it simply accepts
     * that req.from is implicitly authorised to act on behalf of itself.  Otherwise, it verifies req.from is
     * authorised to act as req.onBehalfOf under the roles specified in req.roles.
     *
     * Returns the originator of this meta transaction (Bubble ID Persona or account address) and the authorised
     * roles filtered by the roles permitted by this forwarder.
     *
     * Reverts if req.from is not authorised to act as req.onBehalfOf under req.roles.
     */
    function _verifyBubbleId(ForwardRequest calldata req) internal virtual view 
    returns (address sender, uint senderRoles) 
    {
        if (req.onBehalfOf == address(0)) return (req.from, permittedRoles);
        else {
            require(ProxyIdUtils.isAuthorizedFor(req.from, req.roles, req.onBehalfOf), "FWD: roles denied");
            uint roles = req.roles & permittedRoles;
            require(roles > 0, "FWD: roles denied");
            return (req.onBehalfOf, roles);
        }
    }

    /**
     * @dev Verifies the request signature and reverts if the signatory does not match req.from.  Includes
     * the network id and chain id in the message to prevent cross-chain replay attacks.
     */
    function _verifySig(ForwardRequest calldata req, bytes calldata sig) internal virtual {
        bytes memory message = abi.encodePacked(
            networkId,
            block.chainid,
            req.from,
            req.onBehalfOf,
            req.roles,
            req.to,
            req.value,
            req.gas,
            req.nonce,
            keccak256(req.data),
            req.validUntilTime
        );
        require(keccak256(message).toEthSignedMessageHash().recover(sig) == req.from, "FWD: signature mismatch");
    }

    function _isContract(address addr) private view returns (bool) {
        uint32 size;
        assembly { size := extcodesize(addr) }
        return (size > 0);
    }

    function _getRevertMessage(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return '';

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

}