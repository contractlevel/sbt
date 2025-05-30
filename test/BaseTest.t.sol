// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {DeploySoulBoundToken, SoulBoundToken, HelperConfig} from "../script/DeploySoulBoundToken.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BaseTest is Test {
    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    string internal constant OPTIMISM_MAINNET_RPC_URL = "https://mainnet.optimism.io";
    uint256 internal constant OPTIMISM_MAINNET_STARTING_BLOCK = 136507334;
    uint256 internal optimismFork;

    SoulBoundToken internal sbt;
    HelperConfig internal config;
    string internal name;
    string internal symbol;
    string internal contractURI;
    bool internal whitelistEnabled;
    address internal nativeUsdFeed;

    address internal owner;
    address internal admin = makeAddr("admin");
    address internal notOwner = makeAddr("notOwner");
    address internal notAdmin = makeAddr("notAdmin");
    address internal notWhitelisted = makeAddr("notWhitelisted");
    address internal notBlacklisted = makeAddr("notBlacklisted");
    address internal blacklisted = makeAddr("blacklisted");
    address internal whitelisted = makeAddr("whitelisted");
    address internal user;
    uint256 internal userPk;
    address internal user2;
    uint256 internal user2Pk;
    address[] internal accounts;
    address[] internal initialAdmins;

    /*//////////////////////////////////////////////////////////////
                                 SET UP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        (user, userPk) = makeAddrAndKey("user");
        (user2, user2Pk) = makeAddrAndKey("user2");

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
        (sbt, config) = deploy.run();

        /// @dev fetch args passed in constructor by deploy script
        HelperConfig.NetworkConfig memory networkConfig = config.getActiveNetworkConfig();
        name = networkConfig.name;
        symbol = networkConfig.symbol;
        contractURI = networkConfig.contractURI;
        whitelistEnabled = networkConfig.whitelistEnabled;
        nativeUsdFeed = networkConfig.nativeUsdFeed;
        owner = networkConfig.owner;
        initialAdmins = networkConfig.admins;
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

    function _createSignature(address signer, uint256 signerKey, bytes32 termsHash)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(termsHash, signer));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function _setFeeFactorAndDealFee(uint256 feeFactor, address dealTo) internal returns (uint256 fee) {
        _changePrank(admin);
        sbt.setFeeFactor(feeFactor);
        fee = sbt.getFee();
        deal(dealTo, fee);
    }
}
