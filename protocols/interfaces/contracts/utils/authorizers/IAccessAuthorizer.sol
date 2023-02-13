//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


interface IAccessAuthorizer {

    /**
        @dev Returns the action identifier associated with the external function described by `selector`
    */

    function getActionId(bytes4 selector) external view returns (bytes32);

    /**
     @dev Returns true if `account` can perform the action described by `actionId` in the contract `where`.
     */

    function canPerform(
        bytes32 actionId,
        address account,
        address where
    ) external view returns (bool);

}