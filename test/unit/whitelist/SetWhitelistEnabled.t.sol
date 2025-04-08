// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract SetWhitelistEnabledTest is BaseTest {
    function test_sbt_setWhitelistEnabled_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.setWhitelistEnabled(true);
    }

    function test_sbt_setWhitelistEnabled_revertsWhen_whitelistStatusAlreadySet() public {
        _changePrank(admin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__WhitelistStatusAlreadySet()"));
        sbt.setWhitelistEnabled(true);
    }

    function test_sbt_setWhitelistEnabled_success() public {
        assertTrue(sbt.getWhitelistEnabled());
        _changePrank(admin);
        sbt.setWhitelistEnabled(false);
        assertFalse(sbt.getWhitelistEnabled());
    }
}
