 //SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/utils/authorizers/IAccessAuthorizer.sol";

/**
 @title AccessAuthorizer
 @author Piyush Jaiswal (Almight)
 
 Users or Smart contracts are allowed to perform actions if they have the permission to do so.

    
 */


abstract contract AccessAuthorizer is IAccessAuthorizer {

    mapping(bytes32 => bool) private _permissionRecord;
    mapping(bytes32 => uint32) private _permissionDeadline;

    // solhint-disable-next-line func-name-mixedcase
    bytes32 public immutable GRANT_ACTION_ID;
    // solhint-disable-next-line func-name-mixedcase
    bytes32 public immutable REVOKE_ACTION_ID;

    /**
    @notice Emitted when `account` is granted permission to perform action `actionId` in target `where`
    */
    event PermissionGranted(bytes32 indexed actionId, address indexed account, address indexed where);

    /**
    @notice Emitted when `account`'s permission to perform action `actionId` in target `where` is revoked.
     */
    event PermissionRevoked(bytes32 indexed actionId, address indexed account, address indexed where);

    constructor(address admin) {
        bytes32 grantActionId = getActionId(bytes4(keccak256("grantPermissions(bytes32,address,address)")));
        bytes32 revokeActionId = getActionId(bytes4(keccak256("revokePermissions(bytes32,address,address)")));
        GRANT_ACTION_ID = grantActionId;
        REVOKE_ACTION_ID = revokeActionId;

        // Add super powers to admin for 3 months
        uint32 deadline = 3 * (30 days);
        _grantPermission(grantActionId, admin, address(this), deadline);
        _grantPermission(revokeActionId, admin, address(this), deadline);
    }


    function getActionId(bytes4 selector) public view override returns (bytes32) {
        return keccak256(abi.encodePacked(bytes32(uint256(uint160(address(this)))), selector));
    }

    /**
    @notice Returns the extended action ID for base action ID `baseActionId` with specific params `specifier`
    */

    function getExtendedActionId(bytes32 baseActionId, bytes32 specifier) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseActionId, specifier));
    }

    /**
    @notice Returns the action ID for granting permission for action `actionId`
     */
    function getGrantPermissionActionId(bytes32 actionId) public view returns (bytes32) {
        return getExtendedActionId(GRANT_ACTION_ID, actionId);
    }

    /**
    @notice Returns the action ID for granting permission for action `actionId`
    */
    function getRevokePermissionActionId(bytes32 actionId) public view returns (bytes32) {
        return getExtendedActionId(REVOKE_ACTION_ID, actionId);
    }

    /**
    @notice Returns the permission Id for action Id, account and where
     */
    function getPermissionId(bytes32 actionId, address account, address where) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(actionId, account, where));
    }

    /**
    @notice Returns true if permission exists for actionId
     */
    function hasPermission(bytes32 actionId, address account, address where) public view returns (bool) {
        require(where != address(0) && account != address(0), "ZERO_ADDR");
        bytes32 permissionId = getPermissionId(actionId, account, where);
        return (_permissionRecord[permissionId] &&
            _permissionDeadline[permissionId] == 0 ||  
            _permissionDeadline[permissionId] >= uint32(block.timestamp)
         );
    }

    /**
    @dev Grant permission to `account` for actionId on contract `where` with `deadline`
     */
    function _grantPermission(bytes32 actionId, address account, address where, uint32 deadline) 
        internal {
        bytes32 permissionId = getPermissionId(actionId, account, where);
        if (!_permissionRecord[permissionId]) {
            _permissionRecord[permissionId] = true;
            emit PermissionGranted(actionId, account, where);
        }
        if (_permissionRecord[permissionId] && _permissionDeadline[permissionId] != deadline) {
            _permissionDeadline[permissionId] = deadline;     
        }    
          
    }

    /**
    @dev Grant permission to `account` for actionId on contract `where` with `deadline` set to 0 (forever)
    */

    function _grantPermission(bytes32 actionId, address account, address where) internal {
        bytes32 permissionId = getPermissionId(actionId, account, where);
        if (!_permissionRecord[permissionId]) {
            _permissionRecord[permissionId] = true;
            _permissionDeadline[permissionId] = 0;
            emit PermissionGranted(actionId, account, where);
        }       
    }

    /**
    @dev Revoke the granted permission
    */

    function _revokePermission(bytes32 actionId, address account, address where) internal {
        bytes32 permissionId = getPermissionId(actionId, account, where);
        if (_permissionRecord[permissionId]) {
            _permissionRecord[permissionId] = false;
            emit PermissionRevoked(actionId, account, where);
        }
       
    }


    /**
    @notice Returns true if `granter` can grant the actionId
    */
    function canGrantPermission(bytes32 actionId, address granter, address where ) public view returns (bool) {
        return hasPermission(getGrantPermissionActionId(actionId), granter, where);
    }

    /**
    @notice Returns true if `revoker` can grant the actionId
    */
    function canRevokePermission(bytes32 actionId, address revoker, address where ) public view returns (bool) {
        return hasPermission(getRevokePermissionActionId(actionId), revoker, where);
    }


    function grantPermissions(bytes32 actionId, address account, address where) public  {
        //TODO: Add error code Zero Address and "CanNotGrantPermissions"
        require(where != address(0) && account != address(0), "0ADDR");
        require(canGrantPermission(actionId, msg.sender, where), "CNGPs");
        _grantPermission(actionId, account, where);
    }

    function grantPermissionsWithDeadline(bytes32 actionId, address account, address where, uint32 deadline) public  {
        require(where != address(0) && account != address(0), "0ADDR");
        require(canGrantPermission(actionId, msg.sender, where), "CNGPs");
        _grantPermission(actionId, account, where, deadline);
    }

    function revokePermissions(bytes32 actionId, address account, address where) public  {
        // TODO: add error code "CanNotRevokePermissions" and "DnHPs"
        require(where != address(0) && account != address(0), "0ADDR");
        require(hasPermission(actionId, account, where), "DnHPs");
        require(canRevokePermission(actionId, msg.sender, where), "CNRPv");
        _revokePermission(actionId, account, where);
    }

    function canPerform(bytes32 actionId, address account, address where) public view  returns (bool) {
        return hasPermission(actionId, account, where);
    }
}