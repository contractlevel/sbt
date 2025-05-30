// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/shared/mocks/MockV3Aggregator.sol";

contract MockAggregatorV3 is MockV3Aggregator {
    address internal immutable i_aggregator;

    constructor(uint8 _decimals, int256 _initialAnswer, address aggregator)
        MockV3Aggregator(_decimals, _initialAnswer)
    {
        i_aggregator = aggregator;
    }

    function aggregator() external view returns (address) {
        return i_aggregator;
    }
}
