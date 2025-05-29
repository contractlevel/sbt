// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest, Vm} from "../../BaseTest.t.sol";

contract MintWithTermsTest is BaseTest {
    function test_sbt_mintWithTerms_revertsWhen_paused() public {
        bytes memory signature = _createSignature(user, userPk, sbt.getTermsHash());

        _changePrank(admin);
        sbt.pause();

        _changePrank(user);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        sbt.mintWithTerms(signature);
    }

    function test_sbt_mintWithTerms_revertsWhen_blacklisted() public {
        bytes memory signature = _createSignature(user, userPk, sbt.getTermsHash());

        _changePrank(blacklisted);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__Blacklisted(address)", blacklisted));
        sbt.mintWithTerms(signature);
    }

    function test_sbt_mintWithTerms_revertsWhen_insufficientFee() public {
        uint256 fee = _setFeeFactorAndDealFee(1e18, user);

        bytes memory signature = _createSignature(user, userPk, sbt.getTermsHash());

        _changePrank(user);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InsufficientFee()"));
        sbt.mintWithTerms{value: fee - 1}(signature);
    }

    function test_sbt_mintWithTerms_revertsWhen_alreadyMinted() public {
        _whitelistEnabled(false);
        bytes memory signature = _createSignature(user, userPk, sbt.getTermsHash());

        _changePrank(user);
        sbt.mintWithTerms(signature);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__AlreadyMinted(address)", user));
        sbt.mintWithTerms(signature);
    }

    function test_sbt_mintWithTerms_revertsWhen_invalidSignature() public {
        _whitelistEnabled(false);

        _changePrank(user);
        bytes memory invalidSigner = _createSignature(user2, userPk, sbt.getTermsHash());
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(invalidSigner);

        bytes memory invalidPk = _createSignature(user, user2Pk, sbt.getTermsHash());
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(invalidPk);

        bytes memory invalidTerms = _createSignature(user, user2Pk, keccak256(abi.encodePacked("test")));
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(invalidTerms);
    }

    function test_sbt_mintWithTerms_success() public {
        uint256 fee = _setFeeFactorAndDealFee(1e18, user);

        _whitelistEnabled(false);
        bytes32 termsHash = sbt.getTermsHash();
        bytes memory signature = _createSignature(user, userPk, termsHash);

        _changePrank(admin);
        sbt.pause();
        sbt.unpause();

        vm.recordLogs();

        _changePrank(user);
        uint256 tokenId = sbt.mintWithTerms{value: fee}(signature);

        assertEq(sbt.ownerOf(tokenId), user, "User should own token");
        assertEq(sbt.balanceOf(user), 1, "User should have 1 token");
        assertEq(tokenId, 1, "Token ID should be 1");
        assertEq(address(sbt).balance, fee, "Contract should hold fee");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 signatureVerifiedEventSignature = keccak256("SignatureVerified(address,bytes)");
        bytes32 feeCollectedEventSignature = keccak256("FeeCollected(address,uint256,uint256)");
        bool signatureVerifiedFound = false;
        bool feeCollectedFound = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == signatureVerifiedEventSignature) {
                address sigVerifiedEmittedAccount = address(uint160(uint256(logs[i].topics[1])));
                bytes memory sigVerifiedEmittedSig = abi.decode(logs[i].data, (bytes));
                assertEq(sigVerifiedEmittedAccount, user, "SignatureVerified: Incorrect user");
                assertEq(sigVerifiedEmittedSig, signature, "SignatureVerified: Incorrect signature");
                signatureVerifiedFound = true;
            } else if (logs[i].topics[0] == feeCollectedEventSignature) {
                address emittedUser = address(uint160(uint256(logs[i].topics[1])));
                (uint256 emittedAmount, uint256 emittedTokenId) = abi.decode(logs[i].data, (uint256, uint256));
                assertEq(emittedUser, user, "FeeCollected: Incorrect user");
                assertEq(emittedAmount, fee, "FeeCollected: Incorrect amount");
                assertEq(emittedTokenId, tokenId, "FeeCollected: Incorrect tokenId");
                feeCollectedFound = true;
            }
        }

        assertTrue(signatureVerifiedFound, "SignatureVerified event not emitted");
        assertTrue(feeCollectedFound, "FeeCollected event not emitted");
    }
}
