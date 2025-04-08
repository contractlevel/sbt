// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract SetApprovalForAllTest is BaseTest {
    function test_sbt_setApprovalForAll_reverts() public {
        _changePrank(user);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__ApprovalNotAllowed()"));
        sbt.setApprovalForAll(user, true);
    }
}
