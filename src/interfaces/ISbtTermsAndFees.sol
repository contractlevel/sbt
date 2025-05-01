// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ISoulBoundToken} from "./ISoulBoundToken.sol";

interface ISbtTermsAndFees is ISoulBoundToken {
    function mintWithTerms(bytes memory signature) external payable returns (uint256 tokenId);
    function withdrawFees(uint256 amountToWithdraw) external;
    function setFeeFactor(uint256 newFeeFactor) external;
    function getFee() external view returns (uint256);
    function getTermsHash() external view returns (bytes32);
}
