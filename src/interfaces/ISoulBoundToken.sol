// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface ISoulBoundToken is IERC721Enumerable {
    /// @dev admin functions
    function mintAsAdmin(address account) external returns (uint256);
    function addToWhitelist(address account) external;
    function addToBlacklist(address account) external;
    function removeFromWhitelist(address account) external;
    function removeFromBlacklist(address account) external;
    function batchAddToWhitelist(address[] calldata accounts) external;
    function batchAddToBlacklist(address[] calldata accounts) external;
    function batchRemoveFromWhitelist(address[] calldata accounts) external;
    function batchRemoveFromBlacklist(address[] calldata accounts) external;
    function setWhitelistEnabled(bool whitelistEnabled) external;
    function setFeeFactor(uint256 newFeeFactor) external;

    /// @dev non-admin functions
    function mintAsWhitelisted() external payable returns (uint256);
    function mintWithTerms(bytes memory signature) external payable returns (uint256 tokenId);

    /// @dev owner functions
    function setContractURI(string memory contractURI) external;
    function withdrawFees(uint256 amountToWithdraw) external;
    function setAdmin(address account, bool isAdmin) external;
    function batchSetAdmin(address[] calldata accounts, bool isAdmin) external;

    /// @dev getter functions
    function getWhitelisted(address account) external view returns (bool);
    function getBlacklisted(address account) external view returns (bool);
    function getAdmin(address account) external view returns (bool);
    function getWhitelistEnabled() external view returns (bool);
    function getTokenIdCounter() external view returns (uint256);
    function contractURI() external view returns (string memory);
    /// @notice these two will be used in frontend for facilitating user mints
    function getFee() external view returns (uint256);
    function getTermsHash() external view returns (bytes32);
}
