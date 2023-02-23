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

    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable GRANT_ACTION_ID;
    // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable REVOKE_ACTION_ID;

    // // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable GENERAL_GRANT_ACTION_ID;
    // // solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable GENERAL_REVOKE_ACTION_ID;

    //  /**
    //  * @notice An action specifier which grants a general permission to perform all variants of the base action.
    //  */
    // bytes32
    //     public constant GENERAL_PERMISSION_SPECIFIER = 
        // 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    address public constant EVERYWHERE = address(0);

    /**
     * @notice An action specifier which grants a general permission to perform all variants of the base action.
     */
    bytes32
        public constant GENERAL_PERMISSION_SPECIFIER =
             0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;


    /**
    @notice Emitted when `account` is granted permission to perform action `actionId` in target `where`
    */
    event PermissionGranted(bytes32 indexed actionId, address indexed account, address indexed where);

    /**
    @notice Emitted when `account`'s permission to perform action `actionId` in target `where` is revoked.
     */
    event PermissionRevoked(bytes32 indexed actionId, address indexed account, address indexed where);

    constructor() {
        bytes32 grantActionId = getActionId(bytes4(keccak256("grantPermissions(bytes32,address,address)")));
        bytes32 revokeActionId = getActionId(bytes4(keccak256("revokePermissions(bytes32,address,address)")));
        bytes32 generalGrantActionId = getExtendedActionId(grantActionId, GENERAL_PERMISSION_SPECIFIER);
        bytes32 generalRevokActionId = getExtendedActionId(revokeActionId, GENERAL_PERMISSION_SPECIFIER);
        GRANT_ACTION_ID = grantActionId;
        REVOKE_ACTION_ID = revokeActionId;

        

        GENERAL_GRANT_ACTION_ID = generalGrantActionId;
        GENERAL_REVOKE_ACTION_ID = generalRevokActionId;
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


    function _hasPermission(bytes32 permissionId) internal view returns(bool) {
        return _permissionRecord[permissionId] &&
            (_permissionDeadline[permissionId] == 0 ||  
            _permissionDeadline[permissionId] >= uint32(block.timestamp));
    }


    // function _hasGeneralPermission(bytes32 actionId, address account, address where) internal view returns(bool) {
    //     bytes32 generalPermissionId = getPermissionId(
    //         getExtendedActionId(actionId, GENERAL_PERMISSION_SPECIFIER), account, where);
    //     return _hasPermission(generalPermissionId);
    // }

    /**
    @notice Returns true if permission exists for actionId
     */
    function hasPermission(bytes32 actionId, address account, address where) public view returns (bool) {
        require(where != address(0) && account != address(0), "ZERO_ADDR");
        bytes32 permissionId = getPermissionId(actionId, account, where);
        return _hasPermission(permissionId);
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
    function canGrantPermission(bytes32 actionId, address account, address where ) public view returns (bool) {
        return _canPerformSpecificallyOrGenerally(GRANT_ACTION_ID, account, where, actionId);
    }

    /**
    @notice Returns true if `revoker` can grant the actionId
    */
    function canRevokePermission(bytes32 actionId, address account, address where ) public view returns (bool) {
        return _canPerformSpecificallyOrGenerally(REVOKE_ACTION_ID, account, where, actionId);
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
        require(canRevokePermission(actionId, msg.sender, where), "CNRPv");
        _revokePermission(actionId, account, where);
    }

    function canPerform(bytes32 actionId, address account, address where) public view  returns (bool) {
        bytes32 everyWherePermissionId = getPermissionId(actionId, account, EVERYWHERE);
        return (
            _hasPermission(everyWherePermissionId) || 
            hasPermission(actionId, account, where)
        );
    }


    /**
     * @notice Returns if `account` can perform the action `(baseActionId, specifier)` on target `where`.
     * @dev This function differs from `_hasPermissionSpecificallyOrGenerally` as it *does* take into account whether
     * there is a delay for the action associated with the permission being checked.
     *
     * The address `account` may have the permission associated with the provided action but that doesn't necessarily
     * mean that it may perform that action. If there is no delay associated with this action, `account` may perform the
     * action directly. If there is a delay, then `account` is instead able to schedule that action to be performed
     * at a later date.
     *
     * This function only returns true only in the first case (except for actions performed by the authorizer timelock).
     */
    function _canPerformSpecificallyOrGenerally(
        bytes32 baseActionId,
        address account,
        address where,
        bytes32 specifier
    ) internal view returns (bool) {
        // If there is a delay defined for the specific action ID, then the sender must be the authorizer (scheduled
        // execution)
        bytes32 specificActionId = getExtendedActionId(baseActionId, specifier);

        // If there is no delay, we check if the account has that permission
        if (hasPermission(specificActionId, account, where)) {
            return true;
        }

        // If the account doesn't have the explicit permission, we repeat for the general permission
        bytes32 generalActionId = getExtendedActionId(baseActionId, GENERAL_PERMISSION_SPECIFIER);
        return canPerform(generalActionId, account, where);
    }
}