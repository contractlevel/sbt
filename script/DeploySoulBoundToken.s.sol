// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {SoulBoundToken} from "../src/SoulBoundToken.sol";

contract DeploySoulBoundToken is Script {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    string constant NAME = "name";
    string constant SYMBOL = "symbol";
    string constant BASE_URI = "";
    bool constant WHITELIST_ENABLED = true;

    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/
    function run() public returns (SoulBoundToken) {
        vm.startBroadcast();
        SoulBoundToken sbt = new SoulBoundToken(NAME, SYMBOL, BASE_URI, WHITELIST_ENABLED);
        vm.stopBroadcast();
        return sbt;
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getDeployArgs() external pure returns (string memory, string memory, string memory, bool) {
        return (NAME, SYMBOL, BASE_URI, WHITELIST_ENABLED);
    }
}
