//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAlmightswapV1Callee {

    function almightswapV1Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external;
}