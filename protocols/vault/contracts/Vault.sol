//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/vault/IVault.sol";

import "./TokenHandler.sol";
import "./VaultAuthorizer.sol";


contract Vault is VaultAuthorizer, TokenHandler, IVault {

    constructor(address admin_, address wNative) 
        VaultAuthorizer(admin_) TokenHandler(wNative) {}
    
    function getAdmin() public view returns(address) {
        return admin;
    }
}
