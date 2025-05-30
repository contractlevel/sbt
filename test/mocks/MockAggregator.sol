// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAggregator} from "../../src/interfaces/IAggregator.sol";

contract MockAggregator is IAggregator {
    function maxAnswer() external pure returns (int192) {
        return 100000000000000;
    }

    function minAnswer() external pure returns (int192) {
        return 1000000000;
    }
}
