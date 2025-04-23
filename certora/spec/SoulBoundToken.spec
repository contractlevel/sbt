/// Verification of SoulBoundToken
/// @author @contractlevel
/// @notice Non-transferrable ERC721 token with administrative whitelist and blacklist functionality

/*//////////////////////////////////////////////////////////////
                            METHODS
//////////////////////////////////////////////////////////////*/
methods {
    function totalSupply() external returns (uint256) envfree;
    function tokenOfOwnerByIndex(address,uint256) external returns (uint256) envfree;
    function owner() external returns (address) envfree;
    function balanceOf(address) external returns (uint256) envfree;
    function getWhitelisted(address) external returns (bool) envfree;
    function getBlacklisted(address) external returns (bool) envfree;
    function getIsAdmin(address) external returns (bool) envfree;
    function ownerOf(uint256) external returns (address) envfree;
    function getWhitelistEnabled() external returns (bool) envfree;
    function setWhitelistEnabled(bool) external;
}

/*//////////////////////////////////////////////////////////////
                          DEFINITIONS
//////////////////////////////////////////////////////////////*/
/// @notice external functions that can mint
definition canMint(method f) returns bool = 
	f.selector == sig:mintAsAdmin(address).selector || 
	f.selector == sig:batchMintAsAdmin(address[]).selector ||
    f.selector == sig:mintAsWhitelisted().selector;

/// @notice external functions that can burn
definition canBurn(method f) returns bool = 
	f.selector == sig:addToBlacklist(address).selector ||
    f.selector == sig:batchAddToBlacklist(address[]).selector;

/// @notice functions that can only be called by admins
definition onlyAdmin(method f) returns bool = 
    f.selector == sig:setWhitelistEnabled(bool).selector ||
    f.selector == sig:addToWhitelist(address).selector ||
    f.selector == sig:batchAddToWhitelist(address[]).selector ||
    f.selector == sig:removeFromWhitelist(address).selector ||
    f.selector == sig:batchRemoveFromWhitelist(address[]).selector ||
    f.selector == sig:addToBlacklist(address).selector ||
    f.selector == sig:batchAddToBlacklist(address[]).selector ||
    f.selector == sig:removeFromBlacklist(address).selector ||
    f.selector == sig:batchRemoveFromBlacklist(address[]).selector ||
    f.selector == sig:mintAsAdmin(address).selector ||
    f.selector == sig:batchMintAsAdmin(address[]).selector;

/// @notice functions that can only be called by the owner
definition onlyOwner(method f) returns bool = 
    f.selector == sig:setAdmin(address,bool).selector ||
    f.selector == sig:batchSetAdmin(address[],bool).selector ||
    f.selector == sig:setBaseURI(string).selector;

/// @notice function that take an array of addresses as an argument
definition batchFunction(method f) returns bool = 
    f.selector == sig:batchAddToWhitelist(address[]).selector ||
    f.selector == sig:batchAddToBlacklist(address[]).selector ||
    f.selector == sig:batchRemoveFromWhitelist(address[]).selector ||
    f.selector == sig:batchRemoveFromBlacklist(address[]).selector ||
    f.selector == sig:batchMintAsAdmin(address[]).selector ||
    f.selector == sig:batchSetAdmin(address[],bool).selector;

/// @notice functions for approving ERC721
definition canApprove(method f) returns bool =
    f.selector == sig:approve(address,uint256).selector ||
    f.selector == sig:setApprovalForAll(address,bool).selector;

definition AddedToWhitelistEvent() returns bytes32 =
// keccak256(abi.encodePacked("AddedToWhitelist(address)"))
    to_bytes32(0xa850ae9193f515cbae8d35e8925bd2be26627fc91bce650b8652ed254e9cab03);

definition RemovedFromWhitelistEvent() returns bytes32 =
// keccak256(abi.encodePacked("RemovedFromWhitelist(address)"))
    to_bytes32(0xcdd2e9b91a56913d370075169cefa1602ba36be5301664f752192bb1709df757);

