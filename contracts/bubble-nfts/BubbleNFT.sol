pragma solidity ^0.8.0;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

// Bubble NFT: 0x81e1f2A88B006C5669cb5b32397B2C586F82f59d
// Bubble NFT SDAC: 0xE06777947E6b415555B3fe0332DF28F5502E2798
// Bubble Test NFT: 0x43307E0f79AbfcAeE2d1D1798637a17829dF9eCF
// Bubble Test NFT SDAC: 0xbF3F0f76d07A104a2A709f88E4fb8C0B20c4338b

import "./Roles.sol";
import "../bubble-id/proxyid/ProxyIdUtils.sol";
import "../bubble-id/metatx/ERC2771Recipients/BubbleSingleRelayRecipient.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../utils/registries/NonceRegistry.sol";


/**
 * @title BubbleNFT
 * @author Bubble Protocol
 *
 * This ERC721 contract supports Bubble's Proxy ID smart contracts.  This allows a token to be owned by
 * a Proxy ID and operations on the token to be performed by keys authorised by the Proxy ID smart contract.
 * Tokens can also be owned by standard accounts.  The owner of the contract can also be a Proxy ID.  The use
 * of Proxy IDs prevents the use of IERC721 safeTransferFrom and approval related functions.
 *
 * The following Proxy ID role permissions are required:
 *
 *   Token Owner
 *     - PUBLISH_ROLE: to transfer a token
 *
 *   Contract Owner
 *     - ADMIN_ROLE: to change the contract owner and to set the contract URI
 *     - MINTER_ROLE: to mint tokens (directly or by signing an invite) and to lock a series
 *
 * This ERC721 contract supports multiple NFT 'series' where a series contains a set of minted tokens and can
 * be permanently locked to prevent any more tokens being minted within that series.  The number of tokens within
 * a series and it's locked status can be read with the getSeriesCount and isLocked functions respectively.
 *
 * Tokens can be minted directly by the contract owner or with an 'invite' - a signature from the owner that
 * allows the sender to mint their own token for their own public key.  Invites are single use and have an
 * expiry date set by the owner.  There are two types of invite supported: one that mints a specific token ID 
 * and one that mints the next free token ID (starting at 0 and incrementing).
 *
 * Token IDs are limited by the minting operations to 160-bits in length.  This is to accommodate being
 * mapped to bubble files or directories.  Token Ids are constructed from a 32-bit series id and a 128-bit
 * token id.  Token ID = series<<128 + tokenId
 */

