// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SoulBoundToken} from "../src/SoulBoundToken.sol";

contract DeploySoulBoundToken is Script {
    /*//////////////////////////////////////////////////////////////
                                  RUN
    //////////////////////////////////////////////////////////////*/
    function run() public returns (SoulBoundToken, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (
            string memory name,
            string memory symbol,
            string memory contractURI,
            bool whitelistEnabled,
            address nativeUsdFeed
        ) = config.activeNetworkConfig();

        vm.startBroadcast();
        SoulBoundToken sbt = new SoulBoundToken(name, symbol, contractURI, whitelistEnabled, nativeUsdFeed);
        vm.stopBroadcast();
        return (sbt, config);
    }
}