definition AddedToBlacklistEvent() returns bytes32 =
// keccak256(abi.encodePacked("AddedToBlacklist(address)"))
    to_bytes32(0xf9b68063b051b82957fa193585681240904fed808db8b30fc5a2d2202c6ed627);

definition RemovedFromBlacklistEvent() returns bytes32 =
// keccak256(abi.encodePacked("RemovedFromBlacklist(address)"))
    to_bytes32(0x2b6bf71b58b3583add364b3d9060ebf8019650f65f5be35f5464b9cb3e4ba2d4);

definition UpdatedWhitelistEnabledEvent() returns bytes32 =
// keccak256(abi.encodePacked("UpdatedWhitelistEnabled(bool)"))
    to_bytes32(0xa5cd35b7d08099e2e1b6ac2519d634bccdaa9f147976786a54580f0d354e342f);

definition AdminStatusSetEvent() returns bytes32 =
// keccak256(abi.encodePacked("AdminStatusSet(address,bool)"))
    to_bytes32(0xa8c4c644eea5bad1029a340b24f332f16eeb8ca98e4cb0ce50df3083fc6d40b4);

/*//////////////////////////////////////////////////////////////
                           FUNCTIONS
//////////////////////////////////////////////////////////////*/
/// @notice require this to enforce consistency between ERC721::_owners and ERC721Enumerable::_ownedTokens
function ownershipConsistency(address owner, uint256 index) returns bool {
    return index < balanceOf(owner) => 
        ownerOf(tokenOfOwnerByIndex(owner, index)) == owner;
}

/*//////////////////////////////////////////////////////////////
                             GHOSTS
//////////////////////////////////////////////////////////////*/
/// @notice track total SBTs minted
persistent ghost mathint g_totalMinted {
    init_state axiom g_totalMinted == 0;
}

/// @notice track total SBTs burned
persistent ghost mathint g_totalBurned {
    init_state axiom g_totalBurned == 0;
}

/// @notice track if a transfer has happened
persistent ghost bool g_transferHappened {
    init_state axiom g_transferHappened == false;
}

/// @notice Track admin status for addresses
persistent ghost mapping(address => bool) g_admins {
    init_state axiom forall address a. g_admins[a] == false;
}

/// @notice Track whitelist status for addresses
persistent ghost mapping(address => bool) g_whitelisted {
    init_state axiom forall address a. g_whitelisted[a] == false;
}

/// @notice Track blacklist status for addresses
persistent ghost mapping(address => bool) g_blacklisted {
    init_state axiom forall address a. g_blacklisted[a] == false;
}

/// @notice track SBT token balance per account
persistent ghost mapping(address => uint256) g_balances {
    init_state axiom forall address a. g_balances[a] == 0;
}

/// @notice track amount AddedToWhitelist event is emitted
persistent ghost mathint g_addedToWhitelistEventCount {
    init_state axiom g_addedToWhitelistEventCount == 0;
}

/// @notice track amount RemoveFromWhitelist event is emitted
persistent ghost mathint g_removedFromWhitelistEventCount {
    init_state axiom g_removedFromWhitelistEventCount == 0;
}

/// @notice track amount AddedToBlacklist event is emitted
persistent ghost mathint g_addedToBlacklistEventCount {
    init_state axiom g_addedToBlacklistEventCount == 0;
}

/// @notice track amount RemovedFromBlacklist event is emitted
persistent ghost mathint g_removedFromBlacklistEventCount {
    init_state axiom g_removedFromBlacklistEventCount == 0;
}

/// @notice track amount UpdatedWhitelistEnabled event is emitted
persistent ghost mathint g_updatedWhitelistEnabledEventCount {
    init_state axiom g_updatedWhitelistEnabledEventCount == 0;
}

/// @notice track amount AdminStatusSet event is emitted
persistent ghost mathint g_adminStatusSetEventCount {
    init_state axiom g_adminStatusSetEventCount == 0;
}

/// @notice track amount s_whitelist is modified
persistent ghost mathint g_whitelistStorageCount {
    init_state axiom g_whitelistStorageCount == 0;
}

