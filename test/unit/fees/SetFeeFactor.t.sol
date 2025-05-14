// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract SetFeesTest is BaseTest {
    function test_sbt_setFeeFactor_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.setFeeFactor(1);
    }

    function test_sbt_setFeeFactor_success() public {
        uint256 feeFactor = 1e18;

        vm.recordLogs();

        sbt.setFeeFactor(feeFactor);

        assertEq(feeFactor, sbt.getFeeFactor());

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 feeFactorSetEventSignature = keccak256("FeeFactorSet(uint256)");
        bool feeFactorSetFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == feeFactorSetEventSignature) {
                uint256 emittedFeeFactor = abi.decode(logs[i].data, (uint256));
                assertEq(emittedFeeFactor, feeFactor, "FeeFactorSet: Incorrect feeFactor");
                feeFactorSetFound = true;
            }
        }
        assertTrue(feeFactorSetFound, "FeeFactorSet event not emitted");
    }
}
