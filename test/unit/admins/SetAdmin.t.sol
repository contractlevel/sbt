// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract SetAdminTest is BaseTest {
    function test_sbt_setAdmin_revertsWhen_notOwner() public {
        _changePrank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        sbt.setAdmin(notOwner, true);
    }

    function test_sbt_setAdmin_revertsWhen_alreadySet() public {
        assertTrue(sbt.getAdmin(admin));
        _changePrank(owner);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AdminStatusAlreadySet(address,bool)", admin, true));
        sbt.setAdmin(admin, true);
    }

    function test_sbt_setAdmin_success() public {
        _changePrank(owner);
        sbt.setAdmin(user, true);
        assertTrue(sbt.getAdmin(user));
    }
}