/// @notice track amount s_blacklist is modified
persistent ghost mathint g_blacklistStorageCount {
    init_state axiom g_blacklistStorageCount == 0;
}

/// @notice track amount s_admins is modified
persistent ghost mathint g_adminStorageCount {
    init_state axiom g_adminStorageCount == 0;
}

/// @notice track status of s_whitelistEnabled
persistent ghost bool g_whitelistEnabled {
    init_state axiom g_whitelistEnabled == false;
}

/// @notice track amount s_whitelistEnabled is modified
persistent ghost mathint g_whitelistEnabledStorageCount {
    init_state axiom g_whitelistEnabledStorageCount == 0;
}

/*//////////////////////////////////////////////////////////////
                             HOOKS
//////////////////////////////////////////////////////////////*/
/// @notice update g_totalMinted and g_totalBurned when _allTokens changes
hook Sstore currentContract._allTokens.length uint256 newValue (uint256 oldValue) {
    if (newValue > oldValue) g_totalMinted = g_totalMinted + newValue - oldValue;
    else if (newValue < oldValue) g_totalBurned = g_totalBurned + oldValue - newValue;
}

/// @notice update g_transferHappened ghost if a non mint/burn transfer happens
/// @notice the only transfers should be mint and burn (ie from and to address(0))
hook Sstore currentContract._owners[KEY uint256 tokenId] address newOwner (address oldOwner) {
    if (oldOwner != 0 && newOwner != 0) g_transferHappened = true;
}

/// @notice update g_balances ghost for an account when storage changes
hook Sstore currentContract._balances[KEY address account] uint256 newBalance (uint256 oldBalance) {
    g_balances[account] = newBalance;
}

/// @notice update g_admins and increment g_adminStorageCount when s_admins is modified
hook Sstore currentContract.s_admins[KEY address a] bool newStatus (bool oldStatus) {
    g_admins[a] = newStatus;
    g_adminStorageCount = g_adminStorageCount + 1;
}

/// @notice update g_whitelisted and increment g_whitelistStorageCount when s_whitelist is modified
hook Sstore currentContract.s_whitelist[KEY address a] bool newStatus (bool oldStatus) {
    g_whitelisted[a] = newStatus;
    g_whitelistStorageCount = g_whitelistStorageCount + 1;
}

/// @notice update g_blacklisted and increment g_blacklistStorageCount when s_blacklist is modified
hook Sstore currentContract.s_blacklist[KEY address a] bool newStatus (bool oldStatus) {
    g_blacklisted[a] = newStatus;
    g_blacklistStorageCount = g_blacklistStorageCount + 1;
}

/// @notice update g_whitelistEnabled and increment g_whitelistEnabledStorageCount when s_whitelistEnabled is modified
hook Sstore currentContract.s_whitelistEnabled bool newStatus (bool oldStatus) {
    g_whitelistEnabled = newStatus;
    g_whitelistEnabledStorageCount = g_whitelistEnabledStorageCount + 1;
}

/// @notice hook onto emitted events and increment relevant ghosts
hook LOG2(uint offset, uint length, bytes32 t0, bytes32 t1) {
    if (t0 == AddedToWhitelistEvent())
        g_addedToWhitelistEventCount = g_addedToWhitelistEventCount + 1;
    if (t0 == RemovedFromWhitelistEvent())
        g_removedFromWhitelistEventCount = g_removedFromWhitelistEventCount + 1;
    if (t0 == AddedToBlacklistEvent())
        g_addedToBlacklistEventCount = g_addedToBlacklistEventCount + 1;
    if (t0 == RemovedFromBlacklistEvent())
        g_removedFromBlacklistEventCount = g_removedFromBlacklistEventCount + 1;
    if (t0 == UpdatedWhitelistEnabledEvent())
        g_updatedWhitelistEnabledEventCount = g_updatedWhitelistEnabledEventCount + 1;
}

/// @notice hook onto emitted AdminStatusSet event and increment relevant ghost
hook LOG3(uint offset, uint length, bytes32 t0, bytes32 t1, bytes32 t2) {
    if (t0 == AdminStatusSetEvent())
        g_adminStatusSetEventCount = g_adminStatusSetEventCount + 1;
}

