// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract BatchRemoveFromBlacklistTest is BaseTest {
    function test_sbt_batchRemoveFromBlacklist_revertsWhen_notAdmin() public {
        accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.batchRemoveFromBlacklist(accounts);
    }

    function test_sbt_batchRemoveFromBlacklist_revertsWhen_notBlacklisted() public {
        accounts = new address[](1);
        accounts[0] = notBlacklisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotBlacklisted(address)", notBlacklisted));
        sbt.batchRemoveFromBlacklist(accounts);
    }

    function test_sbt_batchRemoveFromBlacklist_revertsWhen_emptyArray() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchRemoveFromBlacklist(new address[](0));
    }

    function test_sbt_batchRemoveFromBlacklist_success() public {
        accounts = new address[](2);
        accounts[0] = user;
        accounts[1] = user2;

        _blacklist(user);
        _blacklist(user2);

        vm.recordLogs();

        sbt.batchRemoveFromBlacklist(accounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("RemovedFromBlacklist(address)");
        uint256 eventCount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                eventCount++;
                address emittedAccount;
                if (eventCount == 1) {
                    emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                    assertEq(emittedAccount, user);
                } else if (eventCount == 2) {
                    emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                    assertEq(emittedAccount, user2);
                }
            }
        }

        assertEq(eventCount, accounts.length);
        assertFalse(sbt.getBlacklisted(user));
        assertFalse(sbt.getBlacklisted(user2));
    }
}
