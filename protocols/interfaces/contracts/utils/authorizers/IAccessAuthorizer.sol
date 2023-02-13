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


    ///@notice grants permission to `account` for `actionId` on the contract `where`
    /// `msg.sender` must hold permission to grant permission for actionId.
    function grantPermissions(bytes32 actionId, address account, 
            address where) external;
    
    ///@notice grants permission with deadline
    function grantPermissionsWithDeadline(bytes32 actionId, address account, 
        address where, uint32 deadline) external;

    /// @notice revokes permission from `account` to perform `actionId` on contract `where`
    function revokePermissions(bytes32 actionId, address account, address where) external;


    ///@notice Returns true if `granter` can grant permission for `actionId` on contract `where`
    function canGrantPermission(bytes32 actionId, 
    address granter, address where ) external view returns (bool);


    ///@notice Returns true if `revoker` can revoke permission for `actionId` on contract `where`
    function canRevokePermission(bytes32 actionId, 
    address revoker, address where ) external view returns (bool);

}