/*//////////////////////////////////////////////////////////////
                           INVARIANTS
//////////////////////////////////////////////////////////////*/
/// @notice total SBTs minted must equal total SBTs burned
invariant totalSupplyAccounting()
    to_mathint(totalSupply()) == g_totalMinted - g_totalBurned;

/// @notice each account can hold at most one token
invariant oneTokenPerAccount(address a, uint256 index)
    balanceOf(a) <= 1 {
        preserved {
            require ownershipConsistency(a, index);
        }
    }

/// @notice no blacklisted accounts should hold the token
invariant blacklisted_noToken(address a, uint256 index)
    getBlacklisted(a) => balanceOf(a) == 0 {
        preserved {
            requireInvariant blacklistedCantBeWhitelisted(a);
            requireInvariant oneTokenPerAccount(a, index);
            require ownershipConsistency(a, index);
        }
    }

/// @notice no transfers should have happened
invariant noTransfers()
    !g_transferHappened;

/// @notice blacklisted accounts cannot be whitelisted
invariant blacklistedCantBeWhitelisted(address a)
    getBlacklisted(a) => !getWhitelisted(a);

/// @notice total whitelist storage updates should equal sum of AddedToWhitelist and RemovedFromWhitelist events
invariant whitelist_eventConsistency()
    g_whitelistStorageCount == g_addedToWhitelistEventCount + g_removedFromWhitelistEventCount;

/// @notice total blacklist storage updates should equal sum of AddedToBlacklist and RemovedFromBlacklist events
invariant blacklist_eventConsistency()
    g_blacklistStorageCount == g_addedToBlacklistEventCount + g_removedFromBlacklistEventCount;

/// @notice total admin storage updates should equal total AdminStatusSet events
invariant admin_eventConsistency()
    g_adminStorageCount == g_adminStatusSetEventCount;

/// @notice total whitelist enabled storage updates should equal total UpdatedWhitelistEnabled events
invariant whitelistEnabled_eventConsistency()
    g_whitelistEnabledStorageCount == g_updatedWhitelistEnabledEventCount;

/*//////////////////////////////////////////////////////////////
                             RULES
//////////////////////////////////////////////////////////////*/
/// @notice minting increases total supply
rule mintingIncreasesTotalSupply(method f) filtered {f -> canMint(f)} {
    env e;
    calldataarg args;

    uint256 oldTotalSupply = totalSupply();
    require oldTotalSupply < max_uint256;

    f(e, args);

    assert totalSupply() > oldTotalSupply;
}

/// @notice any function other than minting does not increase total supply
rule nonMintingDoesNotIncreaseTotalSupply(method f) filtered {f -> !canMint(f)} {
    env e;
    calldataarg args;

    uint256 oldTotalSupply = totalSupply();

    f(e, args);

    assert totalSupply() <= oldTotalSupply;
}

/// @notice burning decreases total supply
rule burningDecreasesTotalSupply(method f) filtered {f -> canBurn(f)} {
    env e;
    calldataarg args;

    uint256 oldTotalSupply = totalSupply();

    f(e, args);

    assert totalSupply() <= oldTotalSupply;
}

/// @notice any function other than burning does not decrease total supply
rule nonBurningDoesNotDecreaseTotalSupply(method f) filtered {f -> !canBurn(f)} {
    env e;
    calldataarg args;

    uint256 oldTotalSupply = totalSupply();
    require oldTotalSupply < max_uint256;

    f(e, args);

    assert totalSupply() >= oldTotalSupply;
}

/// @notice onlyAdmin functions should revert if called by non-admins
rule onlyAdmin_revertsWhen_nonAdmin(method f) filtered {f -> onlyAdmin(f)} {
    env e;
    calldataarg args;
    require !getIsAdmin(e.msg.sender);

    f@withrevert(e, args);

    assert lastReverted;
}

/// @notice onlyOwner functions should revert if called by non-owner
rule onlyOwner_revertsWhen_nonOwner(method f) filtered {f -> onlyOwner(f)} {
    env e;
    calldataarg args;
    require e.msg.sender != owner();

    f@withrevert(e, args);

    assert lastReverted;
}

