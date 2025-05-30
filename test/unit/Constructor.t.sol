// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../BaseTest.t.sol";

contract ConstructorTest is BaseTest {
    function test_sbt_constructor() public view {
        assertEq(name, sbt.name());
        assertEq(symbol, sbt.symbol());
        assertEq(contractURI, sbt.contractURI());
        assertEq(whitelistEnabled, sbt.getWhitelistEnabled());
        assertEq(sbt.getTokenIdCounter(), 1);
        assertEq(sbt.owner(), owner);
        assertEq(nativeUsdFeed, sbt.getNativeUsdFeed());
        assertEq(true, sbt.getAdmin(initialAdmins[0]));
    }
}
