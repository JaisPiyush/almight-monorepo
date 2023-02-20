//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Pair.sol";

library AlmightswapV1Library {

    uint24 public constant FEE_LIMIT = 1e6;


    function sortTokens(address tokenA, address tokenB) 
        internal 
        pure 
        returns (address token0, address token1) {
            require(tokenA != tokenB, "AlmightswapV1Library: IDENTICAL_ADDRESSES");
            (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
            require(token0 != address(0), "AlmightswapV1Library: ZERO_ADDRESS");
    }

    function getReserves(address pool) internal view 
        returns (uint112 reserve0, uint112 reserve1) {
            (reserve0, reserve1,) = IAlmightswapV1Pair(pool).getReserves();
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
        uint256 reserveOut,
        uint24 fee
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "AlmightswapV1Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "AlmightswapV1Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = (reserveIn * amountOut *  FEE_LIMIT);
        uint256 denominator = (reserveOut - amountOut) * (FEE_LIMIT - fee);
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint24 fee
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "AlmightswapV1Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "AlmightswapV1Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn *  (FEE_LIMIT - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_LIMIT) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountsOut(
        address tokenIn,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(length >= 2, "AlmightswapLibrary: INVALID_PATH");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for(uint256 i; i < length; i++) {
            (uint112 reserve0, uint112 reserve1, address token0, , uint24 fee ) = IAlmightswapV1Pair(path[i]).info();
            (uint256 reserveIn, uint256 reserveOut) = (tokenIn == token0) ? 
                (reserve0, reserve1) : (reserve1, reserve0);
            amounts[i+1] = getAmountOut(amounts[i], reserveIn, reserveOut, fee);
        }
    }

    function getAmountsIn(
        address tokenOut,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(length >= 2, "AlmightswapLibrary: INVALID_PATH");
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = length - 1; i > 0; i--) {
            (uint112 reserve0, uint112 reserve1, address token0, , uint24 fee ) = IAlmightswapV1Pair(path[i]).info();
            (uint256 reserveIn, uint256 reserveOut) = (tokenOut != token0) ? 
                (reserve0, reserve1) : (reserve1, reserve0);
            amounts[i- 1] = getAmountIn(amounts[i], reserveIn, reserveOut, fee);
        }
    }


}