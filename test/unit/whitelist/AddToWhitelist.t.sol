// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract AddToWhiteListTest is BaseTest {
    function setUp() public override {
        BaseTest.setUp();
        _changePrank(admin);
    }

    function test_sbt_addToWhitelist_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.addToWhitelist(notAdmin);
    }

    function test_sbt_addToWhitelist_revertsWhen_zeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NoZeroAddress()"));
        sbt.addToWhitelist(address(0));
    }

    function test_sbt_addToWhitelist_revertsWhen_alreadyWhitelisted() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Whitelisted(address)", whitelisted));
        sbt.addToWhitelist(whitelisted);
    }

    function test_sbt_addToWhitelist_revertsWhen_blacklisted() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.addToWhitelist(blacklisted);
    }

    function test_sbt_addToWhitelist_success() public {
        vm.recordLogs();

        sbt.addToWhitelist(user);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("AddedToWhitelist(address)");
        address emittedAccount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }

        assertTrue(sbt.getWhitelisted(user));
        assertEq(emittedAccount, user);
    }
}
