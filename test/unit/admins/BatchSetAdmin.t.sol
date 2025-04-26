// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract BatchSetAdminTest is BaseTest {
    function test_sbt_batchSetAdmin_revertsWhen_notOwner() public {
        accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        sbt.batchSetAdmin(accounts, true);
    }

    function test_sbt_batchSetAdmin_revertsWhen_adminStatusAlreadySet() public {
        assertTrue(sbt.getAdmin(admin));
        accounts = new address[](1);
        accounts[0] = admin;
        _changePrank(owner);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AdminStatusAlreadySet(address,bool)", admin, true));
        sbt.batchSetAdmin(accounts, true);
    }

    function test_sbt_batchSetAdmin_revertsWhen_emptyArray() public {
        _changePrank(owner);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchSetAdmin(new address[](0), true);
    }

    function test_sbt_batchSetAdmin_success() public {
        accounts = new address[](1);
        accounts[0] = user;
        _changePrank(owner);
        sbt.batchSetAdmin(accounts, true);
        assertTrue(sbt.getAdmin(user));
    }
}
