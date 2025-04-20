// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract BatchAddToBlacklistTest is BaseTest {
    function test_sbt_batchAddToBlacklist_revertsWhen_notAdmin() public {
        accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.batchAddToBlacklist(accounts);
    }

    function test_sbt_batchAddToBlacklist_revertsWhen_zeroAddress() public {
        accounts = new address[](1);
        accounts[0] = address(0);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NoZeroAddress()"));
        sbt.batchAddToBlacklist(accounts);
    }

    function test_sbt_batchAddToBlacklist_revertsWhen_alreadyBlacklisted() public {
        accounts = new address[](1);
        accounts[0] = blacklisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.batchAddToBlacklist(accounts);
    }

    function test_sbt_batchAddToBlacklist_removesFromWhitelist() public {
        accounts = new address[](1);
        accounts[0] = whitelisted;
        assertTrue(sbt.getWhitelisted(whitelisted));

        sbt.batchAddToBlacklist(accounts);

        assertFalse(sbt.getWhitelisted(whitelisted));
    }

    function test_sbt_batchAddToBlacklist_success() public {
        accounts = new address[](2);
        accounts[0] = user;
        accounts[1] = user2;

        vm.recordLogs();

        sbt.batchAddToBlacklist(accounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("AddedToBlacklist(address)");
        uint256 eventCount;
        address emittedAccount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                eventCount++;
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
        assertTrue(sbt.getBlacklisted(user));
        assertTrue(sbt.getBlacklisted(user2));
    }

    function test_sbt_batchAddToBlacklist_revertsWhen_emptyArray() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchAddToBlacklist(new address[](0));
    }

    function test_sbt_batchAddToBlacklist_burnsTokens() public {
        _whitelist(user);
        sbt.mintAsAdmin(user);
        assertEq(sbt.balanceOf(user), 1);
        accounts = new address[](1);
        accounts[0] = user;
        sbt.batchAddToBlacklist(accounts);
        assertEq(sbt.balanceOf(user), 0);
    }
}
