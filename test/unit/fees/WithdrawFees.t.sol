// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract WithdrawFeesTest is BaseTest {
    function test_sbt_withdrawFees_revertsWhen_notOwner() public {
        _changePrank(notOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", notOwner));
        sbt.withdrawFees(1);
    }

    function test_sbt_withdrawFees_revertsWhen_zeroAmount() public {
        _changePrank(owner);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NoZeroValue()"));
        sbt.withdrawFees(0);
    }

    function test_sbt_withdrawFees_revertsWhen_insufficientBalance() public {
        _changePrank(owner);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InsufficientBalance()"));
        sbt.withdrawFees(1);
    }

    function test_sbt_withdrawFees_revertsWhen_withdrawalFailed() public {
        deal(address(sbt), 1e18);

        _changePrank(owner);
        RejectEth rejectEth = new RejectEth();
        sbt.transferOwnership(address(rejectEth));
        _changePrank(address(rejectEth));
        sbt.acceptOwnership();

        _changePrank(address(rejectEth));
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__WithdrawFailed()"));
        sbt.withdrawFees(1);
    }

    function test_sbt_withdrawFees_success() public {
        /// @dev arrange
        uint256 accumulatedFees = 1e18;
        deal(address(sbt), accumulatedFees);

        uint256 ownerInitialBalance = owner.balance;
        uint256 contractInitialBalance = address(sbt).balance;
        vm.recordLogs();

        /// @dev act
        _changePrank(owner);
        sbt.withdrawFees(accumulatedFees);

        /// @dev assert
        assertEq(owner.balance, ownerInitialBalance + accumulatedFees, "Owner should receive fees");
        assertEq(
            address(sbt).balance, contractInitialBalance - accumulatedFees, "Contract should have no remaining balance"
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 feesWithdrawnEventSignature = keccak256("FeesWithdrawn(uint256)");
        bool feesWithdrawnFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == feesWithdrawnEventSignature) {
                uint256 emittedAmount = abi.decode(logs[i].data, (uint256));
                assertEq(emittedAmount, accumulatedFees, "FeesWithdrawn: Incorrect amount");
                feesWithdrawnFound = true;
                break;
            }
        }
        assertTrue(feesWithdrawnFound, "FeesWithdrawn event not emitted");
    }
}

contract RejectEth {
    error RejectEth__Revert();

    receive() external payable {
        revert RejectEth__Revert();
    }
}
