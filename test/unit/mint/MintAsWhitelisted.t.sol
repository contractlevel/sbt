// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

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

    function test_sbt_mintAsWhitelisted_revertsWhen_insufficientFee() public {
        uint256 fee = _setFeeFactorAndDealFee(1e18, whitelisted);

        _changePrank(whitelisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__IncorrectFee()"));
        sbt.mintAsWhitelisted{value: fee - 1}();
    }

    function test_sbt_mintAsWhitelisted_success() public {
        uint256 fee = _setFeeFactorAndDealFee(1e18, whitelisted);

        vm.recordLogs();

        _changePrank(whitelisted);
        uint256 tokenId = sbt.mintAsWhitelisted{value: fee}();

        assertEq(sbt.ownerOf(tokenId), whitelisted, "Whitelisted user should own token");
        assertEq(sbt.balanceOf(whitelisted), 1, "Whitelisted user should have 1 token");
        assertEq(address(sbt).balance, fee, "Contract should hold the fee");

        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 feeCollectedEventSignature = keccak256("FeeCollected(address,uint256,uint256)");
        bool feeCollectedFound = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == feeCollectedEventSignature) {
                address emittedUser = address(uint160(uint256(logs[i].topics[1])));
                (uint256 emittedAmount, uint256 emittedTokenId) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(emittedUser, whitelisted, "FeeCollected: Incorrect user");
                assertEq(emittedAmount, fee, "FeeCollected: Incorrect amount");
                assertEq(emittedTokenId, tokenId, "FeeCollected: Incorrect tokenId");
                feeCollectedFound = true;
                break;
            }
        }
        assertTrue(feeCollectedFound, "FeeCollected event not emitted");
    }
}
