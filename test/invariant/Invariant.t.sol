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
        bytes4[] memory selectors = new bytes4[](13);
        /// @dev mint functions
        selectors[0] = Handler.mintAsAdmin.selector;
        selectors[1] = Handler.mintAsWhitelisted.selector;
        selectors[2] = Handler.batchMintAsAdmin.selector;
        /// @dev whitelist functions
        selectors[3] = Handler.addToWhitelist.selector;
        selectors[4] = Handler.removeFromWhitelist.selector;
        selectors[5] = Handler.batchAddToWhitelist.selector;
        selectors[6] = Handler.batchRemoveFromWhitelist.selector;
        /// @dev blacklist functions
        selectors[7] = Handler.addToBlacklist.selector;
        selectors[8] = Handler.removeFromBlacklist.selector;
        selectors[9] = Handler.batchAddToBlacklist.selector;
        selectors[10] = Handler.batchRemoveFromBlacklist.selector;
        /// @dev owner functions
        selectors[11] = Handler.setAdmin.selector;
        selectors[12] = Handler.batchSetAdmin.selector;

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
}
