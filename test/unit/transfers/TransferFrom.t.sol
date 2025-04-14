// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract TransferFromTest is BaseTest {
    function test_sbt_transferFrom_reverts() public {
        _changePrank(admin);
        sbt.mintAsAdmin(whitelisted);
        _changePrank(whitelisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__TransferNotAllowed()"));
        sbt.transferFrom(whitelisted, user, 1);
    }
}
