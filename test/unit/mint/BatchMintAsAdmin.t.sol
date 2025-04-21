// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract BatchMintAsAdminTest is BaseTest {
    function test_sbt_batchMintAsAdmin_revertsWhen_notAdmin() public {
        address[] memory accounts = new address[](1);
        accounts[0] = notAdmin;
        _changePrank(notAdmin);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__OnlyAdmin(address)", notAdmin));
        sbt.batchMintAsAdmin(accounts);
    }

    function test_sbt_batchMintAsAdmin_revertsWhen_notWhitelisted() public {
        address[] memory accounts = new address[](1);
        accounts[0] = notWhitelisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__NotWhitelisted(address)", notWhitelisted));
        sbt.batchMintAsAdmin(accounts);
    }

    function test_sbt_batchMintAsAdmin_revertsWhen_blacklisted() public {
        _whitelistEnabled(false);
        address[] memory accounts = new address[](1);
        accounts[0] = blacklisted;
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.batchMintAsAdmin(accounts);
    }

    function test_sbt_batchMintAsAdmin_revertsWhen_alreadyMinted() public {
        address[] memory accounts = new address[](1);
        accounts[0] = whitelisted;
        sbt.batchMintAsAdmin(accounts);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AlreadyMinted(address)", whitelisted));
        sbt.batchMintAsAdmin(accounts);
    }

    function test_sbt_batchMintAsAdmin_revertsWhen_emptyArray() public {
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__EmptyArray()"));
        sbt.batchMintAsAdmin(new address[](0));
    }

    function test_sbt_batchMintAsAdmin_success() public {
        address[] memory accounts = new address[](1);
        accounts[0] = whitelisted;
        uint256 tokenId = sbt.getTokenIdCounter();
        uint256[] memory tokenIds = sbt.batchMintAsAdmin(accounts);
        assertEq(tokenIds.length, accounts.length);
        assertEq(tokenIds[0], tokenId);
        assertEq(sbt.ownerOf(tokenId), whitelisted);
    }

    function test_sbt_batchMintAsAdmin_success_multiple() public {
        address[] memory accounts = new address[](2);
        accounts[0] = whitelisted;
        accounts[1] = user;
        sbt.addToWhitelist(user);

        uint256 startId = sbt.getTokenIdCounter();

        uint256[] memory tokenIds = sbt.batchMintAsAdmin(accounts);

        uint256 endId = sbt.getTokenIdCounter();

        assertEq(tokenIds.length, accounts.length);
        assertEq(tokenIds[0], startId);
        assertEq(sbt.ownerOf(tokenIds[0]), whitelisted);
        assertEq(sbt.ownerOf(tokenIds[1]), user);
        assertEq(endId, startId + 2); // startId = whitelisted, +1 = user, +2 = next ID
    }
}
