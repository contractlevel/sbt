// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @notice mock contract that implements ERC1271 to test smart contract signatures and ERC721Receiver to receive the SBT
contract MockERC1271 is IERC1271, IERC721Receiver {
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;
    bytes4 internal constant ERC721_RECEIVER_MAGIC = 0x150b7a02;
    bool public shouldReturnValid;

    constructor(bool _shouldReturnValid) {
        shouldReturnValid = _shouldReturnValid;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        if (shouldReturnValid) return MAGIC_VALUE;
        return 0xffffffff;
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return ERC721_RECEIVER_MAGIC;
    }
}

contract VerifySignatureTest is BaseTest {
    MockERC1271 internal validContract;
    MockERC1271 internal invalidContract;

    function setUp() public virtual override {
        super.setUp();
        validContract = new MockERC1271(true);
        invalidContract = new MockERC1271(false);
    }

    function test_verifySignature_EOA_success() public {
        // Create a message hash
        bytes32 messageHash = keccak256(abi.encodePacked(sbt.getTermsHash(), user));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Sign the message with the user's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Change to user context and verify signature
        _changePrank(user);
        assertTrue(sbt.mintWithTerms(signature) > 0);
    }

    function test_verifySignature_EOA_failure() public {
        // Create a message hash
        bytes32 messageHash = keccak256(abi.encodePacked(sbt.getTermsHash(), user));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Sign the message with a different private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user2Pk, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Change to user context and verify signature
        _changePrank(user);
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(signature);
    }

    function test_verifySignature_ERC1271_success() public {
        // Create a message hash
        bytes32 messageHash = keccak256(abi.encodePacked(sbt.getTermsHash(), address(validContract)));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Create a dummy signature (since the contract will validate it internally)
        bytes memory signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        // Change to contract context and verify signature
        _changePrank(address(validContract));
        assertTrue(sbt.mintWithTerms(signature) > 0);
    }

    function test_verifySignature_ERC1271_failure() public {
        // Create a message hash
        bytes32 messageHash = keccak256(abi.encodePacked(sbt.getTermsHash(), address(invalidContract)));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Create a dummy signature (since the contract will validate it internally)
        bytes memory signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        // Change to contract context and verify signature
        _changePrank(address(invalidContract));
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(signature);
    }

    function test_verifySignature_ERC1271_invalidContract() public {
        // Create a message hash
        bytes32 messageHash = keccak256(abi.encodePacked(sbt.getTermsHash(), address(this)));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        // Create a dummy signature
        bytes memory signature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        // Change to contract context and verify signature
        _changePrank(address(this));
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__InvalidSignature()"));
        sbt.mintWithTerms(signature);
    }
}
