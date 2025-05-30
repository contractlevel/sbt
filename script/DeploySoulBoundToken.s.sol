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
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();

        vm.startBroadcast();
        SoulBoundToken sbt = new SoulBoundToken(
            networkConfig.name,
            networkConfig.symbol,
            networkConfig.contractURI,
            networkConfig.whitelistEnabled,
            networkConfig.nativeUsdFeed,
            networkConfig.owner,
            networkConfig.admins,
            networkConfig.priceFeedStalenessThreshold,
            networkConfig.sequencerUptimeFeed
        );
        vm.stopBroadcast();
        return (sbt, config);
    }
}
