//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@almight/contract-utils/contracts/authorizers/AccessAuthorizer.sol";
import "@almight/contract-utils/contracts/helpers/TemporarilyPausable.sol";
import "@almight/contract-interfaces/contracts/vault/IVaultAuthorizer.sol";


abstract contract VaultAuthorizer is 
    IVaultAuthorizer,
    AccessAuthorizer,
    TemporarilyPausable {

    mapping(address => bool) public isControllerRegisterd;

    address public admin;

    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable REGISTER_CONTROLLER_ACTION_ID;
    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable REMOVE_CONTROLLER_ACTION_ID;
    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable CHANGE_ADMIN_ACTION_ID;
    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable PAUSE_ACTION_ID;
    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable UNPAUSE_ACTION_ID;

    constructor(address admin_) AccessAuthorizer(admin_) TemporarilyPausable() {
        admin = admin_;
        REGISTER_CONTROLLER_ACTION_ID = getActionId(
            bytes4(keccak256("registerController(address)")));
        REMOVE_CONTROLLER_ACTION_ID = getActionId(
                 bytes4(keccak256("removeController(address)"))
            );
        CHANGE_ADMIN_ACTION_ID = getActionId(
                 bytes4(keccak256("changeAdmin(address)"))
        );
        PAUSE_ACTION_ID = getActionId(
                 bytes4(keccak256("pause(uint256)"))
        );
        UNPAUSE_ACTION_ID = getActionId(
                 bytes4(keccak256("unpause()"))
        );

        /// Grant permissions to admin to perform these actions
        _grantAdminPermissions(admin);

    }

    modifier canPerformAction(bytes32 actionId) {
        // TODO: Add error code "UNAUTHORIZED"
        require(canPerform(actionId, msg.sender, address(this)), "UNAUTHORIZED");
        _;
    }


    function _grantAdminPermissions(address admin_) private {
        _grantPermission(REGISTER_CONTROLLER_ACTION_ID, admin_, address(this));
        _grantPermission(REMOVE_CONTROLLER_ACTION_ID, admin_, address(this));
        _grantPermission(CHANGE_ADMIN_ACTION_ID, admin_, address(this));
        _grantPermission(PAUSE_ACTION_ID, admin_, address(this));
        _grantPermission(UNPAUSE_ACTION_ID, admin_, address(this));
    }

    function _revokeAdminPermissions(address admin_) private {
        _revokePermission(REGISTER_CONTROLLER_ACTION_ID, admin_, address(this));
        _revokePermission(REMOVE_CONTROLLER_ACTION_ID, admin_, address(this));
        _revokePermission(CHANGE_ADMIN_ACTION_ID, admin_, address(this));
        _revokePermission(PAUSE_ACTION_ID, admin_, address(this));
        _revokePermission(UNPAUSE_ACTION_ID, admin_, address(this));
    }
   
    function canRegisterController(address addr) public view returns(bool) {
        return canPerform(REGISTER_CONTROLLER_ACTION_ID, addr, address(this));
    }

    function registerController(address controller) 
        external 
        canPerformAction(REGISTER_CONTROLLER_ACTION_ID) {
            isControllerRegisterd[controller] = true;
    }

    function removeController(address controller) 
        external 
        canPerformAction(REMOVE_CONTROLLER_ACTION_ID) {
            isControllerRegisterd[controller] = false;
    }

    function changeAdmin(address admin_) external 
        canPerformAction(CHANGE_ADMIN_ACTION_ID) {
            _revokeAdminPermissions(msg.sender);
            admin = admin_;
            _grantAdminPermissions(admin_);
    }   

    function pause(uint256 duration) external 
        whenNotPaused
        canPerformAction(PAUSE_ACTION_ID) {
            _pause(duration);
    }

    function pause() external 
        whenNotPaused
        canPerformAction(PAUSE_ACTION_ID) {
            _pause(0);
    }

    function unpause() external whenPaused 
        canPerformAction(UNPAUSE_ACTION_ID) {
            _unpause();
    }



}