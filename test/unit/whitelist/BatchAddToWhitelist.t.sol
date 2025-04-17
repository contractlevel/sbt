// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract BatchAddToWhiteListTest is BaseTest {
    function test_sbt_batchAddToWhitelist_revertsWhen_notAdmin() public {
        accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.batchAddToWhitelist(accounts);
    }

    function test_sbt_batchAddToWhitelist_revertsWhen_zeroAddress() public {
        accounts = new address[](1);
        accounts[0] = address(0);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NoZeroAddress()"));
        sbt.batchAddToWhitelist(accounts);
    }

    function test_sbt_batchAddToWhitelist_revertsWhen_alreadyWhitelisted() public {
        accounts = new address[](1);
        accounts[0] = whitelisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Whitelisted(address)", whitelisted));
        sbt.batchAddToWhitelist(accounts);
    }

    function test_sbt_batchAddToWhitelist_revertsWhen_blacklisted() public {
        accounts = new address[](1);
        accounts[0] = blacklisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.batchAddToWhitelist(accounts);
    }

    function test_sbt_batchAddToWhitelist_revertsWhen_emptyArray() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchAddToWhitelist(new address[](0));
    }

    function test_sbt_batchAddToWhitelist_success() public {
        accounts = new address[](2);
        accounts[0] = user;
        accounts[1] = user2;

        vm.recordLogs();

        sbt.batchAddToWhitelist(accounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("AddedToWhitelist(address)");
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
        assertTrue(sbt.getWhitelisted(user));
        assertTrue(sbt.getWhitelisted(user2));
    }
}
