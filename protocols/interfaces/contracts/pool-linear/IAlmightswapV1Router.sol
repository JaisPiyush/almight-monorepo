//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAlmightswapV1Router {

    function factory() external pure returns (address);
    //solhint-disable-next-line func-name-mixedcase
    function native() external pure returns (address);

    struct AddLiquidityParam {
        // Address of tokens to be added as pairs
        address tokenA;
        // When native crypto is sent along as the pair
        // tokenB will be `address(0)`
        address tokenB;
        uint256 amountADesired;
        // Will be zero if native crypto is sent
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        // Flag indicating native crypto is sent to avoid conflicting invalid parameters
        // tokenB can be address(0) if not native crypto
        bool usingNative;
    }

    function addLiquidity(
        address to,
        uint256 deadline,
        AddLiquidityParam calldata param
    ) external payable returns (uint256 amountA, uint256 amountB, uint256 liqudiity);

    struct RemoveLiquidityParam {
        address tokenA;
        address tokenB;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
        bool usingNative;
        bool feeOnTransferToken;
        bool usingPermit;
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function removeLiqudity(
        address to,
        uint256 deadline,
        RemoveLiquidityParam calldata param
    ) external returns (uint256 amounttA, uint256 anountB);


    enum SwapType {
        ExactTokensForTokens,
        TokensForExactTokens
    }

    struct SwapParam {
        SwapType swapType;
        uint256 amountOutMin;
        uint256 amountIn;
        bool feeOnTransferToken;
    }

    function swap(
        address to,
        uint256 deadline,
        address[] calldata path,
        SwapParam calldata param
    ) external payable returns (uint256[] memory amounts);


    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) 
        external pure returns (uint256 amountB);
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) 
        external pure returns (uint256 amountOut);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) 
        external pure returns (uint256 amountIn);
    function getAmountsOut(uint256 amountIn, address[] calldata path) 
        external view returns (uint256[] memory amounts);
    function getAmountsIn(uint256 amountOut, address[] calldata path) 
        external view returns (uint256[] memory amounts);
}