/// @notice approvals revert
rule approvals_alwaysRevert(method f) filtered {f -> canApprove(f)} {
    env e;
    calldataarg args;
    f@withrevert(e, args);
    assert lastReverted;
}

// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//

/*//////////////////////////////////////////////////////////////
                           WHITELIST
//////////////////////////////////////////////////////////////*/
// --- setWhitelistEnabled --- //
rule setWhitelistEnabled_revertsWhen_whitelistStatusAlreadySet() {
    env e;
    require getIsAdmin(e.msg.sender);
    setWhitelistEnabled@withrevert(e, getWhitelistEnabled());
    assert lastReverted;
}

rule setWhitelistEnabled_success() {
    env e;
    require getIsAdmin(e.msg.sender);
    bool oldWhitelistEnabled = getWhitelistEnabled();
    setWhitelistEnabled(e, !oldWhitelistEnabled);
    assert getWhitelistEnabled() != oldWhitelistEnabled;
}

// --- addToWhitelist --- //
rule addToWhitelist_revertsWhen_zeroAddress() {
    env e;
    address a = 0;
    require getIsAdmin(e.msg.sender);
    addToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule addToWhitelist_revertsWhen_alreadyWhitelisted() {
    env e;
    address a;
    require getWhitelisted(a);
    require getIsAdmin(e.msg.sender);
    addToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule addToWhitelist_revertsWhen_blacklisted() {
    env e;
    address a;
    require getBlacklisted(a);
    require getIsAdmin(e.msg.sender);
    addToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule addToWhitelist_success() {
    env e;
    address a;
    require getIsAdmin(e.msg.sender);
    addToWhitelist(e, a);
    assert getWhitelisted(a);
}

// --- batchAddToWhitelist --- //
rule batchAddToWhitelist_revertsWhen_zeroAddress() {
    env e;
    address[] a;
    require a[0] == 0;
    require getIsAdmin(e.msg.sender);
    batchAddToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToWhitelist_revertsWhen_alreadyWhitelisted() {
    env e;
    address[] a;
    require getWhitelisted(a[0]);
    require getIsAdmin(e.msg.sender);
    batchAddToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToWhitelist_revertsWhen_blacklisted() {
    env e;
    address[] a;
    require getBlacklisted(a[0]);
    require getIsAdmin(e.msg.sender);
    batchAddToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToWhitelist_revertsWhen_emptyArray() {
    env e;
    address[] a;
    require a.length == 0;
    require getIsAdmin(e.msg.sender);
    batchAddToWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToWhitelist_success() {
    env e;
    address[] a;
    
    batchAddToWhitelist(e, a);

    assert forall uint256 i. i < a.length => g_whitelisted[a[i]];
}

// --- batchRemoveFromWhitelist --- //
rule batchRemoveFromWhitelist_revertsWhen_notWhitelisted() {
    env e;
    address[] a;
    require !getWhitelisted(a[0]);
    require getIsAdmin(e.msg.sender);
    batchRemoveFromWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchRemoveFromWhitelist_revertsWhen_emptyArray() {
    env e;
    address[] a;
    require a.length == 0;
    require getIsAdmin(e.msg.sender);
    batchRemoveFromWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule batchRemoveFromWhitelist_success() {
    env e;
    address[] a;
    batchRemoveFromWhitelist(e, a);

    assert forall uint256 i. i < a.length => !g_whitelisted[a[i]];
}

// --- removeFromWhitelist --- //
rule removeFromWhitelist_revertsWhen_notWhitelisted() {
    env e;
    address a;
    require !getWhitelisted(a);
    removeFromWhitelist@withrevert(e, a);
    assert lastReverted;
}

rule removeFromWhitelist_success() {
    env e;
    address a;
    require getWhitelisted(a);
    removeFromWhitelist(e, a);
    assert !getWhitelisted(a);
}

/*//////////////////////////////////////////////////////////////
                           BLACKLIST
//////////////////////////////////////////////////////////////*/
// --- addToBlacklist --- //
rule addToBlacklist_revertsWhen_zeroAddress() {
    env e;
    address a = 0;
    require getIsAdmin(e.msg.sender);
    addToBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule addToBlacklist_revertsWhen_alreadyBlacklisted() {
    env e;
    address a;
    require getBlacklisted(a);
    require getIsAdmin(e.msg.sender);
    addToBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule addToBlacklist_success() {
    env e;
    address a;
    uint256 index;

    requireInvariant oneTokenPerAccount(a, index);
    require ownershipConsistency(a, index);

    addToBlacklist(e, a);

    assert getBlacklisted(a);
    assert !getWhitelisted(a);
    assert balanceOf(a) == 0;
}

// --- batchAddToBlacklist --- //
rule batchAddToBlacklist_revertsWhen_zeroAddress() {
    env e;
    address[] a;
    require a[0] == 0;
    require getIsAdmin(e.msg.sender);
    batchAddToBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToBlacklist_revertsWhen_alreadyBlacklisted() {
    env e;
    address[] a;
    require getBlacklisted(a[0]);
    require getIsAdmin(e.msg.sender);
    batchAddToBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToBlacklist_revertsWhen_emptyArray() {
    env e;
    address[] a;
    require a.length == 0;
    require getIsAdmin(e.msg.sender);
    batchAddToBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule batchAddToBlacklist_success() {
    env e;
    address[] a;
    uint256 index;

    require a.length == 3
        &&  ownershipConsistency(a[0], index)
        &&  ownershipConsistency(a[1], index)
        &&  ownershipConsistency(a[2], index);
    requireInvariant oneTokenPerAccount(a[0], index);
    requireInvariant oneTokenPerAccount(a[1], index);
    requireInvariant oneTokenPerAccount(a[2], index);

    batchAddToBlacklist(e, a);

    assert  balanceOf(a[0]) == 0 && getBlacklisted(a[0]) && !getWhitelisted(a[0]) 
        &&  balanceOf(a[1]) == 0 && getBlacklisted(a[1]) && !getWhitelisted(a[1]) 
        &&  balanceOf(a[2]) == 0 && getBlacklisted(a[2]) && !getWhitelisted(a[2]);
}

// --- removeFromBlacklist --- //
rule removeFromBlacklist_revertsWhen_notBlacklisted() {
    env e;
    address a;
    require getIsAdmin(e.msg.sender);
    require !getBlacklisted(a);
    removeFromBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule removeFromBlacklist_success() {
    env e;
    address a;
    require getBlacklisted(a);
    removeFromBlacklist(e, a);
    assert !getBlacklisted(a);
}

// --- batchRemoveFromBlacklist --- //
rule batchRemoveFromBlacklist_revertsWhen_notBlacklisted() {
    env e;
    address[] a;
    require !getBlacklisted(a[0]);
    require getIsAdmin(e.msg.sender);
    batchRemoveFromBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule batchRemoveFromBlacklist_revertsWhen_emptyArray() {
    env e;
    address[] a;
    require a.length == 0;
    require getIsAdmin(e.msg.sender);
    batchRemoveFromBlacklist@withrevert(e, a);
    assert lastReverted;
}

rule batchRemoveFromBlacklist_success() {
    env e;
    address[] a;

    batchRemoveFromBlacklist(e, a);

    assert forall uint256 i. i < a.length => !g_blacklisted[a[i]];
}

/*//////////////////////////////////////////////////////////////
                              MINT
//////////////////////////////////////////////////////////////*/
// --- batchMintAsAdmin --- //
rule batchMintAsAdmin_revertsWhen_notWhitelisted_ifWhitelistEnabled() {
    env e;
    address[] a;
    require getIsAdmin(e.msg.sender);
    require getWhitelistEnabled();
    require !getWhitelisted(a[0]);
    batchMintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule batchMintAsAdmin_revertsWhen_blacklisted() {
    env e;
    address[] a;
    require getBlacklisted(a[0]);
    require getIsAdmin(e.msg.sender);
    require !getWhitelistEnabled();
    batchMintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule batchMintAsAdmin_revertsWhen_alreadyMinted() {
    env e;
    address[] a;
    require balanceOf(a[0]) == 1;
    require getIsAdmin(e.msg.sender);
    require !getWhitelistEnabled();
    batchMintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule batchMintAsAdmin_revertsWhen_emptyArray() {
    env e;
    address[] a;
    require a.length == 0;
    require getIsAdmin(e.msg.sender);
    require !getWhitelistEnabled();
    batchMintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule batchMintAsAdmin_success() {
    env e;
    address[] a;
    require getIsAdmin(e.msg.sender);
    require !getWhitelistEnabled();
    require balanceOf(a[0]) == 0;
    batchMintAsAdmin(e, a);
    assert balanceOf(a[0]) == 1;
}

// --- mintAsAdmin --- //
rule mintAsAdmin_revertsWhen_alreadyMinted () {
    env e;
    address a;
    require getIsAdmin(e.msg.sender);
    require balanceOf(a) > 0;

    mintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule mintAsAdmin_revertsWhen_blacklisted () {
    env e;
    address a;
    require getIsAdmin(e.msg.sender);
    require getBlacklisted(a);

    mintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule mintAsAdmin_revertsWhen_notWhitelistedWhenEnabled () {
    env e;
    address a;
    require getIsAdmin(e.msg.sender);
    require getWhitelistEnabled();
    require !getWhitelisted(a);

    mintAsAdmin@withrevert(e, a);
    assert lastReverted;
}

rule mintAsAdmin_success () {
    env e;
    address a;
    mintAsAdmin(e, a);
    assert balanceOf(a) == 1;
}

// --- mintAsWhitelisted --- //
rule mintAsWhitelisted_revertsWhen_whitelistDisabled() {
    env e;
    calldataarg args;
    require !getWhitelistEnabled();

    mintAsWhitelisted@withrevert(e, args);
    assert lastReverted;
}

rule mintAsWhitelisted_revertsWhen_notWhitelisted() {
    env e;
    require getWhitelistEnabled();
    require !getWhitelisted(e.msg.sender);

    mintAsWhitelisted@withrevert(e);
    assert lastReverted;
}

rule mintAsWhitelisted_revertsWhen_alreadyMinted() {
    env e;
    require getWhitelistEnabled();
    require getWhitelisted(e.msg.sender);
    require balanceOf(e.msg.sender) > 0;

    mintAsWhitelisted@withrevert(e);
    assert lastReverted;
}

rule mintAsWhitelisted_success() {
    env e;
    mintAsWhitelisted(e);
    assert balanceOf(e.msg.sender) == 1;
}

/*//////////////////////////////////////////////////////////////
                           SET ADMIN
//////////////////////////////////////////////////////////////*/
// --- setAdmin --- //
rule setAdmin_revertsWhen_alreadySet() {
    env e;
    address a;
    require e.msg.sender == owner();

    setAdmin@withrevert(e, a, getIsAdmin(a));
    assert lastReverted;
}

rule setAdmin_success() {
    env e;
    address a;
    bool isAdmin;
    setAdmin(e, a, isAdmin);
    assert isAdmin == getIsAdmin(a);
}

// --- batchSetAdmin --- //
rule batchSetAdmin_revertsWhen_alreadySet() {
    env e;
    address[] a;
    require e.msg.sender == owner();

    batchSetAdmin@withrevert(e, a, getIsAdmin(a[0]));
    assert lastReverted;
}

rule batchSetAdmin_revertsWhen_emptyArray() {
    env e;
    address[] a;
    bool isAdmin;
    require a.length == 0;
    require e.msg.sender == owner();
    batchSetAdmin@withrevert(e, a, isAdmin);
    assert lastReverted;
}

rule batchSetAdmin_success() {
    env e;
    address[] a;
    bool isAdmin;

    batchSetAdmin(e, a, isAdmin);

    assert forall uint256 i. i < a.length => g_admins[a[i]] == isAdmin;
}