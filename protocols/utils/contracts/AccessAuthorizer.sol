//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@almight/contract-interfaces/contracts/utils/IAccessAuthorizer.sol";

/**
 @title AccessAuthorizer
 @author Piyush Jaiswal (Almight)
 
 Users or Smart contracts are allowed to perform actions if they have the permission to do so.

 Glossary:
    - Action: Operation that can be performed to a target contract. These are identified by a unique bytes32 `actionId`
            defined by each target contract `IAccessAuthorization.getActionId`
    
 */
contract AccessAuthorizer is IAccessAuthorizer {

    mapping(bytes32 => bool) _permissionRecord;
    mapping(bytes32 => uint32) _permissionDeadline;

    address public immutable EVERYWEHRE;

    bytes32 public immutable GRANT_ACTION_ID;
    bytes32 public immutable REVOKE_ACTION_ID;

    /**
    @notice Emitted when `account` is granted permission to perform action `actionId` in target `where`
    */
    event PermissionGranted(bytes32 indexed actionId, address indexed account, address indexed where);

    /**
    @notice Emitted when `account`'s permission to perform action `actionId` in target `where` is revoked.
     */
    event PermissionRevoked(bytes32 indexed actionId, address indexed account, address indexed where);

    constructor(address admin, address everywhere) {
        EVERYWEHRE = everywhere;

        bytes32 grantActionId = getActionId(AccessAuthorizer.grantPermissions.selector);
        bytes32 revokeActionId = getActionId(AccessAuthorizer.revokePermissions.selector);
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
        uint32 timestamp = uint32(block.timestamp);
        bytes32 permissionId = getPermissionId(actionId, account, where);
        return (_permissionRecord[permissionId] &&
            _permissionDeadline[permissionId] >= timestamp || _permissionDeadline[permissionId] == 0
         ) || 
        _permissionRecord[getPermissionId(actionId, account, EVERYWEHRE)];
    }

    /**
    @dev Grant permission to `account` for actionId on contract `where` with `deadline`
     */
    function _grantPermission(bytes32 actionId, address account, address where, uint32 deadline) private {
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

    function _grantPermission(bytes32 actionId, address account, address where) private {
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

    function _revokePermission(bytes32 actionId, address account, address where) private {
        bytes32 permissionId = getPermissionId(actionId, account, where);
        if (_permissionRecord[permissionId]) {
            _permissionRecord[permissionId] = false;
            emit PermissionRevoked(actionId, account, where);
        }
       
    }


    /**
    @notice Returns true if `granter` can grant the actionId
    */
    function canGrantPermission(bytes32 actionId, address granter, address where ) internal view returns (bool) {
        return hasPermission(getGrantPermissionActionId(actionId), granter, where);
    }

    /**
    @notice Returns true if `revoker` can grant the actionId
    */
    function canRevokePermission(bytes32 actionId, address revoker, address where ) internal view returns (bool) {
        return hasPermission(getRevokePermissionActionId(actionId), revoker, where);
    }


    function grantPermissions(bytes32 actionId, address account, address where) public view {
        require(where != address(0) && account != address(0), "ZERO_ADDR");
        require(canGrantPermission(actionId, msg.sender, where), "UNAUTHORIZED");
        _grantPermission(actionId, account, where);
    }

    function grantPermissionsWithDeadline(bytes32 actionId, address account, address where, uint32 deadline) public view {
        require(where != address(0) && account != address(0), "ZERO_ADDR");
        require(canGrantPermission(actionId, msg.sender, where), "UNAUTHORIZED");
        _grantPermission(actionId, account, where, deadline);
    }

    function revokePermissions(bytes32 actionId, address account, address where) public view {
        require(where != address(0) && account != address(0), "ZERO_ADDR");
        require(canRevokePermission(actionId, msg.sender, where), "UNAUTHORIZED");
        _revokePermission(actionId, account, where);
    }

    function canPerform(bytes32 actionId, address account, address where) public view returns (bool) {
        return hasPermission(actionId, account, where);
    }
}