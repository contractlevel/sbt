// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockAggregatorV3} from "../test/mocks/MockAggregatorV3.sol";
import {MockAggregator} from "../test/mocks/MockAggregator.sol";

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
        uint256 priceFeedStalenessThreshold;
        address sequencerUptimeFeed;
    }

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() {
        if (block.chainid == 10) activeNetworkConfig = getOptimismConfig();
        else if (block.chainid == 11155111) activeNetworkConfig = getEthSepoliaConfig();
        else activeNetworkConfig = getOrCreateAnvilEthConfig();
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTER
    //////////////////////////////////////////////////////////////*/
    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    function getOptimismConfig() public pure returns (NetworkConfig memory) {
        address[] memory optimismAdmins = new address[](3);
        optimismAdmins[0] = 0xfaCd87e98C1bdcd9F33cDD494586926F540FeC89;
        optimismAdmins[1] = 0x5684db5DAb7EA39A256ede0445636aC00e9B299e;
        optimismAdmins[2] = 0x32E49679281941534fe466b97A28165D23B1fFA9;

        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "https://docs.fileverse.io/0x3EF27DC9A11807322A370021F7C5A3f51Ee1B2CE/4#key=YwuKpn6EyGSqmycYTgi6j1ZZTSXuSfLWVU7bdgH9uX31oPTdaoqjvmCDxi-PTZLY",
            whitelistEnabled: true,
            nativeUsdFeed: 0xb7B9A39CC63f856b90B364911CC324dC46aC1770, // https://docs.chain.link/data-feeds/price-feeds/addresses?page=1&network=optimism&search=eth
            owner: 0xc8654eAF0313Fa702c52000BCf2e38B3339C90B5,
            admins: optimismAdmins,
            priceFeedStalenessThreshold: 1200 seconds, // https://docs.chain.link/data-feeds/price-feeds/addresses/?network=optimism&page=1&testnetPage=1&search=eth%2Fusd#data-feed-best-practices
            sequencerUptimeFeed: 0x371EAD81c9102C9BF4874A9075FFFf170F2Ee389 // https://docs.chain.link/data-feeds/l2-sequencer-feeds#op
        });
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "https://docs.fileverse.io/0x3EF27DC9A11807322A370021F7C5A3f51Ee1B2CE/4#key=YwuKpn6EyGSqmycYTgi6j1ZZTSXuSfLWVU7bdgH9uX31oPTdaoqjvmCDxi-PTZLY",
            whitelistEnabled: true,
            nativeUsdFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            owner: 0xc8654eAF0313Fa702c52000BCf2e38B3339C90B5,
            admins: optimismAdmins,
            priceFeedStalenessThreshold: 3600 seconds, // https://docs.chain.link/data-feeds/price-feeds/addresses/?network=ethereum&page=1&testnetPage=1&testnetSearch=eth%2Fusd#sepolia-testnet
            sequencerUptimeFeed: address(0) // @review
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        uint8 decimals = 8;
        // the answer returned by mockPriceFeed will be the price of ETH in USD
        int256 initialAnswer = 2000 * 1e8; // $2000/ETH
        MockAggregator mockAggregator = new MockAggregator();
        MockAggregatorV3 mockPriceFeed = new MockAggregatorV3(decimals, initialAnswer, address(mockAggregator));
        // the answer returned by mockSequencerFeed will be the uptime of the sequencer, ie 0 or 1
        int256 initialUptimeAnswer = 0;
        MockAggregatorV3 mockSequencerFeed = new MockAggregatorV3(decimals, initialUptimeAnswer, address(0));

        return NetworkConfig({
            name: "Evo Labs DAO Membership",
            symbol: "EVO",
            contractURI: "ipfs://QmfKN2Cq3HSNXVr36MXHdRMvH2PDrby3y1cH1aRFbTkf4C/", // dummy value, replace in production
            whitelistEnabled: true,
            nativeUsdFeed: address(mockPriceFeed),
            owner: address(1), // dummy value, replace in production
            admins: _createAdminsArray(), // dummy value, replace in production
            priceFeedStalenessThreshold: 3600 seconds, // @review
            sequencerUptimeFeed: address(mockSequencerFeed)
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
