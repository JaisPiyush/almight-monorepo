//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


/// @title Prevents delegatecall to a contract
abstract contract NoDelegateCall {

    ///@dev The original address of this contract
    address private immutable _original;

    constructor() {
        _original = address(this);
    }

    /// @dev Private method is used instead of inlining into modifier because modifiers are copied into each method,
    ///     and the use of immutable means the address bytes are copied in every place the modifier is used.
    function _checkNotDelegateCall() private view {
        //TODO: Add `NDC` to error code for No Delegate Call Allowed
        require(address(this) == _original, "NDC");
    }

    /// @notice Prevents delegatecall into the modified method
    modifier noDelegateCall() {
        _checkNotDelegateCall();
        _;
    }


}