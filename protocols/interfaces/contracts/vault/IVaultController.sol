//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IVaultController {

    /**
    @title IVaultController
    Controllers are smart-contract which can directly interact with thier internal balances.

    Non-controller address cannot interact directly with the internal balances and has to 
    rely on registered controllers.
    This feature allows the facilities of `Vault` to be extended in the future. Controllers implement
    their logic by utilizing the fundamental features of the `Vault`. 
     */

    /**
    @notice Returns bool -- indicating whether the provided address is a registered controller in the vault.
     */

    function isControllerInVault(address controller) external view returns(bool);
}