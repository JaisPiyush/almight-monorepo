//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


interface IAlmightMintCallback {

    /// @notice Called to  `msg.sender`after minting  liquidity to a position from Pool#mint.
    function almightMintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
