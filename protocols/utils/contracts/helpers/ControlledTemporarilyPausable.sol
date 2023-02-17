//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./TemporarilyPausable.sol";
import "@almight/contract-interfaces/contracts/utils/authorizers/IAccessAuthorizer.sol";

abstract contract ControlledTemporarilyPausable is TemporarilyPausable {

    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable PAUSE_ACTION_ID;
    //solhint-disable-next-line var-name-mixedcase
    bytes32 public immutable UNPAUSE_ACTION_ID;

    address public immutable authorizer;

     constructor(address authorizer_) TemporarilyPausable() {
        authorizer = authorizer_ == address(0) ? address(this) : authorizer_;
        PAUSE_ACTION_ID = IAccessAuthorizer(authorizer).getActionId(
                 bytes4(keccak256("pause(uint256)"))
        );
        UNPAUSE_ACTION_ID = IAccessAuthorizer(authorizer).getActionId(
                 bytes4(keccak256("unpause()"))
        );
    }


    function _pause(uint256 duration) internal override
        whenNotPaused
         {
            require(IAccessAuthorizer(authorizer).canPerform(PAUSE_ACTION_ID, msg.sender, 
             address(this)), "UNAUTHORIZED");
            super._pause(duration);
    }

    function _pause() internal override 
        whenNotPaused
         {
            require(IAccessAuthorizer(authorizer).canPerform(PAUSE_ACTION_ID, msg.sender, 
            address(this)), "UNAUTHORIZED");
            super._pause(0);
    }

    function _unpause() internal override whenPaused 
         {
            require(IAccessAuthorizer(authorizer).canPerform(UNPAUSE_ACTION_ID, msg.sender,
             address(this)), "UNAUTHORIZED");
            super._unpause();
    }
}