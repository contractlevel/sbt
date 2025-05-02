// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {BaseTest, Vm, console2, SoulBoundToken} from "../BaseTest.t.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, BaseTest {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Handler contract we are running calls to the SBT through
    Handler internal handler;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public override {
        /// @dev deployments
        _deployInfra();
        handler = new Handler(sbt, owner);

        /// @dev define appropriate function selectors
        bytes4[] memory selectors = new bytes4[](19);
        /// @dev mint functions
        selectors[0] = Handler.mintAsAdmin.selector;
        selectors[1] = Handler.mintAsWhitelisted.selector;
        selectors[2] = Handler.batchMintAsAdmin.selector;
        selectors[3] = Handler.mintWithTerms.selector;
        /// @dev whitelist functions
        selectors[4] = Handler.setWhitelistEnabled.selector;
        selectors[5] = Handler.addToWhitelist.selector;
        selectors[6] = Handler.removeFromWhitelist.selector;
        selectors[7] = Handler.batchAddToWhitelist.selector;
        selectors[8] = Handler.batchRemoveFromWhitelist.selector;
        /// @dev blacklist functions
        selectors[9] = Handler.addToBlacklist.selector;
        selectors[10] = Handler.removeFromBlacklist.selector;
        selectors[11] = Handler.batchAddToBlacklist.selector;
        selectors[12] = Handler.batchRemoveFromBlacklist.selector;
        /// @dev owner functions
        selectors[13] = Handler.setAdmin.selector;
        selectors[14] = Handler.batchSetAdmin.selector;
        selectors[15] = Handler.setBaseURI.selector;
        selectors[16] = Handler.withdrawFees.selector;
        /// @dev other admin functions
        selectors[17] = Handler.setFeeFactor.selector;
        /// @dev utility
        selectors[18] = Handler.changeNativeUsdPrice.selector;

        /// @dev target handler and appropriate function selectors
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANTS
    //////////////////////////////////////////////////////////////*/
    // Blacklisted should not hold token:
    /// @dev no blacklisted accounts should hold the token
    function invariant_blacklisted_noToken() public {
        handler.forEachBlacklisted(this.checkBlacklistedBalanceOfZero);
    }

    function checkBlacklistedBalanceOfZero(address blacklisted) external view {
        assertEq(sbt.balanceOf(blacklisted), 0, "Invariant violated: Blacklisted account should not hold the token.");
    }

    // Holder should not have more than 1 token:
    // loop through all holders and assert balance is 1
    function invariant_holder_oneToken() public {
        handler.forEachHolder(this.checkHolderBalanceOfOne);
    }

    function checkHolderBalanceOfOne(address holder) external view {
        assertEq(sbt.balanceOf(holder), 1, "Invariant violated: Holder should not have more than 1 token.");
    }

    // Total supply should be total minted minus total burned:
    function invariant_totalSupply_totalMintedMinusTotalBurned() public view {
        assertEq(
            sbt.totalSupply(),
            handler.g_totalMinted() - handler.g_totalBurned(),
            "Invariant violated: Total supply should be total minted minus total burned."
        );
    }

    // No approvals should exist:
    // loop through all tokens and assert that the token has no approved address
    function invariant_noApprovals() public view {
        uint256 totalSupply = sbt.totalSupply();
        for (uint256 i = 0; i < totalSupply; i++) {
            uint256 tokenId = sbt.tokenByIndex(i);
            assertEq(
                sbt.getApproved(tokenId), address(0), "Invariant violated: Token should not have an approved address."
            );
        }
    }

    // Fee Accountancy: SBT balance should equal (or be more than) total accumulated fees - total withdrawn
    function invariant_feesAccountancy() public {
        assertEq(
            address(sbt).balance,
            handler.g_totalFeesAccumulated() - handler.g_totalFeesWithdrawn(),
            "Invariant violated: SBT balance should be equal to total fees accumulated minus total withdrawn."
        );
    }
}
