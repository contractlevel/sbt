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

/*//////////////////////////////////////////////////////////////
                           FUNCTIONS
//////////////////////////////////////////////////////////////*/
/// @notice enforce consistency between ERC721::_owners and ERC721Enumerable::_ownedTokens
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

/// @notice Update g_admins when s_admins is modified
hook Sstore currentContract.s_admins[KEY address a] bool newStatus (bool oldStatus) {
    g_admins[a] = newStatus;
}

/// @notice Update g_whitelisted when s_whitelist is modified
hook Sstore currentContract.s_whitelist[KEY address a] bool newStatus (bool oldStatus) {
    g_whitelisted[a] = newStatus;
}

/// @notice Update g_blacklisted when s_blacklist is modified
hook Sstore currentContract.s_blacklist[KEY address a] bool newStatus (bool oldStatus) {
    g_blacklisted[a] = newStatus;
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

// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//
// ------------------------------------------------------------//

rule mintAsWhitelisted_revertsWhen_whitelistDisabled() {
    env e;
    calldataarg args;
    require !getWhitelistEnabled();

    mintAsWhitelisted@withrevert(e, args);
    assert lastReverted;
}

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