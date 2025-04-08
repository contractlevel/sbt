// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract ApproveTest is BaseTest {
    function test_sbt_approve_reverts() public {
        _changePrank(user);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__ApprovalNotAllowed()"));
        sbt.approve(user, 0);
    }
}
