/// Verification of SoulBoundToken
/// @author @contractlevel
/// @notice Non-transferrable ERC721 token with administrative whitelist and blacklist functionality

/*//////////////////////////////////////////////////////////////
                            METHODS
//////////////////////////////////////////////////////////////*/
methods {
    function getFee() external returns (uint256) envfree;
    function getBlacklisted(address) external returns (bool) envfree;
    function balanceOf(address) external returns (uint256) envfree;

    // Summaries
    function _.latestRoundData() external => DISPATCHER(true);
    function _.onERC721Received(address,address,uint256,bytes) external => DISPATCHER(true);
    function _._verifySignature(bytes memory signature) internal => NONDET;

    // Harness helper functions
    function getSignerSignature(address,bytes) external returns (bool) envfree;
}

/*//////////////////////////////////////////////////////////////
                          DEFINITIONS
//////////////////////////////////////////////////////////////*/
/// @notice number of CALLVALUE opcodes used per mint
definition MsgValueOpcodePerMint() returns mathint = 3;

/// @notice functions that can take a fee
definition canTakeFee(method f) returns bool =
    f.selector == sig:mintAsWhitelisted().selector ||
    f.selector == sig:mintWithTerms(bytes).selector;

/*//////////////////////////////////////////////////////////////
                             GHOSTS
//////////////////////////////////////////////////////////////*/
/// @notice track total fees withdrawn
persistent ghost mathint g_totalFeesWithdrawn {
    init_state axiom g_totalFeesWithdrawn == 0;
}

/// @notice this tracks the total value of CALLVALUE opcodes used in mints, and must be divided by MsgValueOpcodePerMint()
persistent ghost mathint g_totalCallvaluePreDivision {
    init_state axiom g_totalCallvaluePreDivision == 0;
}

/*//////////////////////////////////////////////////////////////
                             HOOKS
//////////////////////////////////////////////////////////////*/
// CALLVALUE opcode is used 3 times per mint, so that must be accounted for with MsgValueOpcodePerMint()
hook CALLVALUE uint v {
    if (v > 0) {
        g_totalCallvaluePreDivision = g_totalCallvaluePreDivision + to_mathint(v);
    }
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, uint retOffset, uint retLength) uint rc {
    if (value > 0 && addr != currentContract) {
        g_totalFeesWithdrawn = g_totalFeesWithdrawn + to_mathint(value);
    }
}

/*//////////////////////////////////////////////////////////////
                           INVARIANTS
//////////////////////////////////////////////////////////////*/
/// @notice the balance of the SBT contract should always cover the accumulated fees minus fees withdrawn
invariant feesAccountancy()
    nativeBalances[currentContract] >= 
        (g_totalCallvaluePreDivision / MsgValueOpcodePerMint()) - g_totalFeesWithdrawn;

/*//////////////////////////////////////////////////////////////
                             RULES
//////////////////////////////////////////////////////////////*/
/// @notice functions that can take a fee should increase currentContract.balance
rule feeCollection_increaseBalance(method f) filtered {f -> canTakeFee(f)} {
    env e;
    calldataarg args;
    require getFee() > 0;
    require e.msg.sender != currentContract;

    uint256 startBalance = nativeBalances[currentContract];

    f(e, args);

    assert nativeBalances[currentContract] > startBalance;
}

rule mintWithTerms_revertsWhen_insufficientFee() {
    env e;
    bytes s;
    require !getBlacklisted(e.msg.sender);
    require getFee() > 0;
    require !currentContract._paused;
    require getVerifiedSignature(e, s);
    
    require e.msg.value < getFee();
    mintWithTerms@withrevert(e, s);
    assert lastReverted;
}

rule mintWithTerms_success() {
    env e;
    bytes s;
    uint256 startBalance = nativeBalances[currentContract];

    mintWithTerms(e, s);

    assert balanceOf(e.msg.sender) == 1;
    assert nativeBalances[currentContract] >= startBalance;
    // assert getSignerSignature(e.msg.sender, s); // @review auto havoc not resolving signer.staticcall(abi.encodeCall(IERC1271.isValidSignature, (hash, signature)))
}