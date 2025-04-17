// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract BatchRemoveFromWhitelistTest is BaseTest {
    function test_sbt_batchRemoveFromWhitelist_revertsWhen_notAdmin() public {
        accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.batchRemoveFromWhitelist(accounts);
    }

    function test_sbt_batchRemoveFromWhitelist_revertsWhen_notWhitelisted() public {
        accounts = new address[](1);
        accounts[0] = notWhitelisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotWhitelisted(address)", notWhitelisted));
        sbt.batchRemoveFromWhitelist(accounts);
    }

    function test_sbt_batchRemoveFromWhitelist_revertsWhen_emptyArray() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchRemoveFromWhitelist(new address[](0));
    }

    function test_sbt_batchRemoveFromWhitelist_success() public {
        accounts = new address[](2);
        accounts[0] = user;
        accounts[1] = user2;

        _whitelist(user);
        _whitelist(user2);

        vm.recordLogs();

        sbt.batchRemoveFromWhitelist(accounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("RemovedFromWhitelist(address)");
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
        assertFalse(sbt.getWhitelisted(user));
        assertFalse(sbt.getWhitelisted(user2));
    }
}
