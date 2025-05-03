// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SoulBoundToken, ECDSA, MessageHashUtils} from "../../src/SoulBoundToken.sol";

contract Harness is SoulBoundToken {
    constructor(string memory name, string memory symbol, string memory baseURI, bool whitelistEnabled, address nativeUsdFeed)
        SoulBoundToken(name, symbol, baseURI, whitelistEnabled, nativeUsdFeed)
    {}
    
    function bytes32ToBool(bytes32 value) public pure returns (bool) {
        return value != bytes32(0);
    }

    function getVerifiedSignature(bytes memory signature) public returns (bool) {
        return _verifySignature(signature);
    }
}
