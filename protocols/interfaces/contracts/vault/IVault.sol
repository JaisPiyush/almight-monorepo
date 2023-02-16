//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "./ITokenHandler.sol";
import "./IVaultAuthorizer.sol";

interface IVault is IVaultAuthorizer, ITokenHandler {

    function getAdmin() external view returns(address);
}