// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {SoulBoundToken} from "../../src/SoulBoundToken.sol";

contract Harness is SoulBoundToken {
    constructor(string memory name, string memory symbol, string memory baseURI, bool whitelistEnabled)
        SoulBoundToken(name, symbol, baseURI, whitelistEnabled)
    {}
    
    function bytes32ToBool(bytes32 value) public pure returns (bool) {
        return value != bytes32(0);
    }
}
