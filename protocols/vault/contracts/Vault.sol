//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/vault/IVault.sol";

import "./TokenBalance.sol";
import "./TokenHandler.sol";
import "./VaultAuthorizer.sol";

contract Vault is IVault, VaultAuthorizer,
    TokenBalance,TokenHandler {


    constructor(address admin_, address wNative) 
        VaultAuthorizer(admin_)
        TokenBalance(wNative)
        TokenHandler();

}