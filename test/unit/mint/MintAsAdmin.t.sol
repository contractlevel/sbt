// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract MintAsAdminTest is BaseTest {
    function test_sbt_mintAsAdmin_revertsWhen_notAdmin() public {
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.mintAsAdmin(notAdmin);
    }

    function test_sbt_mintAsAdmin_revertsWhen_blacklisted() public {
        _whitelistEnabled(false);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.mintAsAdmin(blacklisted);
    }

    function test_sbt_mintAsAdmin_revertsWhen_alreadyMinted() public {
        sbt.mintAsAdmin(whitelisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AlreadyMinted(address)", whitelisted));
        sbt.mintAsAdmin(whitelisted);
    }

    function test_sbt_mintAsAdmin_success() public {
        uint256 tokenId = sbt.getTokenIdCounter();
        sbt.mintAsAdmin(whitelisted);
        assertEq(sbt.ownerOf(tokenId), whitelisted);
    }
}
