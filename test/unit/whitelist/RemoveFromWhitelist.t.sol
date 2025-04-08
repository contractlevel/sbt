// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract RemoveFromWhitelistTest is BaseTest {
    function test_sbt_removeFromWhitelist_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.removeFromWhitelist(whitelisted);
    }

    function test_sbt_removeFromWhitelist_revertsWhen_notWhitelisted() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotWhitelisted(address)", notWhitelisted));
        sbt.removeFromWhitelist(notWhitelisted);
    }

    function test_sbt_removeFromWhitelist_success() public {
        _whitelist(user);
        vm.recordLogs();

        sbt.removeFromWhitelist(user);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 eventSignature = keccak256("RemovedFromWhitelist(address)");
        address emittedAccount;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == eventSignature) {
                emittedAccount = address(uint160(uint256(logs[i].topics[1])));
                break;
            }
        }
        assertEq(emittedAccount, user);
        assertFalse(sbt.getWhitelisted(user));
    }
}
