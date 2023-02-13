//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IAccessAuthorizer.sol";


interface ICommanderAuthorizer {

    /**
    @dev Commander is a privileged address in the contract. It hold rights to perform
    specific changes in the contract such as changing `property` or pausing the contract
    operations.
     */

    ///@notice Returns true if the user is a commander in the contract
    function isCommander(address user) external view returns(bool);

    ///@notice Returns true if the user can add new commander in the contract `where`
    function canAddCommander(address user, address where) external view returns(bool);
    ///@notice Returns true if the user can remove commander in the contract `where`
    function canRemoveCommander(address user, address where) external view returns(bool);

    ///@notice Returns true if the user can remove the `commander` from the contract `where`
    /// The privilege to remove specific commander can be granted to any pre-existing commander
    function canRemoveSpecificCommander(address user, address commander, address where) external view returns (bool);
}