// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract MintAsWhitelistedTest is BaseTest {
    function test_sbt_mintAsWhitelisted_revertsWhen_notWhitelisted() public {
        _changePrank(notWhitelisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotWhitelisted(address)", notWhitelisted));
        sbt.mintAsWhitelisted();
    }

    function test_sbt_mintAsWhitelisted_revertsWhen_whitelistDisabled() public {
        _whitelistEnabled(false);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__WhitelistDisabled()"));
        sbt.mintAsWhitelisted();
    }

    function test_sbt_mintAsWhitelisted_revertsWhen_alreadyMinted() public {
        _changePrank(whitelisted);
        sbt.mintAsWhitelisted();
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AlreadyMinted(address)", whitelisted));
        sbt.mintAsWhitelisted();
    }

    function test_sbt_mintAsWhitelisted_success() public {
        uint256 tokenId = sbt.getTokenIdCounter();
        _changePrank(whitelisted);
        sbt.mintAsWhitelisted();
        assertEq(sbt.ownerOf(tokenId), whitelisted);
    }
}
