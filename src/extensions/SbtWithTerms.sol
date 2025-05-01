// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SoulBoundToken} from "../SoulBoundToken.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title SoulBoundToken with Terms of Service
/// @author @contractlevel
/// @notice This contract is an extension of SoulBoundToken
/// @notice Non-whitelisted users can mint tokens if they sign a message agreeing with Terms of Service
contract SbtWithTerms is SoulBoundToken {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SbtWithTerms__WhitelistEnabled();
    error SbtWithTerms__InvalidSignature();
    error SbtWithTerms__InsufficientFee();
    error SbtWithTerms__WithdrawFailed();

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Value used to calculate mint fee
    uint256 internal constant PRICE_FEED_PRECISION = 10 ** 8; // 8 decimals for ETH/USD

    /// @dev Chainlink price feed for native/USD
    AggregatorV3Interface internal immutable i_nativeUsdFeed;

    /// @dev Hash of base URI (which is intended to be IPFS resource for Terms of Service)
    bytes32 internal s_termsHash;
    /// @dev Admin-configurable value used to calculate mint fee
    /// @notice This value should be in USD with 18 decimals. ie 1 USD = 1e18 (1000000000000000000)
    uint256 internal s_feeFactor;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event TermsHashed(bytes32 indexed hashedTerms, string baseURI);
    event FeeCollected(address indexed user, uint256 amount, uint256 tokenId, bytes32 indexed termsHash);
    event FeesWithdrawn(address indexed admin, uint256 amount);
    event FeeFactorSet(address indexed admin, uint256 newFeeFactor);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        bool whitelistEnabled,
        address nativeUsdFeed
    ) SoulBoundToken(name, symbol, baseURI, whitelistEnabled) {
        i_nativeUsdFeed = AggregatorV3Interface(nativeUsdFeed);
        _hashTerms(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @notice This function requires a signature from the msg.sender, including the hash of this token's base URI
    /// The base URI is intended to be an IPFS reference containing Terms of Service for token holders.
    /// @param signature Signed by msg.sender with Terms of Service hash
    /// @dev Revert if insufficient fee (ie msg.value is less than getFee())
    /// @dev Revert if whitelist is enabled
    /// @dev Revert if signature is invalid
    /// @dev Revert if msg.sender already holds a token
    function mintWithTerms(bytes memory signature) external payable returns (uint256 tokenId) {
        _revertIfInsufficientFee();
        if (s_whitelistEnabled) revert SbtWithTerms__WhitelistEnabled();

        bytes32 termsHash = s_termsHash;
        if (!_verifySignature(signature, termsHash)) revert SbtWithTerms__InvalidSignature();

        _revertIfAlreadyMinted(msg.sender);

        tokenId = _mintSoulBoundToken(msg.sender);

        if (msg.value > 0) emit FeeCollected(msg.sender, msg.value, tokenId, termsHash);
    }

    // @review - should we be overriding mintAsWhitelisted() and requiring a fee?

    /// @notice Admin only function for withdrawing fees
    /// @param amountToWithdraw The amount of address(this).balance to withdraw
    /// @dev Revert if caller is not admin
    function withdrawFees(uint256 amountToWithdraw) external onlyAdmin {
        (bool success,) = payable(msg.sender).call{value: amountToWithdraw}("");
        if (!success) revert SbtWithTerms__WithdrawFailed();
        emit FeesWithdrawn(msg.sender, amountToWithdraw);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    /// @notice This function verifies whether a signature is valid or not
    /// @param signature Signed and passed by the user when minting
    /// @param termsHash Read from storage s_termsHash in mintWithTerms()
    /// @return isValid True if the signature is valid, false if not
    function _verifySignature(bytes memory signature, bytes32 termsHash) internal view returns (bool) {
        /// @dev compute the message hash: keccak256(termsHash, msg.sender)
        bytes32 messageHash = keccak256(abi.encodePacked(termsHash, msg.sender));

        /// @dev apply Ethereum signed message prefix
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        /// @dev attempt to recover the signer
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(ethSignedMessageHash, signature);

        /// @dev return false if errors or incorrect signer
        if (error != ECDSA.RecoverError.NoError || recovered != msg.sender) return false;
        else return true;
    }

    function _hashTerms(string memory baseURI) internal {
        bytes32 hashedTerms = keccak256(abi.encodePacked(baseURI));
        s_termsHash = hashedTerms;
        emit TermsHashed(hashedTerms, baseURI);
    }

    function _revertIfInsufficientFee() internal view {
        if (msg.value < _getFee()) revert SbtWithTerms__InsufficientFee();
    }

    /// @dev returns the latest native/USD price
    function _getLatestPrice() internal view returns (uint256) {
        //slither-disable-next-line unused-return
        (, int256 price,,,) = i_nativeUsdFeed.latestRoundData();
        return uint256(price);
    }

    /// @dev gets the fee for minting
    function _getFee() internal view returns (uint256) {
        uint256 feeFactor = s_feeFactor;
        if (feeFactor == 0) return 0;
        else return (feeFactor * PRICE_FEED_PRECISION) / _getLatestPrice();
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTER
    //////////////////////////////////////////////////////////////*/
    /// @dev Sets the base URI for token metadata
    /// @param baseURI New base URI
    function setBaseURI(string memory baseURI) external override onlyOwner {
        _setBaseURI(baseURI);
        _hashTerms(baseURI);
    }

    /// @dev Sets the factor used for calculating the fee
    /// @param newFeeFactor the new factor value used for calculating the fee
    /// @notice This is an admin only function
    function setFeeFactor(uint256 newFeeFactor) external onlyAdmin {
        s_feeFactor = newFeeFactor;
        emit FeeFactorSet(msg.sender, newFeeFactor);
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    /// @return fee msg.value amount required for minting
    function getFee() external view returns (uint256) {
        return _getFee();
    }

    /// @return termsHash This is a hash of the base URI which should be used when signing a message to mintWithTerms()
    function getTermsHash() external view returns (bytes32) {
        return s_termsHash;
    }
}
