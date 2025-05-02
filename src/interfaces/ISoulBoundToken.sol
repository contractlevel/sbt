// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface ISoulBoundToken is IERC721Enumerable {
    function mintAsAdmin(address account) external returns (uint256);
    function mintAsWhitelisted() external payable returns (uint256);
    function addToWhitelist(address account) external;
    function batchAddToWhitelist(address[] calldata accounts) external;
    function removeFromWhitelist(address account) external;
    function batchRemoveFromWhitelist(address[] calldata accounts) external;
    function addToBlacklist(address account) external;
    function batchAddToBlacklist(address[] calldata accounts) external;
    function removeFromBlacklist(address account) external;
    function batchRemoveFromBlacklist(address[] calldata accounts) external;
    function setBaseURI(string memory baseURI) external;
    function setWhitelistEnabled(bool whitelistEnabled) external;
    function getWhitelisted(address account) external view returns (bool);
    function getBlacklisted(address account) external view returns (bool);
    function getAdmin(address account) external view returns (bool);
    function getWhitelistEnabled() external view returns (bool);
    function getBaseURI() external view returns (string memory);
    function getTokenIdCounter() external view returns (uint256);
    function mintWithTerms(bytes memory signature) external payable returns (uint256 tokenId);
    function withdrawFees(uint256 amountToWithdraw) external;
    function setFeeFactor(uint256 newFeeFactor) external;
    function getFee() external view returns (uint256);
    function getTermsHash() external view returns (bytes32);
}
