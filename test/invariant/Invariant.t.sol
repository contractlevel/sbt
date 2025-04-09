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
        bytes4[] memory selectors = new bytes4[](15);
        /// @dev mint functions
        selectors[0] = Handler.mintAsAdmin.selector;
        selectors[1] = Handler.mintAsWhitelisted.selector;
        selectors[2] = Handler.batchMintAsAdmin.selector;
        /// @dev whitelist functions
        selectors[3] = Handler.setWhitelistEnabled.selector;
        selectors[4] = Handler.addToWhitelist.selector;
        selectors[5] = Handler.removeFromWhitelist.selector;
        selectors[6] = Handler.batchAddToWhitelist.selector;
        selectors[7] = Handler.batchRemoveFromWhitelist.selector;
        /// @dev blacklist functions
        selectors[8] = Handler.addToBlacklist.selector;
        selectors[9] = Handler.removeFromBlacklist.selector;
        selectors[10] = Handler.batchAddToBlacklist.selector;
        selectors[11] = Handler.batchRemoveFromBlacklist.selector;
        /// @dev owner functions
        selectors[12] = Handler.setAdmin.selector;
        selectors[13] = Handler.batchSetAdmin.selector;
        selectors[14] = Handler.setBaseURI.selector;

        /// @dev target handler and appropriate function selectors
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // @review make this file BaseInvariant and inherit it?

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
}
