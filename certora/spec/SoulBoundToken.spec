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

/*//////////////////////////////////////////////////////////////
                             HOOKS
//////////////////////////////////////////////////////////////*/
/// @notice update g_totalMinted and g_totalBurned when _allTokens changes
hook Sstore currentContract._allTokens.length uint256 newValue (uint256 oldValue) {
    if (newValue > oldValue) g_totalMinted = g_totalMinted + newValue - oldValue;
    else if (newValue < oldValue) g_totalBurned = g_totalBurned + oldValue - newValue;
}

/// @notice update g_transferHappened ghost if a non mint/burn transfer happens
hook Sstore currentContract._owners[KEY uint256 tokenId] address newOwner (address oldOwner) {
    if (oldOwner != 0 && newOwner != 0) g_transferHappened = true;
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

/// @notice the only transfers should be mint and burn (ie from and to address(0))

/// @notice onlyAdmin functions should revert if called by non-admins
rule onlyAdminFunctionsRevertIfCalledByNonAdmins(method f) filtered {f -> onlyAdmin(f)} {
    env e;
    calldataarg args;
    require !getIsAdmin(e.msg.sender);

    f@withrevert(e, args);

    assert lastReverted;
}
