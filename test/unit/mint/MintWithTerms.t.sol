// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseTest} from "../../BaseTest.t.sol";

contract MintWithTermsTest is BaseTest {
    function test_sbt_mintWithTerms_revertsWhen_whitelistEnabled() public {
        _changePrank(user);
        bytes memory signature = _createSignature(user, userPk, sbt.getTermsHash());
        uint256 fee = sbt.getFee();
        vm.expectRevert(abi.encodeWithSignature("SoulBoundToken__WhitelistEnabled()"));
        sbt.mintWithTerms{value: fee}(signature);
    }
}
