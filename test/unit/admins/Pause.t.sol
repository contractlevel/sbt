// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract PauseTest is BaseTest {
    function test_sbt_pause_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.pause();
    }

    function test_sbt_pause_revertsWhen_alreadyPaused() public {
        _changePrank(admin);
        sbt.pause();
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        sbt.pause();
    }

    function test_sbt_unpause_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.unpause();
    }

    function test_sbt_unpause_revertsWhen_notPaused() public {
        _changePrank(admin);
        vm.expectRevert(abi.encodeWithSignature("ExpectedPause()"));
        sbt.unpause();
    }
}
