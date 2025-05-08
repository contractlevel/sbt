# SoulBoundToken

A SoulBoundToken contract for Optimism with administrative whitelist and blacklist functionality. Only one token can be held per address. Tokens cannot be transferred or approved.

## Table of Contents

- [SoulBoundToken](#soulboundtoken)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Roles](#roles)
    - [Owner](#owner)
    - [Admins](#admins)
    - [Whitelisted](#whitelisted)
    - [Blacklisted](#blacklisted)
  - [Valid States](#valid-states)
    - [Whitelist Enabled](#whitelist-enabled)
    - [Whitelist Disabled](#whitelist-disabled)
  - [Constructor/Deployment](#constructordeployment)
  - [External Functions](#external-functions)
    - [Minting](#minting)
    - [Whitelist Management](#whitelist-management)
    - [Blacklist Management](#blacklist-management)
    - [Assign/Revoke Admin](#assignrevoke-admin)
    - [Base URI](#base-uri)
  - [Usage](#usage)
  - [Testing](#testing)
  - [Formal Verification](#formal-verification)
  - [Important Notes](#important-notes)
  - [Comments on Design Choices](#comments-on-design-choices)
  - [Frontend Notes](#frontend-notes)
    - [Libraries for connecting frontend to smart contract:](#libraries-for-connecting-frontend-to-smart-contract)
    - [What is needed?](#what-is-needed)
    - [Non-admin/user mints](#non-adminuser-mints)
      - [Fee](#fee)
      - [Signature](#signature)
  - [License](#license)

## Features

- **Non-transferrable Tokens**: Tokens are "soulbound," meaning they cannot be transferred, traded, or approved for transfer.
- **Single Token per Address**: Each address is limited to holding at most one token.
- **Admin Roles**: Administrative roles enable controlled management of whitelists, blacklists, and contract settings.
- **Whitelist Functionality**: Can be toggled on or off to restrict token minting to whitelisted addresses.
- **Blacklist Functionality**: Blacklisted addresses have their tokens burned (if any) and are excluded from minting and whitelisting.
- **Batch Operations**: Supports batch minting, whitelisting, blacklisting, and admin assignment for operational efficiency.

## Roles

There are four key roles in this system:

### Owner

- Can assign and revoke admin roles.
- Can set the base URI for token metadata.

### Admins

- Can assign and revoke whitelisted and blacklisted roles.
- Can enable or disable the whitelist.
- Can mint tokens to addresses (subject to whitelist and blacklist rules).

### Whitelisted

- Can mint a token for themselves if the whitelist is enabled.

### Blacklisted

- Cannot be minted a token.
- If they previously held a token, it is burned upon blacklisting.
- If they were on the whitelist, they are removed from it upon blacklisting.

## Valid States

There are two valid states in this system:

### Whitelist Enabled

- Whitelisted accounts can mint a token for themselves.
- Admins can mint tokens to whitelisted accounts.

### Whitelist Disabled

- Admins can mint tokens to any address that is not blacklisted.

## Constructor/Deployment

When the `SoulBoundToken` contract is deployed, the following parameters must be provided:

- `name`: The name of the token (e.g., "SoulBoundToken").
- `symbol`: The symbol of the token (e.g., "SBT").
- `baseURI`: The base URI for token metadata (e.g., "https://ipfs.io/ipfs/<CID>/").
- `whitelistEnabled`: A boolean indicating whether the whitelist is initially enabled (`true`) or disabled (`false`).

The deployer of the contract becomes the initial owner. **NOTE: This can be changed so the initial owner can be set to another address on deployment.**

## External Functions

Below are the external functions that modify the contract's state:

### Minting

- **`mintAsAdmin(address account)`**

  - **Description**: Allows an admin to mint a token to a specified address.
  - **Requirements**:
    - Caller must be an admin.
    - If whitelist is enabled, `account` must be whitelisted.
    - `account` must not be blacklisted.
    - `account` must not already hold a token.
  - **Returns**: `uint256` - The ID of the minted token.

- **`batchMintAsAdmin(address[] calldata accounts)`**

  - **Description**: Allows an admin to mint tokens to multiple addresses in a single transaction.
  - **Requirements**:
    - Caller must be an admin.
    - `accounts` array must not be empty.
    - For each address: same checks as `mintAsAdmin`.
  - **Returns**: `uint256[]` - Array of minted token IDs.

- **`mintAsWhitelisted()`**
  - **Description**: Allows a whitelisted address to mint a token for themselves.
  - **Requirements**:
    - Whitelist must be enabled.
    - Caller must be whitelisted.
    - Caller must not be blacklisted.
    - Caller must not already hold a token.
  - **Returns**: `uint256` - The ID of the minted token.

### Whitelist Management

- **`addToWhitelist(address account)`**

  - **Description**: Adds an address to the whitelist.
  - **Requirements**:
    - Caller must be an admin.
    - `account` must not be the zero address.
    - `account` must not already be whitelisted.
    - `account` must not be blacklisted.

- **`batchAddToWhitelist(address[] calldata accounts)`**

  - **Description**: Adds multiple addresses to the whitelist.
  - **Requirements**:
    - Caller must be an admin.
    - `accounts` array must not be empty.
    - For each address: same checks as `addToWhitelist`.

- **`removeFromWhitelist(address account)`**

  - **Description**: Removes an address from the whitelist.
  - **Requirements**:
    - Caller must be an admin.
    - `account` must be whitelisted.

- **`batchRemoveFromWhitelist(address[] calldata accounts)`**

  - **Description**: Removes multiple addresses from the whitelist.
  - **Requirements**:
    - Caller must be an admin.
    - `accounts` array must not be empty.
    - Each address must be whitelisted.

- **`setWhitelistEnabled(bool whitelistEnabled)`**
  - **Description**: Enables or disables the whitelist.
  - **Requirements**:
    - Caller must be an admin.
    - New status must differ from the current status.

### Blacklist Management

- **`addToBlacklist(address account)`**

  - **Description**: Adds an address to the blacklist, burning any token they hold and removing them from the whitelist if applicable.
  - **Requirements**:
    - Caller must be an admin.
    - `account` must not be the zero address.
    - `account` must not already be blacklisted.

- **`batchAddToBlacklist(address[] calldata accounts)`**

  - **Description**: Adds multiple addresses to the blacklist.
  - **Requirements**:
    - Caller must be an admin.
    - `accounts` array must not be empty.
    - For each address: same checks as `addToBlacklist`.

- **`removeFromBlacklist(address account)`**

  - **Description**: Removes an address from the blacklist.
  - **Requirements**:
    - Caller must be an admin.
    - `account` must be blacklisted.

- **`batchRemoveFromBlacklist(address[] calldata accounts)`**
  - **Description**: Removes multiple addresses from the blacklist.
  - **Requirements**:
    - Caller must be an admin.
    - `accounts` array must not be empty.
    - Each address must be blacklisted.

### Assign/Revoke Admin

- **`setAdmin(address account, bool isAdmin)`**

  - **Description**: Sets the admin status for an address (assigns or revokes admin role).
  - **Requirements**:
    - Caller must be the owner.
    - `account`’s admin status must not already be set to `isAdmin`.
    - `account` must not be the zero address.

- **`batchSetAdmin(address[] calldata accounts, bool isAdmin)`**
  - **Description**: Sets the admin status for multiple addresses.
  - **Requirements**:
    - Caller must be the owner.
    - `accounts` array must not be empty.
    - For each address: same checks as `setAdmin`.

### Base URI

- **`setBaseURI(string memory baseURI)`**
  - **Description**: Sets the base URI for token metadata.
  - **Requirements**:
    - Caller must be the owner.
  - **Note**:
    - This could be a Terms of Service on IPFS.

## Usage

1. **Deployment**:

   - Deploy the contract with:
     - `name`: The token name (e.g., "SoulBoundToken").
     - `symbol`: The token symbol (e.g., "SBT").
     - `baseURI`: The base URI for token metadata (e.g., "https://ipfs.io/ipfs/<CID>/").
     - `whitelistEnabled`: Initial whitelist status (`true` or `false`).
   - The deployer becomes the initial owner.

2. **Owner Setup**:

   - Assign admin roles using `setAdmin` or `batchSetAdmin`.
   - Optionally, update the `baseURI` with `setBaseURI`.

3. **Admin Actions**:

   - Manage the whitelist with `addToWhitelist`, `batchAddToWhitelist`, `removeFromWhitelist`, or `batchRemoveFromWhitelist`.
   - Manage the blacklist with `addToBlacklist`, `batchAddToBlacklist`, `removeFromBlacklist`, or `batchRemoveFromBlacklist`.
   - Toggle the whitelist status with `setWhitelistEnabled`.
   - Mint tokens using `mintAsAdmin` or `batchMintAsAdmin`.

4. **Whitelisted Users**:
   - If the whitelist is enabled, whitelisted users can call `mintAsWhitelisted` to mint a token for themselves (assuming they are not blacklisted and do not already hold a token).

## Testing

Run `forge install` to install dependencies.

See coverage with `forge coverage` and `forge coverage --report debug`.

For unit tests run:

```
forge test --mt test_sbt
```

For invariant tests run:

```
forge test --mt invariant
```

## Formal Verification

This project uses [Certora](https://docs.certora.com/en/latest/) for formal verification.

To run the specification, first export your Certora prover key, and then run the configuration file:

```
export CERTORAKEY=<YOUR_KEY_HERE>
certoraRun ./certora/conf/SoulBoundToken.conf
```

## Important Notes

- **Non-transferrable Tokens**: Tokens cannot be transferred. Attempts to call `transferFrom`, `approve`, or `setApprovalForAll` will revert with `SoulBoundToken__TransferNotAllowed` or `SoulBoundToken__ApprovalNotAllowed`.
- **Blacklisting Effects**: Adding an address to the blacklist burns any token they hold and removes them from the whitelist if applicable. Blacklisted addresses cannot be whitelisted or minted new tokens.
- **Token Limits**: Each address can hold at most one token. Attempts to mint to an address that already holds a token will revert with `SoulBoundToken__AlreadyMinted`.
- **Token IDs**: Token IDs start at 1 and increment sequentially with each mint.
- **Error Handling**: Functions include detailed revert conditions (e.g., zero address checks, duplicate status checks) to ensure robust and secure operation.
- **Zero Address Mints**: ERC721 reverts if mints are attempted to the zero address, so that functionality hasn't been explictly added.

## Comments on Design Choices

- **Separate Add/Remove Functions**: Functions like `addToWhitelist` and `removeFromWhitelist` are separate rather than combined into a single `setWhitelist(address, bool)` function. This design choice prioritizes simplicity and readability over a more compact but less intuitive interface. The same applies to blacklist and batch equivalents.
- **Token ID Management**: The `_incrementTokenIdCounter` function optimizes storage reads and writes during batch minting.

## Frontend Notes

### Libraries for connecting frontend to smart contract:

[ethers.js](https://docs.ethers.org/v6/) - this is the most popular and probably the best option.

[web3.js](https://web3js.readthedocs.io/en/v1.10.0/) - there's also this one if you have issues with ethers.

### What is needed?

- deployed SBT contract address
- probably rpc url for the blockchain network contract is deployed to
- contract ABI (application binary interface) - this is like a JSON file with information about the contract's functions and is created when the contract is compiled. I can find it later

### Non-admin/user mints

#### Fee

Users will have to pay a fee (if there is a fee) when minting a token. The fee can be retrieved from the contract's `getFee()` function (will return 0 if no fee) and should be passed as a `msg.value`.

Fees apply to both `mintAsWhitelisted()` and `mintWithTerms()`.

#### Signature

`mintWithTerms()` takes a signature as an argument. The signature must be unique to the user/msg.sender.

This is the logic in the contract for creating the signature:

```
/// @dev compute the message hash: keccak256(termsHash, msg.sender)
bytes32 messageHash = keccak256(abi.encodePacked(s_termsHash, msg.sender));

/// @dev apply Ethereum signed message prefix
bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
```

The value of `s_termsHash` can be retrieved from `getTermsHash()`, so you want to take that value and the user's address and create a hash of that using `keccak256(abi.encodePacked())` - ethers.js should be able to do this. Let me know if you need more information.

Then the hash that has been created with the `getTermsHash()` and user's address needs to be prefixed with a standard formatting thing for eth signatures. The logic in the library I've used looks like this:

```
keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
```

ethers.js should probably be able to do this too. Consider double checking this bit with AI.

## License

This project is licensed under the MIT License.
