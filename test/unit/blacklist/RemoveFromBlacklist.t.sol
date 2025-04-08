// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract RemoveFromBlacklistTest is BaseTest {
    function test_sbt_removeFromBlacklist_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.removeFromBlacklist(blacklisted);
    }

    function test_sbt_removeFromBlacklist_revertsWhen_notBlacklisted() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotBlacklisted(address)", notBlacklisted));
        sbt.removeFromBlacklist(notBlacklisted);
    }

    function test_sbt_removeFromBlacklist_success() public {
        _blacklist(user);
        vm.recordLogs();

        sbt.removeFromBlacklist(user);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("RemovedFromBlacklist(address)");
        address emittedAccount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }
        assertEq(emittedAccount, user);
        assertFalse(sbt.getBlacklisted(user));
    }
}
