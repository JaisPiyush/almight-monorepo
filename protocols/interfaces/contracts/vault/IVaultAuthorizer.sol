//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IVaultAuthorizer {

    ///@notice Returns true if the controller is registered in the Vault
    function isControllerRegisterd(address controller) external view returns(bool);
    ///@notice Register the controller in the Vault, can only be called by specific user
    function registerController(address controller) external;
    ///@notice Returns true if the address can call `registerController`
    function canRegisterController(address) external view returns(bool);
    
    ///@notice Change the admin of the Vault.
    /// Very sensitive function
    function changeAdmin(address) external; 

    function pause(uint256 duration) external;
    function pause() external;
    function unpause() external;


}