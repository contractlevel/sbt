// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ERC721Enumerable,
    IERC721Enumerable,
    ERC721
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISoulBoundToken} from "./interfaces/ISoulBoundToken.sol";

/// @title SoulBoundToken
/// @author @contractlevel
/// @notice Non-transferrable ERC721 token with administrative whitelist and blacklist functionality
/// @notice System Actors: Owner, Admins, Whitelisted, Blacklisted
/// @dev Owner - sets admin role and base URI
/// @dev Admins - set whitelisted and blacklisted roles, and enables/disables whitelist
/// @dev Whitelisted - can mint a token if whitelist is enabled
/// @dev Blacklisted - if held token, then burnt, and if whitelisted, then removed, and cant be whitelisted or minted
contract SoulBoundToken is ERC721Enumerable, Ownable, ISoulBoundToken {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SoulBoundToken__NoZeroAddress();
    error SoulBoundToken__Whitelisted(address whitelistedAccount);
    error SoulBoundToken__Blacklisted(address blacklistedAccount);
    error SoulBoundToken__NotWhitelisted(address nonWhitelistedAccount);
    error SoulBoundToken__NotBlacklisted(address nonBlacklistedAccount);
    error SoulBoundToken__WhitelistDisabled();
    error SoulBoundToken__OnlyAdmin(address nonAdmin);
    error SoulBoundToken__WhitelistStatusAlreadySet();
    error SoulBoundToken__TransferNotAllowed();
    error SoulBoundToken__ApprovalNotAllowed();
    error SoulBoundToken__AdminStatusAlreadySet(address account, bool isAdmin);
    error SoulBoundToken__AlreadyMinted(address account);
    error SoulBoundToken__EmptyArray();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Token counter for minting
    uint256 internal s_tokenIdCounter;
    /// @dev Base URI for token metadata
    string internal s_baseURI;
    /// @dev Mapping for whitelist
    mapping(address account => bool isWhitelisted) internal s_whitelist;
    /// @dev Mapping for blacklist
    mapping(address account => bool isBlacklisted) internal s_blacklist;
    /// @dev Mapping for admins
    mapping(address account => bool isAdmin) internal s_admins;
    /// @dev True if whitelist is enabled, false if not
    bool internal s_whitelistEnabled;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AddedToWhitelist(address indexed account);
    event RemovedFromWhitelist(address indexed account);
    event AddedToBlacklist(address indexed account);
    event RemovedFromBlacklist(address indexed account);
    event UpdatedWhitelistEnabled(bool indexed isWhitelistEnabled);
    event UpdatedBaseURI(string newBaseURI);
    event AdminStatusSet(address indexed account, bool indexed isAdmin);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @dev Only allow the admin to call the function
    modifier onlyAdmin() {
        if (!s_admins[msg.sender]) revert SoulBoundToken__OnlyAdmin(msg.sender);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param baseURI The base URI for the token
    /// @param whitelistEnabled Whether the whitelist is enabled
    /// @dev Initializes the token ID counter to 1
    constructor(string memory name, string memory symbol, string memory baseURI, bool whitelistEnabled)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        _setBaseURI(baseURI);
        _setWhitelistEnabled(whitelistEnabled);
        s_tokenIdCounter = 1;
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @dev Mints a new token to the specified address
    /// @param account Address to mint the token to
    /// @return uint256 The ID of the minted token
    /// @dev Revert if account is not whitelisted when whitelist is enabled
    /// @dev Revert if account is blacklisted
    /// @dev Revert if account already holds a token
    /// @notice This function is only callable by the contract admins
    function mintAsAdmin(address account) external onlyAdmin returns (uint256) {
        return _mintAsAdmin(account);
    }

    /// @dev Mints a new token to each of the specified addresses
    /// @param accounts Addresses to mint the tokens to
    /// @return uint256[] The IDs of the minted tokens
    /// @dev Revert if accounts array is empty
    /// @dev Revert if any of the accounts are not whitelisted when whitelist is enabled
    /// @dev Revert if any of the accounts are blacklisted
    /// @dev Revert if any of the accounts already hold a token
    /// @notice This function is only callable by the contract admins
    function batchMintAsAdmin(address[] calldata accounts) external onlyAdmin returns (uint256[] memory) {
        _revertIfEmptyArray(accounts);
        uint256 startId = _incrementTokenIdCounter(accounts.length);

        uint256[] memory tokenIds = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _mintAsAdminChecks(accounts[i]);
            tokenIds[i] = startId + i;
            _safeMint(accounts[i], tokenIds[i]);
        }
        return tokenIds;
    }

    /// @dev Mints a new token to the msg.sender if they are whitelisted
    /// @return uint256 The ID of the minted token
    /// @dev Revert if whitelist is disabled
    /// @dev Revert if msg.sender is not whitelisted
    /// @dev Revert if msg.sender already holds a token
    function mintAsWhitelisted() external returns (uint256) {
        if (!_isWhitelistEnabled()) revert SoulBoundToken__WhitelistDisabled();
        _revertIfNotWhitelisted(msg.sender);
        _revertIfAlreadyMinted(msg.sender);
        return _mintSoulBoundToken(msg.sender);
    }

    /// @dev Adds an address to the whitelist
    /// @param account Address to add to the whitelist
    /// @notice This function is only callable by the contract admins
    /// @dev Revert if account == zero address
    /// @dev Revert if account already whitelisted
    /// @dev Revert if account blacklisted
    function addToWhitelist(address account) external onlyAdmin {
        _addToWhitelist(account);
    }

    /// @dev Adds multiple addresses to the whitelist
    /// @param accounts Addresses to add to the whitelist
    /// @dev Revert if any of the accounts are blacklisted or already whitelisted
    /// @dev Revert if accounts array is empty
    /// @notice This function is only callable by the contract admins
    function batchAddToWhitelist(address[] calldata accounts) external onlyAdmin {
        _revertIfEmptyArray(accounts);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _addToWhitelist(accounts[i]);
        }
    }

    /// @dev Removes an address from the whitelist
    /// @param account Address to remove from the whitelist
    /// @notice This function is only callable by the contract admins
    function removeFromWhitelist(address account) external onlyAdmin {
        _removeFromWhitelist(account);
    }

    /// @dev Removes multiple addresses from the whitelist
    /// @param accounts Addresses to remove from the whitelist
    /// @dev This will revert if any of the addresses are not already whitelisted
    /// @dev Revert if accounts array is empty
    /// @notice This function is only callable by the contract admins
    function batchRemoveFromWhitelist(address[] calldata accounts) external onlyAdmin {
        _revertIfEmptyArray(accounts);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _removeFromWhitelist(accounts[i]);
        }
    }

    /// @dev Adds an address to the blacklist
    /// @param account Address to add to the blacklist
    /// @notice This function is only callable by the contract admins
    /// @notice If the account holds a token, it will be burned
    /// @dev Revert if account == zero address
    /// @dev Revert if account is already blacklisted
    /// @dev Removes the account from the whitelist if present
    function addToBlacklist(address account) external onlyAdmin {
        _addToBlacklist(account);
    }

    /// @dev Adds multiple addresses to the blacklist
    /// @param accounts Addresses to add to the blacklist
    /// @notice This function is only callable by the contract admins
    /// @notice For each account, if they hold a token, it will be burned
    /// @dev Revert if any of the accounts are already blacklisted
    /// @dev Revert if accounts array is empty
    /// @dev Removes each account from the whitelist if present
    function batchAddToBlacklist(address[] calldata accounts) external onlyAdmin {
        _revertIfEmptyArray(accounts);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _addToBlacklist(accounts[i]);
        }
    }

    /// @dev Removes an address from the blacklist
    /// @param account Address to remove from the blacklist
    /// @notice This function is only callable by the contract admins
    function removeFromBlacklist(address account) external onlyAdmin {
        _removeFromBlacklist(account);
    }

    /// @dev Removes multiple addresses from the blacklist
    /// @param accounts Addresses to remove from the blacklist
    /// @dev This will revert if any of the accounts are not already blacklisted to save gas on SLOADs
    /// @dev Revert if accounts array is empty
    /// @notice This function is only callable by the contract admins
    function batchRemoveFromBlacklist(address[] calldata accounts) external onlyAdmin {
        _revertIfEmptyArray(accounts);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _removeFromBlacklist(accounts[i]);
        }
    }

    /// @dev Sets the admin status for an address
    /// @param account The address to set the admin status for
    /// @param isAdmin The admin status to set
    /// @dev Revert if the admin status is already set
    /// @notice Only the owner can set the admin status
    function setAdmin(address account, bool isAdmin) external onlyOwner {
        _setAdmin(account, isAdmin);
    }

    /// @dev Sets the admin status for multiple addresses
    /// @param accounts The addresses to set the admin status for
    /// @param isAdmin The admin status to set
    /// @dev Revert if the admin status is already set
    /// @dev Revert if accounts array is empty
    /// @notice Only the owner can set the admin status
    function batchSetAdmin(address[] calldata accounts, bool isAdmin) external onlyOwner {
        _revertIfEmptyArray(accounts);
        for (uint256 i = 0; i < accounts.length; ++i) {
            _setAdmin(accounts[i], isAdmin);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @dev Mints a new token to the specified address
    /// @param account Address to mint the token to
    /// @return tokenId The ID of the minted token
    function _mintSoulBoundToken(address account) internal returns (uint256 tokenId) {
        tokenId = _incrementTokenIdCounter(1);
        _safeMint(account, tokenId);
        return tokenId;
    }

    /// @dev Increments the tokenID counter
    /// @param count Amount to increment s_tokenIdCounter by
    /// @return startId The tokenId before incrementing
    /// @notice This function is to optimize storage read and writes when batch minting
    function _incrementTokenIdCounter(uint256 count) internal returns (uint256 startId) {
        startId = s_tokenIdCounter;
        s_tokenIdCounter += count;
        return startId;
    }

    /// @param account Address to check
    /// @dev Revert if account is not whitelisted when whitelist is enabled
    /// @dev Revert if account is blacklisted
    function _mintAsAdminChecks(address account) internal view {
        _revertIfAlreadyMinted(account);
        if (_isWhitelistEnabled()) _revertIfNotWhitelisted(account);
        _revertIfBlacklisted(account);
    }

    /// @dev Mints a new token to the specified address
    /// @param account Address to mint the token to
    /// @return uint256 The ID of the minted token
    /// @dev Revert if account is not whitelisted when whitelist is enabled
    /// @dev Revert if account is blacklisted
    function _mintAsAdmin(address account) internal returns (uint256) {
        _mintAsAdminChecks(account);
        return _mintSoulBoundToken(account);
    }

    /// @dev Adds an account to the whitelist
    /// @param account The address to add to the whitelist
    /// @dev Revert if account == zero address
    /// @dev Revert if account already whitelisted
    /// @dev Revert if account blacklisted
    function _addToWhitelist(address account) internal {
        _revertIfZeroAddress(account);
        if (s_whitelist[account]) revert SoulBoundToken__Whitelisted(account);
        _revertIfBlacklisted(account);

        s_whitelist[account] = true;
        emit AddedToWhitelist(account);
    }

    /// @dev Removes an account from the whitelist
    /// @param account The address to remove from the whitelist
    /// @dev Revert if account is not already on the whitelist
    function _removeFromWhitelist(address account) internal {
        _revertIfNotWhitelisted(account);

        s_whitelist[account] = false;
        emit RemovedFromWhitelist(account);
    }

    /// @dev Adds an account to the blacklist
    /// @param account The address to add to the blacklist
    /// @dev Revert if account == zero address
    /// @dev Revert if account already blacklisted
    /// @notice Removes account from whitelist if present
    /// @notice Will burn token if the account holds one
    function _addToBlacklist(address account) internal {
        _revertIfZeroAddress(account);
        _revertIfBlacklisted(account);

        if (s_whitelist[account]) {
            s_whitelist[account] = false;
            emit RemovedFromWhitelist(account);
        }

        if (balanceOf(account) > 0) {
            uint256 tokenId = tokenOfOwnerByIndex(account, 0); // Get first token
            _burn(tokenId); // Burn the token
        }

        s_blacklist[account] = true;
        emit AddedToBlacklist(account);
    }

    /// @dev Removes an account from the blacklist
    /// @param account The address to remove from the blacklist
    /// @dev Revert if account is not already on the blacklist
    function _removeFromBlacklist(address account) internal {
        if (!s_blacklist[account]) revert SoulBoundToken__NotBlacklisted(account);

        s_blacklist[account] = false;
        emit RemovedFromBlacklist(account);
    }

    /// @dev Revert if account is zero address
    function _revertIfZeroAddress(address account) internal pure {
        if (account == address(0)) revert SoulBoundToken__NoZeroAddress();
    }

    /// @dev Revert if account is blacklisted
    function _revertIfBlacklisted(address account) internal view {
        if (s_blacklist[account]) revert SoulBoundToken__Blacklisted(account);
    }

    /// @dev Revert if account is not whitelisted
    function _revertIfNotWhitelisted(address account) internal view {
        if (!s_whitelist[account]) revert SoulBoundToken__NotWhitelisted(account);
    }

    /// @dev Revert if empty array
    function _revertIfEmptyArray(address[] calldata accounts) internal pure {
        if (accounts.length == 0) revert SoulBoundToken__EmptyArray();
    }

    /// @dev Revert if already minted
    function _revertIfAlreadyMinted(address account) internal view {
        if (balanceOf(account) > 0) revert SoulBoundToken__AlreadyMinted(account);
    }

    /// @dev Enable whitelist
    /// @param whitelistEnabled Set to true for whitelist enabled, false for not enabled
    function _setWhitelistEnabled(bool whitelistEnabled) internal {
        bool previousEnabled = s_whitelistEnabled;
        if (previousEnabled == whitelistEnabled) revert SoulBoundToken__WhitelistStatusAlreadySet();
        s_whitelistEnabled = whitelistEnabled;
        emit UpdatedWhitelistEnabled(whitelistEnabled);
    }

    /// @dev Sets the base URI for token metadata
    /// @param baseURI New base URI
    function _setBaseURI(string memory baseURI) internal {
        s_baseURI = baseURI;
        emit UpdatedBaseURI(baseURI);
    }

    /// @dev Check if whitelist is enabled
    /// @return bool Whether the whitelist is enabled
    function _isWhitelistEnabled() internal view returns (bool) {
        return s_whitelistEnabled;
    }

    /// @dev Sets the admin status for an address
    /// @param account The address to set the admin status for
    /// @param isAdmin The admin status to set
    function _setAdmin(address account, bool isAdmin) internal {
        if (s_admins[account] == isAdmin) revert SoulBoundToken__AdminStatusAlreadySet(account, isAdmin);
        s_admins[account] = isAdmin;
        emit AdminStatusSet(account, isAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Sets the base URI for token metadata
    /// @param baseURI New base URI
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    /// @dev Sets whitelist to enabled
    function setWhitelistEnabled(bool whitelistEnabled) external onlyAdmin {
        _setWhitelistEnabled(whitelistEnabled);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Checks if an address is whitelisted
    /// @param account Address to check
    /// @return bool Whether the address is whitelisted
    function getWhitelisted(address account) external view returns (bool) {
        return s_whitelist[account];
    }

    /// @dev Checks if an address is blacklisted
    /// @param account Address to check
    /// @return bool Whether the address is blacklisted
    function getBlacklisted(address account) external view returns (bool) {
        return s_blacklist[account];
    }

    /// @dev Checks if an address is an admin
    /// @param account Address to check
    /// @return bool Whether the address is an admin
    function getAdmin(address account) external view returns (bool) {
        return s_admins[account];
    }

    /// @dev Check if whitelist is enabled
    /// @return bool Whether the whitelist is enabled
    function getWhitelistEnabled() external view returns (bool) {
        return _isWhitelistEnabled();
    }

    /// @dev Returns the base URI for token metadata
    /// @return string The base URI
    function getBaseURI() external view returns (string memory) {
        return _baseURI();
    }

    /// @return tokenIdCounter token ID for the next token to be minted
    function getTokenIdCounter() external view returns (uint256) {
        return s_tokenIdCounter;
    }

    /*//////////////////////////////////////////////////////////////
                                OVERRIDE
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the base URI for token metadata
    /// @return string The base URI
    function _baseURI() internal view override returns (string memory) {
        return s_baseURI;
    }

    /// @dev Override to prevent approval for non-transferrable tokens
    function approve(address, /* to */ uint256 /* tokenId */ ) public pure override(ERC721, IERC721) {
        revert SoulBoundToken__ApprovalNotAllowed();
    }

    /// @dev Override to prevent approval for non-transferrable tokens
    function setApprovalForAll(address, /* operator */ bool /* approved */ ) public pure override(ERC721, IERC721) {
        revert SoulBoundToken__ApprovalNotAllowed();
    }

    /// @dev Override to prevent transfers
    function transferFrom(address, address, uint256) public pure override(ERC721, IERC721) {
        revert SoulBoundToken__TransferNotAllowed();
    }
}
