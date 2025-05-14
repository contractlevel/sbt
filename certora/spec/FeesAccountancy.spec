/// Verification of SoulBoundToken
/// @author @contractlevel
/// @notice Non-transferrable ERC721 token with administrative whitelist and blacklist functionality

/*//////////////////////////////////////////////////////////////
                            METHODS
//////////////////////////////////////////////////////////////*/
methods {
    // Summaries
    function _.latestRoundData() external => DISPATCHER(true);
    function _.onERC721Received(address,address,uint256,bytes) external => DISPATCHER(true);
    function _._verifySignature(bytes memory signature) internal => NONDET;
}

/*//////////////////////////////////////////////////////////////
                          DEFINITIONS
//////////////////////////////////////////////////////////////*/
/// @notice number of CALLVALUE opcodes used per mint
definition MsgValueOpcodePerMint() returns mathint = 3;

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