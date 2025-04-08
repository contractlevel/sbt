// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract AddToBlacklistTest is BaseTest {
    function test_sbt_addToBlacklist_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.addToBlacklist(notAdmin);
    }

    function test_sbt_addToBlacklist_revertsWhen_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NoZeroAddress()"));
        sbt.addToBlacklist(address(0));
    }

    function test_sbt_addToBlacklist_revertsWhen_alreadyBlacklisted() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.addToBlacklist(blacklisted);
    }

    function test_sbt_addToBlacklist_removesFromWhitelist() public {
        assertTrue(sbt.getWhitelisted(whitelisted));
        sbt.addToBlacklist(whitelisted);
        assertFalse(sbt.getWhitelisted(whitelisted));
    }

    function test_sbt_addToBlacklist_success() public {
        vm.recordLogs();

        sbt.addToBlacklist(user);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("AddedToBlacklist(address)");
        address emittedAccount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        assertTrue(sbt.getBlacklisted(user));
        assertEq(emittedAccount, user);
    }

    function test_sbt_addToBlacklist_burnsToken() public {
        _whitelist(user);
        sbt.mintAsAdmin(user);
        assertEq(sbt.balanceOf(user), 1);
        sbt.addToBlacklist(user);
        assertEq(sbt.balanceOf(user), 0);
    }
}
