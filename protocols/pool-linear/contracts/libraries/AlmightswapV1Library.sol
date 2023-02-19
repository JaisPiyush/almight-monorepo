//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library AlmightswapV1Library {

    function sortTokens(address tokenA, address tokenB) 
        internal 
        pure 
        returns (address token0, address token1) {
            require(tokenA != tokenB, "AlmightswapV1Library: IDENTICAL_ADDRESSES");
            (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
            require(token0 != address(0), "AlmightswapV1Library: ZERO_ADDRESS");
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "AlmightswapV1Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "AlmightswapV1Library: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "AlmightswapV1Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "AlmightswapV1Library: INSUFFICIENT_LIQUIDITY");
        uint numerator = (reserveIn * amountOut * 1000);
        uint denominator = (reserveOut - amountOut) *997;
        amountIn = (numerator / denominator) + 1;
    }


}