contract BubbleNFT is IERC721, IERC721Metadata, BubbleSingleRelayRecipient {

    using ECDSA for bytes32;

    // ProxyID contract or account that owns this contract
    address _proxyOwner;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token balance
    mapping(address => uint256) private _balances;

    // Mapping series to number of tokens minted in that series
    mapping(uint32 => uint128) private _seriesCounts;

    // Mapping series to lock status
    mapping(uint32 => bool) private _seriesLocks;

    // Name, symbol and URI of this contract
    string public override name;
    string public override symbol;
    string public bubbleURI = "";

    // Registry for recording request nonces to prevent replay attacks.
    NonceRegistry public nonceRegistry;

    /**
     * @dev Constructs a new contract, setting the owner to the given ProxyID or account
     */
    constructor(address trustedForwarder, NonceRegistry registry, address accountOrProxy, string memory contractName, string memory contractSymbol)
    BubbleSingleRelayRecipient(trustedForwarder)
    {
        nonceRegistry = registry;
        _proxyOwner = accountOrProxy;
        name = contractName;
        symbol = contractSymbol;
    }

    /**
     * @dev Mints a new token and assigns its owner.
     *
     * Requirements:
     *
     * - owner cannot be zero
     * - token must not have been minted before
     * - series must not be locked
     * - sender must have MINTER_ROLE rights over the current proxy owner of the contract (or be the owner)
     */
    function mint(uint32 series, uint128 tokenId, address owner) public {
        _mint(_msgSender(), series, tokenId, owner);
    }

    /**
     * @dev Mints a specific token using an invitation signed by the contract owner
     *
     * Requirements:
     *
     * - the owner is responsible for ensuring mintWithInvite is not used in conjunction with mintNextWithInvite
     * - accountOrProxy cannot be zero
     * - expiryTime must be > current block time
     * - token must not have been minted before
     * - series must not be locked
     * - ownerSignature must be generated by a key with MINTER_ROLE rights over the current proxy owner of this contract (or be the owner)
     * - ownerSignature must be for an invitation of this type, not a mintNextWithInvite type (i.e. signed message must include the token id)
     */
    function mintWithInvite(address accountOrProxy, uint32 series, uint128 tokenId, uint expiryTime, bytes memory ownerSignature) public {
        require(block.timestamp < expiryTime, "invite has expired");
        bytes memory packet = abi.encodePacked("mintWithInvite", address(this), series, tokenId, expiryTime);
        address signer = keccak256(packet).toEthSignedMessageHash().recover(ownerSignature);
        _mint(signer, series, tokenId, accountOrProxy);
    }

    /**
     * @dev Mints the next token using an invite signed by the contract owner.
     *
     * Requirements:
     *
     * - the owner is responsible for ensuring mintNextWithInvite is not used in conjunction with mintWithInvite
     * - accountOrProxy cannot be zero
     * - expiryTime must be > current block time
     * - series must not be locked
     * - ownerSignature must be generated by a key with MINTER_ROLE rights over the current proxy owner of this contract (or be the owner)
     * - ownerSignature must be for an invitation of this type, not a mintWithInvite type (i.e. signed message must not include the token id)
     */
    function mintNextWithInvite(address accountOrProxy, uint32 series, uint nonce, uint expiryTime, bytes memory ownerSignature) public {
        require(block.timestamp < expiryTime, "invite has expired");
        nonceRegistry.registerNonce(bytes32(nonce));
        bytes memory packet = abi.encodePacked("mintNextWithInvite", address(this), series, nonce, expiryTime);
        address signer = keccak256(packet).toEthSignedMessageHash().recover(ownerSignature);
        uint128 tokenId = _seriesCounts[series];
        _mint(signer, series, tokenId, accountOrProxy);
    }

    /**
     * @dev Locks the given series permanently so that no more tokens in that series can be minted
     *
     * Requirements:
     *
     * - sender must have MINTER_ROLE rights over the current proxy owner of the contract (or be the owner)
     * - series must not be locked
     * - once locked a series cannot be unlocked
     */
    function lock(uint32 series) external {
        require(ProxyIdUtils.isAuthorizedFor(msg.sender, MINTER_ROLE, _proxyOwner), "permission denied");
        require(_seriesLocks[series] == false, "already locked");
        _seriesLocks[series] = true;
    }

    /**
     * @dev Returns whether or not the series is locked (whether any more tokens in that series can be minted)
     */
    function isLocked(uint32 series) external view returns (bool) {
        return _seriesLocks[series];
    }

    /**
     * @dev Returns the number of tokens minted in the given series.
     */
    function getSeriesCount(uint32 series) external view returns (uint128) {
        return _seriesCounts[series];
    }

    /**
     * @dev Sets the URI string of the bubble controlled by this contract
     *
     * Requirements:
     *
     * - sender must have admin rights over the current proxy owner of the contract (or be the owner)
     */
    function setBubbleURI(string memory URI) public {
        require(ProxyIdUtils.isAuthorizedFor(msg.sender, Roles.ADMIN_ROLE, _proxyOwner), "permission denied");
        bubbleURI = URI;
    }
    
    /**
     * @dev Sets the owner of this contract
     *
     * Requirements:
     *
     * - accountOrProxy cannot be zero
     * - sender must have admin rights over the current proxy owner of the contract (or be the owner)
     */
    function changeContractOwner(address accountOrProxy) public {
        require(ProxyIdUtils.isAuthorizedFor(msg.sender, Roles.ADMIN_ROLE, _proxyOwner), "permission denied");
        require(accountOrProxy != address(0), "invalid address");
        _proxyOwner = accountOrProxy;
    }
    
    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external override view returns (string memory) {
        return string(abi.encodePacked(bubbleURI, _toHexString(uint160(tokenId))));
    }

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external override view returns (uint256 balance) {
        return _balances[owner];
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external override view returns (address owner) {
        return _owners[tokenId];
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external override pure {
        revert("not supported");
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override pure {
        revert("not supported");
    }

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external override {
        require(ProxyIdUtils.isAuthorizedFor(_msgSender(), PUBLISH_ROLE, _owners[tokenId]), "ERC721: transfer from incorrect owner");
        require(_owners[tokenId] == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        _owners[tokenId] = to;
        _balances[from] -= 1;
        _balances[to] += 1;
        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external override pure {
        revert("not supported");
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external override pure {
        revert("not supported");
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external override pure returns (address operator) {
        revert("not supported");
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external override pure returns (bool) {
        revert("not supported");
    }

    function supportsInterface(bytes4 interfaceId) external override pure returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }


    //
    // Private/Internal Functions
    //

    /**
     * @dev Mints a new token and assigns its owner. Token ID = series<<128 + tokenId.  Max 160 bits.
     *
     * Requirements:
     *
     * - owner cannot be zero
     * - token must not have been minted before
     * - series must not be locked
     * - sender must have MINTER_ROLE rights over the current proxy owner of the contract (or be the owner)
     */
    function _mint(address sender, uint32 series, uint128 tokenId, address owner) private {
        require(ProxyIdUtils.isAuthorizedFor(sender, MINTER_ROLE, _proxyOwner), "permission denied");
        require(owner != address(0), "invalid recipient address");
        require(_seriesLocks[series] == false, "series is locked");
        uint160 uSeries = uint160(series) << 128;
        uint160 uTokenId = uint160(tokenId);
        uint160 token = uSeries + uTokenId;
        require(_owners[token] == address(0), "already minted");
        _owners[token] = owner;
        _balances[owner]++;
        _seriesCounts[series]++;
        emit Transfer(address(this), owner, token);
    }
    
    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */

    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    
    function _toHexString(uint160 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(42);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 41; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        return string(buffer);
    }

}
