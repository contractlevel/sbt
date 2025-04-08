// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../BaseTest.t.sol";

contract SetBaseURITest is BaseTest {
    function test_sbt_setBaseURI_revertsWhen_notOwner() public {
        _changePrank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        sbt.setBaseURI("test");
    }

    function test_sbt_setBaseURI_success() public {
        _changePrank(owner);
        sbt.setBaseURI("test");
        assertEq(sbt.getBaseURI(), "test");
    }
}
