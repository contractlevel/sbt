// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../BaseTest.t.sol";

contract SetContractURITest is BaseTest {
    function test_sbt_setContractURI_revertsWhen_notOwner() public {
        _changePrank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        sbt.setContractURI("test");
    }

    function test_sbt_setContractURI_success() public {
        _changePrank(owner);
        sbt.setContractURI("test");
        assertEq(sbt.getContractURI(), "test");
    }
}
