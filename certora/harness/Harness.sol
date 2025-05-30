// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SoulBoundToken, ECDSA, MessageHashUtils, SignatureChecker} from "../../src/SoulBoundToken.sol";

contract Harness is SoulBoundToken {
    constructor(
        string memory name,
        string memory symbol,
        string memory contractURI,
        bool whitelistEnabled,
        address nativeUsdFeed,
        address owner,
        address[] memory admins
    ) SoulBoundToken(name, symbol, contractURI, whitelistEnabled, nativeUsdFeed, owner, admins) {}

    function bytes32ToBool(bytes32 value) public pure returns (bool) {
        return value != bytes32(0);
    }

    function getVerifiedSignature(bytes memory signature) public returns (bool) {
        return _verifySignature(signature);
    }

    function getSignerSignature(address signer, bytes memory signature) public returns (bool) {
        bytes32 messageHash = keccak256(abi.encodePacked(s_termsHash, signer));

        /// @dev apply Ethereum signed message prefix
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        /// @dev attempt to recover the signer
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(ethSignedMessageHash, signature);

        /// @dev if the signer is an EOA, return true if the signature is valid
        if (error == ECDSA.RecoverError.NoError && recovered == signer) return true;
        /// @dev else check if the signature is valid for a smart contract
        else return SignatureChecker.isValidERC1271SignatureNow(signer, ethSignedMessageHash, signature);
    }

    function keccakHash(string memory input) public returns (bytes32) {
        return keccak256(abi.encodePacked(input));
    }
}
