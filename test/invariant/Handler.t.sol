// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, Vm, console2, SoulBoundToken} from "../BaseTest.t.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Handler is Test {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev SBT contract
    SoulBoundToken internal sbt;
    /// @dev SBT owner
    address internal owner;

    /// @dev track the accounts in the system
    EnumerableSet.AddressSet internal accounts;
    /// @dev track the admins in the system
    EnumerableSet.AddressSet internal admins;
    /// @dev track the whitelisted in the system
    EnumerableSet.AddressSet internal whitelisted;
    /// @dev track the blacklisted in the system
    EnumerableSet.AddressSet internal blacklisted;
    /// @dev track the holders in the system
    EnumerableSet.AddressSet internal holders;

    enum Set {
        Accounts,
        Admins,
        Whitelisted,
        Blacklisted,
        Holders
    }

    /*//////////////////////////////////////////////////////////////
                                 GHOSTS
    //////////////////////////////////////////////////////////////*/
    /// @dev track the admins
    mapping(address account => bool isAdmin) public g_admins;
    /// @dev track the blacklisted accounts in the system
    mapping(address account => bool isBlacklisted) public g_blacklisted;
    /// @dev track the whitelisted accounts in the system
    mapping(address account => bool isWhitelisted) public g_whitelisted;

    /// @dev track the SBT holders
    mapping(address account => bool isHolder) public g_holders;
    /// @dev track the number of SBT holders
    uint256 public g_amountOfHolders;

    /// @dev track the number of mintAsAdmin calls
    uint256 public g_mintAsAdminCalls;
    /// @dev track the number of mintAsWhitelisted calls
    uint256 public g_mintAsWhitelistedCalls;
    /// @dev track the number of batchMintAsAdmin calls
    uint256 public g_batchMintAsAdminCalls;

    /// @dev track the total minted
    uint256 public g_totalMinted;
    /// @dev track the total burned
    uint256 public g_totalBurned;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(SoulBoundToken _sbt, address _owner) {
        sbt = _sbt;
        owner = _owner;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function mintAsAdmin(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createOrGetAccount(accountSeed);

        /// @dev sanity conditions
        if (sbt.balanceOf(account) > 0) return;
        _ifBlacklistedThenRemove(admin, account);
        if (sbt.getWhitelistEnabled()) _ifNotWhitelistedThenAdd(admin, account);

        /// @dev update mint ghosts
        _updateMintGhosts(account);
        g_mintAsAdminCalls++;

        /// @dev mint as admin
        _changePrank(admin);
        sbt.mintAsAdmin(account);
    }

    function mintAsWhitelisted(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createOrGetAccount(accountSeed);

        /// @dev sanity conditions
        if (sbt.balanceOf(account) > 0) return;
        _ifBlacklistedThenRemove(admin, account);
        if (!sbt.getWhitelistEnabled()) _enableWhitelist(admin);
        _ifNotWhitelistedThenAdd(admin, account);

        /// @dev update mint ghosts
        _updateMintGhosts(account);
        g_mintAsWhitelistedCalls++;

        /// @dev mint as whitelisted
        _changePrank(account);
        sbt.mintAsWhitelisted();
    }

    function batchMintAsAdmin(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(adminSeed, 1, 20);
        address[] memory accountsToMint = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 accountSeed = uint256(keccak256(abi.encode(adminSeed, i)));
            address account = _createAccount(accountSeed);

            /// @dev sanity conditions
            _ifBlacklistedThenRemove(admin, account);
            if (sbt.getWhitelistEnabled()) _ifNotWhitelistedThenAdd(admin, account);

            /// @dev update ghost variables before the call
            _updateMintGhosts(account);
            g_batchMintAsAdminCalls++;

            /// @dev add account to batch
            accountsToMint[i] = account;
        }

        /// @dev execute the batch mint as admin
        _changePrank(admin);
        sbt.batchMintAsAdmin(accountsToMint);
    }

    function setWhitelistEnabled(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev set whitelist enabled
        _changePrank(admin);
        sbt.setWhitelistEnabled(!sbt.getWhitelistEnabled());
    }

    function addToWhitelist(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createAccount(accountSeed);

        /// @dev sanity conditions
        _ifWhitelistedThenRemove(admin, account);
        _ifBlacklistedThenRemove(admin, account);

        /// @dev add to whitelist
        _addToWhitelist(admin, account);
    }

    function batchAddToWhitelist(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(adminSeed, 1, 20);
        address[] memory accountsToAdd = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 accountSeed = uint256(keccak256(abi.encode(adminSeed, i)));
            address account = _createAccount(accountSeed);

            /// @dev sanity conditions
            _ifWhitelistedThenRemove(admin, account);
            _ifBlacklistedThenRemove(admin, account);

            /// @dev add account to batch
            accountsToAdd[i] = account;
        }

        /// @dev execute the batch add to whitelist
        _changePrank(admin);
        sbt.batchAddToWhitelist(accountsToAdd);
    }

    function removeFromWhitelist(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createOrGetAccount(accountSeed);

        /// @dev sanity conditions
        _ifBlacklistedThenRemove(admin, account);
        _ifNotWhitelistedThenAdd(admin, account);

        /// @dev remove from whitelist
        _removeFromWhitelist(admin, account);
    }

    function batchRemoveFromWhitelist(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(adminSeed, 1, 20);
        address[] memory accountsToRemove = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 accountSeed = uint256(keccak256(abi.encode(adminSeed, i)));
            address account = _createAccount(accountSeed);

            /// @dev sanity conditions
            _ifBlacklistedThenRemove(admin, account);
            _ifNotWhitelistedThenAdd(admin, account);

            /// @dev add account to batch
            accountsToRemove[i] = account;
        }

        /// @dev execute the batch remove from whitelist
        _changePrank(admin);
        sbt.batchRemoveFromWhitelist(accountsToRemove);
    }

    function addToBlacklist(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createAccount(accountSeed);

        /// @dev sanity conditions
        // _ifWhitelistedThenRemove(admin, account);
        _ifBlacklistedThenRemove(admin, account);

        /// @dev add to blacklist
        _addToBlacklist(admin, account);
    }

    function batchAddToBlacklist(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(adminSeed, 1, 20);
        address[] memory accountsToAdd = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 accountSeed = uint256(keccak256(abi.encode(adminSeed, i)));
            address account = _createAccount(accountSeed);

            /// @dev sanity conditions
            // _ifWhitelistedThenRemove(admin, account);
            _ifBlacklistedThenRemove(admin, account);
            if (g_holders[account]) _updateBurnGhosts(account);

            /// @dev add account to batch
            accountsToAdd[i] = account;
        }

        /// @dev execute the batch add to blacklist
        _changePrank(admin);
        sbt.batchAddToBlacklist(accountsToAdd);
    }

    function removeFromBlacklist(uint256 adminSeed, uint256 accountSeed) external {
        /// @dev get actors
        address admin = _createOrGetAdmin(adminSeed);
        address account = _createOrGetAccount(accountSeed);

        /// @dev sanity conditions
        _ifWhitelistedThenRemove(admin, account);
        _ifNotBlacklistedThenAdd(admin, account);
        if (g_holders[account]) _updateBurnGhosts(account);

        /// @dev remove from blacklist
        _removeFromBlacklist(admin, account);
    }

    function batchRemoveFromBlacklist(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAdmin(adminSeed);

        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(adminSeed, 1, 20);
        address[] memory accountsToRemove = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 accountSeed = uint256(keccak256(abi.encode(adminSeed, i)));
            address account = _createAccount(accountSeed);

            /// @dev sanity conditions
            _ifWhitelistedThenRemove(admin, account);
            _ifNotBlacklistedThenAdd(admin, account);

            /// @dev update blacklist ghosts
            _updateBlacklistGhosts(account, false);

            /// @dev add account to batch
            accountsToRemove[i] = account;
        }

        /// @dev execute the batch remove from blacklist
        _changePrank(admin);
        sbt.batchRemoveFromBlacklist(accountsToRemove);
    }

    function setAdmin(uint256 adminSeed) external {
        /// @dev get admin
        address admin = _createOrGetAccount(adminSeed);

        /// @dev set admin
        _setAdmin(admin, !sbt.getIsAdmin(admin));
    }

    function batchSetAdmin(uint256 initialSeed, bool isAdmin) external {
        /// @dev determine batch size (1 to 20 accounts)
        uint256 length = bound(initialSeed, 1, 20);
        address[] memory adminsToSet = new address[](length);

        /// @dev generate and prepare accounts
        for (uint256 i = 0; i < length; ++i) {
            /// @dev generate a unique seed for each account
            uint256 adminSeed = uint256(keccak256(abi.encode(initialSeed, i)));
            address account = _createAccount(adminSeed);

            if (sbt.getIsAdmin(account) == isAdmin) _setAdmin(account, !isAdmin);

            /// @dev update admin ghosts
            _updateAdminGhosts(account, isAdmin);

            /// @dev add account to batch
            adminsToSet[i] = account;
        }

        /// @dev execute batch set admin
        _changePrank(owner);
        sbt.batchSetAdmin(adminsToSet, isAdmin);
    }

    function setBaseURI(bytes32 baseURIBytes32) external {
        string memory baseURI = string(abi.encodePacked(baseURIBytes32));
        _changePrank(owner);
        sbt.setBaseURI(baseURI);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    function _updateMintGhosts(address account) internal {
        g_holders[account] = true;
        g_amountOfHolders++;
        g_totalMinted++;
        holders.add(account);
    }

    function _updateBurnGhosts(address account) internal {
        g_holders[account] = false;
        g_amountOfHolders--;
        g_totalBurned++;
        holders.remove(account);
    }

    function _addToWhitelist(address admin, address account) internal {
        g_whitelisted[account] = true;
        whitelisted.add(account);
        _changePrank(admin);
        sbt.addToWhitelist(account);
    }

    function _addToBlacklist(address admin, address account) internal {
        if (g_holders[account]) _updateBurnGhosts(account);
        g_blacklisted[account] = true;
        blacklisted.add(account);
        _changePrank(admin);
        sbt.addToBlacklist(account);
    }

    function _enableWhitelist(address admin) internal {
        _changePrank(admin);
        sbt.setWhitelistEnabled(true);
    }

    function _ifNotWhitelistedThenAdd(address admin, address account) internal {
        if (!sbt.getWhitelisted(account)) _addToWhitelist(admin, account);
    }

    function _ifWhitelistedThenRemove(address admin, address account) internal {
        if (sbt.getWhitelisted(account)) _removeFromWhitelist(admin, account);
    }

    function _ifNotBlacklistedThenAdd(address admin, address account) internal {
        if (!sbt.getBlacklisted(account)) _addToBlacklist(admin, account);
    }

    function _ifBlacklistedThenRemove(address admin, address account) internal {
        if (sbt.getBlacklisted(account)) _removeFromBlacklist(admin, account);
    }

    function _removeFromBlacklist(address admin, address account) internal {
        _updateBlacklistGhosts(account, false);
        _changePrank(admin);
        sbt.removeFromBlacklist(account);
    }

    function _removeFromWhitelist(address admin, address account) internal {
        g_whitelisted[account] = false;
        whitelisted.remove(account);
        _changePrank(admin);
        sbt.removeFromWhitelist(account);
    }

    function _updateBlacklistGhosts(address account, bool isBlacklisted) internal {
        g_blacklisted[account] = isBlacklisted;
        if (isBlacklisted) blacklisted.add(account);
        else blacklisted.remove(account);
    }

    function _updateAdminGhosts(address admin, bool isAdmin) internal {
        g_admins[admin] = isAdmin;
        if (isAdmin) admins.add(admin);
        else admins.remove(admin);
    }

    function _setAdmin(address admin, bool isAdmin) internal {
        _updateAdminGhosts(admin, isAdmin);
        _changePrank(owner);
        sbt.setAdmin(admin, isAdmin);
    }

    /*//////////////////////////////////////////////////////////////
                                UTILITY
    //////////////////////////////////////////////////////////////*/
    /// @dev helper function for looping through holders in the system
    function forEachHolder(function(address) external func) external {
        if (holders.length() == 0) return;

        for (uint256 i; i < holders.length(); ++i) {
            func(holders.at(i));
        }
    }

    /// @dev helper function for looping through blacklisted accounts in the system
    function forEachBlacklisted(function(address) external func) external {
        if (blacklisted.length() == 0) return;

        for (uint256 i; i < blacklisted.length(); ++i) {
            func(blacklisted.at(i));
        }
    }

    /// @dev convert a seed to an address
    function _seedToAddress(uint256 addressSeed) internal pure returns (address seedAddress) {
        uint160 boundInt = uint160(bound(addressSeed, 1, type(uint160).max));
        seedAddress = address(boundInt);
    }

    /// @dev create an account
    /// @param accountSeed the seed to create the account from
    /// @return account The account
    function _createAccount(uint256 accountSeed) internal returns (address account) {
        account = _seedToAddress(accountSeed);
        accounts.add(account);
    }

    /// @dev create or get an account
    /// @param accountSeed the seed to create or get the account from
    /// @return account The account
    function _createOrGetAccount(uint256 accountSeed) internal returns (address account) {
        if (accounts.length() == 0) account = _createAccount(accountSeed);
        else account = _indexToAccount(accountSeed);
    }

    function _createOrGetAdmin(uint256 adminSeed) internal returns (address admin) {
        admin = _createOrGetAccount(adminSeed);
        if (!sbt.getIsAdmin(admin)) _setAdmin(admin, true);
    }

    // @review - should this be renamed to _seedToAccount?
    /// @dev convert an index to an existing account in a set
    /// @param addressIndex the index of the account to convert
    /// @return The account at the index
    function _indexToAccount(uint256 addressIndex) internal view returns (address) {
        return accounts.at(bound(addressIndex, 0, accounts.length() - 1));
    }

    function _changePrank(address newPrank) internal {
        vm.stopPrank();
        vm.startPrank(newPrank);
    }
}
