//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAlmightswapV1Router {

    function factory() external view returns (address);
    //solhint-disable-next-line func-name-mixedcase
    function native() external view returns (address);

    struct AddLiquidityParam {
        address pool;
        uint256 amountADesired;
        // Will be zero if native crypto is sent
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        // Flag indicating native crypto is sent to avoid conflicting invalid parameters
        // tokenB can be address(0) if not native crypto
        bool usingNative;
    }




    function createPool(address tokenA, address tokenB, uint24 fee,uint256 deadline, AddLiquidityParam memory param) 
        external payable returns (address,uint256 amountA, uint256 amountB, uint256 liqudiity);

    function addLiquidity(
        address to,
        uint256 deadline,
        AddLiquidityParam memory param
    ) external payable returns (uint256 amountA, uint256 amountB, uint256 liqudiity);

    struct RemoveLiquidityParam {
        address pool;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
        bool usingNative;
        bool usingPermit;
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function removeLiquidity(
        address to,
        uint256 deadline,
        RemoveLiquidityParam calldata param
    ) external returns (uint256 amounttA, uint256 anountB);


    struct SwapStepInfo {
        // address token0;
        // address token1;
        bool isInputZero;
        uint256 amountIn;
        uint256 amountOut;
    }

    struct SwapParam {
        /// if false that means input token is provided with amountBorder as amountOutMin
        /// if true order for required output token and amountBorder  is amountInMax
        bool requiredOut;
        // should never be zero, when native is sent should be equal to msg.value
        uint256 amount;
        uint256 amountBorder;
        bool usingNative;
        address tokenOut;        
    }

    function swap(
        address tokenIn,
        address to,
        uint256 deadline,
        // address of pools
        address[] calldata path,
        SwapParam calldata param
    ) external payable returns (SwapStepInfo[] memory steps);


    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) 
        external pure returns (uint256 amountB);
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint24 fee) 
        external pure returns (uint256 amountOut);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint24 fee) 
        external pure returns (uint256 amountIn);
    function getAmountsOut(address tokenIn, uint256 amountIn, address[] calldata path) 
        external view returns (SwapStepInfo[] memory steps);
    function getAmountsIn(address tokenOut, uint256 amountOut, address[] calldata path) 
        external view returns (SwapStepInfo[] memory steps);
}