# SoulBoundToken

A SoulBoundToken contract for Optimism with administrative whitelist and blacklist functionality. Only 1 token can be held per address. Tokens can not be transferred or approved.

## Roles

There are 4 key roles in this system:

1. the owner
2. the admins
3. whitelisted
4. blacklisted

### Owner

- can assign and revoke admin role
- can set the baseURI

### Admins

- can assign and revoke whitelisted and blacklisted roles
- can enable and disable whitelist
- can mint tokens

### Whitelisted

- can mint themself a token if whitelist is enabled

### Blacklisted

- can't be minted a token
- if previously minted a token, their token is burned
- if on whitelist, removed from whitelist

## Valid States

There are 2 valid states in this system:

1. whitelist enabled ✅
2. whitelist disabled ❌

### Whitelist Enabled

- whitelisted accounts can mint a token
- admins can mint tokens to whitelisted accounts

### Whitelist Disabled

- admins can mint tokens to anyone who isn't blacklisted

## Constructor/Deployment

When the SBT contract is deployed, values must be given for the token `name`, `symbol`, `baseURI` and a bool indicating whether whitelist is initially enabled or not.

## External Functions (that change state)

### Mint

- `mintAsAdmin(address)` - _onlyAdmin_
  - admin passes an address to mint it a token
- `mintAsWhitelisted()` - only when whitelist enabled
  - whitelisted user calls to mint themself a token
- `batchMintAsAdmin(address[] memory)` - _onlyAdmin_
  - admin passes an array of addresses to mint each one a token
  - each mint in the array will cost roughly the same gas as an individual `mintAsAdmin` call - _this needs to be reviewed, we should be able to make it more gas efficient_

### Whitelist

- `addToWhitelist(address)` - _onlyAdmin_
  - admin passes an address to add it to whitelist
- `batchAddToWhitelist(address[] memory)` - _onlyAdmin_
  - admin passes an array of addresses to add each to whitelist
- `removeFromWhitelist(address)` - _onlyAdmin_
  - admin passes an address to remove it from whitelist
- `batchRemoveFromWhitelist(address[] memory)` - _onlyAdmin_
  - admin passes an array of addresses to remove each from whitelist
- `setWhitelistEnabled(bool)` - _onlyAdmin_
  - admin passes a bool indicating whether whitelist is enabled or not

### Blacklist

- `addToBlacklist(address)` - _onlyAdmin_
  - admin passes an address to add it to blacklist
- `batchAddToBlacklist(address[] memory)` - _onlyAdmin_
  - admin passes an array of addresses to add each to blacklist
- `removeFromBlacklist(address)` - _onlyAdmin_
  - admin passes an address to remove it from blacklist
- `batchRemoveFromBlacklist(address[] memory)` - _onlyAdmin_
  - admin passes an array of addresses to remove each from blacklist

### Assign/Revoke Admin

- `setAdmin(address,bool)` - _onlyOwner_
  - owner passes an address and a bool indicating whether that address is an admin or not
- `batchSetAdmin(address[] memory,bool)` - _onlyOwner_
  - owner passes an array of addresses and a bool indicating whether those addresses are admins or not

### Base URI

- `setBaseURI(string memory)` - _onlyOwner_
  - owner passes a string to set the base URI for the token metadata

## Comments on Design Choices

The `addToWhitelist(address)` and `removeFromWhitelist(address)` functions could be combined into a `setWhitelist(address,bool)`, but have been separated in the interest of simplicity and readability. The same can be said for the batch add/remove and blacklist equivalents.
