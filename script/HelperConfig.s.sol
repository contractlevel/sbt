// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                             NETWORK CONFIG
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        string name;
        string symbol;
        string contractURI;
        bool whitelistEnabled;
        address nativeUsdFeed;
        address owner;
        address[] admins;
    }

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        if (block.chainid == 10) activeNetworkConfig = getOptimismConfig();
        if (block.chainid == 11155111) activeNetworkConfig = getEthSepoliaConfig();
        else activeNetworkConfig = getOrCreateAnvilEthConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getOptimismConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C/", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: 0xb7B9A39CC63f856b90B364911CC324dC46aC1770, // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&network=optimism&search=eth
            owner: address(1), // dummy value, replace in production
            admins: _createAdminsArray() // dummy value, replace in production
        });
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C/", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            owner: address(1), // dummy value, replace in production
            admins: _createAdminsArray() // dummy value, replace in production
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        uint8 decimals = 8;
        int256 initialAnswer = 2000 * 1e8; // $2000/ETH
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(decimals, initialAnswer);

        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C/", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: address(mockPriceFeed),
            owner: address(1), // dummy value, replace in production
            admins: _createAdminsArray() // dummy value, replace in production
        });
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _createAdminsArray() internal pure returns (address[] memory) {
        address[] memory admins = new address[](1);
        admins[0] = address(2); // dummy value, replace in production
        return admins;
    }
}
