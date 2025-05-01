// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint8 constant DECIMALS = 8;
    int256 constant INITIAL_ANSWER = 2000 * 1e8; // $2000/ETH

    /*//////////////////////////////////////////////////////////////
                             NETWORK CONFIG
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        string name;
        string symbol;
        string baseURI;
        bool whitelistEnabled;
        address nativeUsdFeed;
    }

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        if (block.chainid == 10) activeNetworkConfig = getOptimismConfig();
        else activeNetworkConfig = getOrCreateAnvilEthConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getOptimismConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            name: "Evo Labs SoulBoundToken", // review format
            symbol: "EVO",
            baseURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: 0xb7B9A39CC63f856b90B364911CC324dC46aC1770 // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&network=optimism&search=eth
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);

        return NetworkConfig({
            name: "Evo Labs SoulBoundToken", // review format
            symbol: "EVO",
            baseURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: address(mockPriceFeed)
        });
    }
}
