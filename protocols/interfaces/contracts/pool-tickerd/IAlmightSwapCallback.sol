//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


interface IAlmightSwapCallback {

    function almightSwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}