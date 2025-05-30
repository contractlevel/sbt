// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ERC721Enumerable,
    IERC721Enumerable,
    ERC721
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";
import {IAggregator} from "./interfaces/IAggregator.sol";
import {ISoulBoundToken} from "./interfaces/ISoulBoundToken.sol";

import {console2} from "forge-std/Test.sol";

/// @title SoulBoundToken
/// @author @contractlevel
/// @notice Non-transferrable ERC721 token with administrative whitelist and blacklist functionality
/// @notice System Actors: Owner, Admins, Whitelisted, Blacklisted, Public Minters
/// @dev Owner - sets admin role and contract URI
/// @dev Admins - set whitelisted and blacklisted roles, and enables/disables whitelist
/// @dev Whitelisted - can mint a token if whitelist is enabled
/// @dev Blacklisted - if held token, then burnt, and if whitelisted, then removed, and cant be whitelisted or minted/mint themselves
/// @dev Public Minters - can mint a token if they sign a message agreeing with Terms of Service
/// @notice Non-whitelisted users can mint tokens if they sign a message agreeing with Terms of Service
/// @notice Fees are enforced on all user mints, and set by admins
contract SoulBoundToken is ERC721Enumerable, Ownable2Step, Pausable, ISoulBoundToken {
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
    error SoulBoundToken__InvalidSignature();
    error SoulBoundToken__IncorrectFee();
    error SoulBoundToken__WithdrawFailed();
    error SoulBoundToken__NoZeroValue();
    error SoulBoundToken__InsufficientBalance();
    error SoulBoundToken__StalePriceFeed();
    error SoulBoundToken__SequencerDown();
    error SoulBoundToken__GracePeriodNotOver();
    error SoulBoundToken__InvalidPrice();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Grace period for sequencer uptime feed
    uint256 internal constant GRACE_PERIOD_TIME = 120 seconds;

    /// @dev Chainlink price feed for native/USD
    IAggregatorV3 internal immutable i_nativeUsdFeed;
    /// @dev Price feed staleness threshold
    uint256 internal immutable i_priceFeedStalenessThreshold;
    /// @dev Chainlink price feed for sequencer uptime
    IAggregatorV3 internal immutable i_sequencerUptimeFeed;
    /// @dev Price feed precision
    uint256 internal immutable i_priceFeedPrecision;

    /// @dev Hash of contract URI (which is intended to be IPFS resource for Terms of Service)
    bytes32 internal s_termsHash;
    /// @dev Admin-configurable value used to calculate mint fee
    /// @notice This value should be in USD with 18 decimals. ie 1 USD = 1e18 (1000000000000000000)
    uint256 internal s_feeFactor;
    /// @dev Token counter for minting
    uint256 internal s_tokenIdCounter;
    /// @dev Contract URI for token metadata
    string internal s_contractURI;
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
    event ContractURIUpdated();
    event AdminStatusSet(address indexed account, bool indexed isAdmin);
    event TermsHashed(bytes32 indexed hashedTerms, string contractURI);
    event FeeCollected(address indexed user, uint256 amount, uint256 tokenId);
    event FeesWithdrawn(uint256 amount);
    event FeeFactorSet(uint256 feeFactor);
    event SignatureVerified(address indexed signer, bytes signature);

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
    /// @param initialContractURI The contract URI for the token
    /// @param whitelistEnabled Whether the whitelist is enabled
    /// @param nativeUsdFeed The address of the native/USD Chainlink price feed
    /// @param owner The owner of the contract
    /// @param admins The initial admins of the contract
    /// @param priceFeedStalenessThreshold The staleness threshold for the price feed
    /// @dev Sets the admin status for the initial admins
    /// @dev Initializes the token ID counter to 1
    /// @dev Hashes the contract URI and stores in s_termsHash
    constructor(
        string memory name,
        string memory symbol,
        string memory initialContractURI,
        bool whitelistEnabled,
        address nativeUsdFeed,
        address owner,
        address[] memory admins,
        uint256 priceFeedStalenessThreshold,
        address sequencerUptimeFeed
    ) ERC721(name, symbol) Ownable(owner) {
        for (uint256 i; i < admins.length; ++i) {
            _setAdmin(admins[i], true);
        }
        _setContractURI(initialContractURI);
        _setWhitelistEnabled(whitelistEnabled);
        s_tokenIdCounter = 1;
        i_nativeUsdFeed = IAggregatorV3(nativeUsdFeed);
        i_priceFeedStalenessThreshold = priceFeedStalenessThreshold;
        i_sequencerUptimeFeed = IAggregatorV3(sequencerUptimeFeed);
        i_priceFeedPrecision = 10 ** i_nativeUsdFeed.decimals();
        _hashTerms(initialContractURI);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @dev Mints a new token to the specified address
    /// @param account Address to mint the token to
    /// @return uint256 The ID of the minted token
    /// @dev Revert if account is blacklisted
    /// @dev Revert if account already holds a token
    /// @notice ERC721 reverts if account == zero address
    /// @notice This function is only callable by the contract admins
    function mintAsAdmin(address account) external onlyAdmin returns (uint256) {
        return _mintAsAdmin(account);
    }

    /// @dev Mints a new token to each of the specified addresses
    /// @param accounts Addresses to mint the tokens to
    /// @return tokenIds The IDs of the minted tokens
    /// @dev Revert if accounts array is empty
    /// @dev Revert if any of the accounts are blacklisted
    /// @dev Revert if any of the accounts already hold a token
    /// @notice ERC721 reverts if any of the accounts == zero address
    /// @notice This function is only callable by the contract admins
    function batchMintAsAdmin(address[] calldata accounts) external onlyAdmin returns (uint256[] memory tokenIds) {
        _revertIfEmptyArray(accounts);
        uint256 startId = _incrementTokenIdCounter(accounts.length);

        tokenIds = new uint256[](accounts.length);
        for (uint256 i; i < accounts.length; ++i) {
            _mintAsAdminChecks(accounts[i]);
            tokenIds[i] = startId + i;
            _safeMint(accounts[i], tokenIds[i]);
        }
    }

    /// @dev Mints a new token to the msg.sender if they are whitelisted
    /// @return tokenId The ID of the minted token
    /// @dev Revert if whitelist is disabled
    /// @dev Revert if msg.sender is not whitelisted
    /// @dev Revert if msg.sender already holds a token
    /// @dev Revert if msg.value is not equal to the fee
    function mintAsWhitelisted() external payable returns (uint256 tokenId) {
        _revertIfIncorrectFee();
        if (!_isWhitelistEnabled()) revert SoulBoundToken__WhitelistDisabled();
        _revertIfNotWhitelisted(msg.sender);
        _revertIfAlreadyMinted(msg.sender);
        tokenId = _mintSoulBoundToken(msg.sender);
        /// @notice the condition for emitting this event may not be optimal in terms of readability
        /// if someone pays a higher fee than is required
        /// but other than that it is functionally correct and efficient in terms of gas
        if (msg.value > 0) emit FeeCollected(msg.sender, msg.value, tokenId);
    }

    /// @dev Mints a new token to the msg.sender if they sign the termsHash
    /// @notice This function requires a signature from the msg.sender, including the hash of this token's contract URI
    /// The contract URI is intended to be an IPFS reference containing Terms of Service for token holders.
    /// @param signature Signed by msg.sender with Terms of Service hash
    /// @dev Revert if msg.value is not equal to the fee
    /// @dev Revert if signature is invalid
    /// @dev Revert if msg.sender already holds a token
    /// @dev Revert if contract is paused
    function mintWithTerms(bytes calldata signature) external payable whenNotPaused returns (uint256 tokenId) {
        _revertIfIncorrectFee();
        _revertIfBlacklisted(msg.sender);
        _revertIfAlreadyMinted(msg.sender);

        if (!_verifySignature(signature)) revert SoulBoundToken__InvalidSignature();
        emit SignatureVerified(msg.sender, signature);

        tokenId = _mintSoulBoundToken(msg.sender);

        if (msg.value > 0) emit FeeCollected(msg.sender, msg.value, tokenId);
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
        for (uint256 i; i < accounts.length; ++i) {
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
        for (uint256 i; i < accounts.length; ++i) {
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
        for (uint256 i; i < accounts.length; ++i) {
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
        for (uint256 i; i < accounts.length; ++i) {
            _removeFromBlacklist(accounts[i]);
        }
    }

    /// @dev Sets the admin status for an address
    /// @param account The address to set the admin status for
    /// @param isAdmin The admin status to set
    /// @dev Revert if the admin status is already set
    /// @notice Only the owner can set the admin status
    function setAdmin(address account, bool isAdmin) external onlyOwner {
        _setAdminChecks(account, isAdmin);
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
        for (uint256 i; i < accounts.length; ++i) {
            _setAdminChecks(accounts[i], isAdmin);
            _setAdmin(accounts[i], isAdmin);
        }
    }

    /// @notice Owner only function for withdrawing fees
    /// @dev Revert if caller is not owner
    /// @notice Withdraws contract balance to owner
    //slither-disable-next-line reentrancy-events
    function withdrawFees() external onlyOwner {
        uint256 amountToWithdraw = address(this).balance;
        if (amountToWithdraw > 0) {
            // from https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol#L90-L98 /// @solidity memory-safe-assembly
            assembly {
                if iszero(call(gas(), caller(), amountToWithdraw, codesize(), 0x00, codesize(), 0x00)) {
                    mstore(0x00, 0xefde920d) // `SoulBoundToken__WithdrawFailed()`.
                    revert(0x1c, 0x04)
                }
            }
            emit FeesWithdrawn(amountToWithdraw);
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
    }

    /// @dev Increments the tokenID counter
    /// @param count Amount to increment s_tokenIdCounter by
    /// @return startId The tokenId before incrementing
    /// @notice This function is to optimize storage read and writes when batch minting
    function _incrementTokenIdCounter(uint256 count) internal returns (uint256 startId) {
        startId = s_tokenIdCounter;
        s_tokenIdCounter += count;
    }

    /// @param account Address to check
    /// @dev Revert if account is blacklisted
    function _mintAsAdminChecks(address account) internal view {
        _revertIfAlreadyMinted(account);
        _revertIfBlacklisted(account);
    }

    /// @dev Mints a new token to the specified address
    /// @param account Address to mint the token to
    /// @return uint256 The ID of the minted token
    /// @dev Revert if account already holds a token
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

    /// @dev Sets the contract URI for token metadata
    /// @param newContractURI New contract URI
    function _setContractURI(string memory newContractURI) internal {
        s_contractURI = newContractURI;
        emit ContractURIUpdated();
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
        s_admins[account] = isAdmin;
        emit AdminStatusSet(account, isAdmin);
    }

    /// @dev Revert if account is zero address
    /// @dev Revert if admin status is already set
    /// @notice Only the owner can set the admin status
    /// @param account The address to set the admin status for
    /// @param isAdmin The admin status to set
    function _setAdminChecks(address account, bool isAdmin) internal view {
        _revertIfZeroAddress(account);
        if (s_admins[account] == isAdmin) revert SoulBoundToken__AdminStatusAlreadySet(account, isAdmin);
    }

    /// @notice This function verifies whether a signature is valid or not
    /// @param signature Signed and passed by the user when minting
    /// @return isValid True if the signature is valid, false if not
    function _verifySignature(bytes calldata signature) internal view returns (bool) {
        /// @dev compute the message hash: keccak256(termsHash, msg.sender)
        bytes32 messageHash = keccak256(abi.encodePacked(s_termsHash, msg.sender));

        /// @dev apply Ethereum signed message prefix
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        /// @dev attempt to recover the signer
        //slither-disable-next-line unused-return
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(ethSignedMessageHash, signature);

        /// @dev if the signer is an EOA, return true if the signature is valid
        if (error == ECDSA.RecoverError.NoError && recovered == msg.sender) return true;
        /// @dev else check if the signature is valid for a smart contract
        else return SignatureChecker.isValidERC1271SignatureNow(msg.sender, ethSignedMessageHash, signature);
    }

    /// @param newContractURI SBT contract URI (intended to be IPFS resource)
    /// @dev Hashes the contractURI and stores it
    function _hashTerms(string memory newContractURI) internal {
        bytes32 hashedTerms = keccak256(abi.encodePacked(newContractURI));
        s_termsHash = hashedTerms;
        emit TermsHashed(hashedTerms, newContractURI);
    }

    /// @dev reverts if msg.value is less than fee
    function _revertIfIncorrectFee() internal view {
        if (msg.value != _getFee()) revert SoulBoundToken__IncorrectFee();
    }

    /// @dev returns the latest native/USD price
    /// @dev Revert if sequencer is down
    /// @dev Revert if grace period is not over
    /// @dev Revert if price is out of bounds
    /// @dev Revert if price feed is stale
    function _getLatestPrice() internal view returns (uint256) {
        //slither-disable-next-line unused-return
        (, int256 answer, uint256 startedAt,,) = i_sequencerUptimeFeed.latestRoundData();
        if (answer == 1) revert SoulBoundToken__SequencerDown();
        //slither-disable-next-line timestamp
        if (_getGracePeriodActive(startedAt)) revert SoulBoundToken__GracePeriodNotOver();

        //slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = i_nativeUsdFeed.latestRoundData();

        IAggregator aggregator = IAggregator(i_nativeUsdFeed.aggregator());
        if (price < aggregator.minAnswer() || price > aggregator.maxAnswer()) revert SoulBoundToken__InvalidPrice();

        //slither-disable-next-line timestamp
        if (updatedAt < block.timestamp - i_priceFeedStalenessThreshold) revert SoulBoundToken__StalePriceFeed();

        return uint256(price);
    }

    /// @dev Checks if the grace period is active
    /// @param startedAt The timestamp of the last round
    /// @return bool Whether the grace period is active
    function _getGracePeriodActive(uint256 startedAt) internal view returns (bool) {
        //slither-disable-next-line timestamp
        return block.timestamp - startedAt <= GRACE_PERIOD_TIME;
    }

    /// @dev gets the fee for minting
    function _getFee() internal view returns (uint256 fee) {
        // read fee factor directly to output variable
        fee = s_feeFactor;
        // only do extra work if non-zero
        if (fee != 0) fee = FixedPointMathLib.fullMulDivUp(fee, i_priceFeedPrecision, _getLatestPrice());
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Sets the contract URI for token metadata
    /// @param newContractURI New contract URI
    function setContractURI(string memory newContractURI) external onlyOwner {
        _setContractURI(newContractURI);
        _hashTerms(newContractURI);
    }

    /// @dev Sets whitelist to enabled
    function setWhitelistEnabled(bool whitelistEnabled) external onlyAdmin {
        _setWhitelistEnabled(whitelistEnabled);
    }

    /// @dev Sets the factor used for calculating the fee
    /// @param newFeeFactor the new factor value used for calculating the fee
    /// @notice This is an admin only function
    /// @dev This value should be in USD with 18 decimals. ie 1 USD = 1e18 (1000000000000000000)
    function setFeeFactor(uint256 newFeeFactor) external onlyAdmin {
        s_feeFactor = newFeeFactor;
        emit FeeFactorSet(newFeeFactor);
    }

    /// @dev Pauses the contract
    /// @notice This is an admin only function
    /// @dev Revert if contract is paused
    /// @notice Pause functionality in this contract is used to disable public minting
    function pause() external onlyAdmin {
        _pause();
    }

    /// @dev Unpauses the contract
    /// @notice This is an admin only function
    /// @dev Revert if contract is not paused
    /// @notice Unpause functionality in this contract is used to enable public minting
    function unpause() external onlyAdmin {
        _unpause();
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

    /// @dev Returns the contract URI for token metadata
    /// @return string The contract URI
    function contractURI() external view returns (string memory) {
        return _contractURI();
    }

    /// @return tokenIdCounter token ID for the next token to be minted
    function getTokenIdCounter() external view returns (uint256) {
        return s_tokenIdCounter;
    }

    /// @return fee msg.value amount required for minting
    function getFee() external view returns (uint256) {
        return _getFee();
    }

    /// @return termsHash This is a hash of the contract URI which should be used when signing a message to mint with terms
    function getTermsHash() external view returns (bytes32) {
        return s_termsHash;
    }

    /// @return nativeUsdFeed Chainlink price feed for native/USD used to calculate fee
    function getNativeUsdFeed() external view returns (address) {
        return address(i_nativeUsdFeed);
    }

    /// @return feeFactor The value set by admins to calculate fee price
    function getFeeFactor() external view returns (uint256) {
        return s_feeFactor;
    }

    /// @dev Checks if the grace period for the sequencer uptime feed is active
    /// @dev If this is returning true, then minting will revert if it requires a fee
    /// @return bool Whether the grace period is active
    function getGracePeriodActive() external view returns (bool) {
        //slither-disable-next-line unused-return
        (,, uint256 startedAt,,) = i_sequencerUptimeFeed.latestRoundData();
        return _getGracePeriodActive(startedAt);
    }

    /*//////////////////////////////////////////////////////////////
                                OVERRIDE
    //////////////////////////////////////////////////////////////*/
    /// @dev Returns the contract URI for token metadata
    /// @return string The contract URI
    function _contractURI() internal view returns (string memory) {
        return s_contractURI;
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
