// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract SafeTransferFromTest is BaseTest {
    function test_sbt_safeTransferFrom_reverts() public {
        _changePrank(admin);
        sbt.mintAsAdmin(whitelisted);
        _changePrank(whitelisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__TransferNotAllowed()"));
        sbt.safeTransferFrom(whitelisted, user, 1);
    }
}
