// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {DeploySoulBoundToken, SoulBoundToken} from "../script/DeploySoulBoundToken.s.sol";

contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    string internal constant OPTIMISM_MAINNET_RPC_URL = "https://mainnet.optimism.io";
    uint256 internal constant OPTIMISM_MAINNET_STARTING_BLOCK = 134098035;
    uint256 internal optimismFork;

    SoulBoundToken internal sbt;
    string internal name;
    string internal symbol;
    string internal baseURI;
    bool internal whitelistEnabled;

    address internal owner = makeAddr("owner");
    address internal admin = makeAddr("admin");
    address internal notOwner = makeAddr("notOwner");
    address internal notAdmin = makeAddr("notAdmin");
    address internal notWhitelisted = makeAddr("notWhitelisted");
    address internal notBlacklisted = makeAddr("notBlacklisted");
    address internal blacklisted = makeAddr("blacklisted");
    address internal whitelisted = makeAddr("whitelisted");
    address internal user = makeAddr("user");
    address internal user2 = makeAddr("user2");
    address[] internal accounts;

    /*//////////////////////////////////////////////////////////////
                                 SET UP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        _forkOptimism();
        _deployInfra();

        /// @dev define actors
        _changePrank(owner);
        _assignAdmin(admin);
        _blacklist(blacklisted);
        _whitelist(whitelisted);
        _changePrank(admin);
    }

    /// @notice empty test to ignore file in coverage report
    function test_baseTest() public {}

    /*//////////////////////////////////////////////////////////////
                                 DEPLOY
    //////////////////////////////////////////////////////////////*/
    function _forkOptimism() internal {
        /// @dev fork Optimism mainnet
        optimismFork = vm.createSelectFork(OPTIMISM_MAINNET_RPC_URL, OPTIMISM_MAINNET_STARTING_BLOCK);
        /// @dev sanity check
        assertEq(block.chainid, 10);
    }

    function _deployInfra() internal {
        /// @dev run deploy script
        DeploySoulBoundToken deploy = new DeploySoulBoundToken();
        sbt = deploy.run();

        /// @dev fetch args passed in constructor by deploy script
        (name, symbol, baseURI, whitelistEnabled) = deploy.getDeployArgs();

        /// @dev store owner
        _changePrank(sbt.owner());
        sbt.transferOwnership(owner);
        _stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    function _changePrank(address newPrank) internal {
        vm.stopPrank();
        vm.startPrank(newPrank);
    }

    function _stopPrank() internal {
        vm.stopPrank();
    }

    function _blacklist(address account) internal {
        _changePrank(admin);
        sbt.addToBlacklist(account);
    }

    function _whitelist(address account) internal {
        _changePrank(admin);
        sbt.addToWhitelist(account);
    }

    function _assignAdmin(address account) internal {
        _changePrank(owner);
        sbt.setAdmin(account, true);
    }

    function _whitelistEnabled(bool isEnabled) internal {
        _changePrank(admin);
        sbt.setWhitelistEnabled(isEnabled);
    }
}
