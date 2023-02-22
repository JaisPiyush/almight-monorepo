//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./libraries/AlmightswapV1Library.sol";
import "./libraries/TransferHelper.sol";

import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Router.sol";
import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Factory.sol";
import "@almight/contract-interfaces/contracts/utils/IWFIL.sol";

import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


contract AlmightswapV1Router is IAlmightswapV1Router {

    address public immutable override factory;
    address public immutable override native;

    modifier ensure(uint256 deadline) {
        //solhint-disable-next-line not-rely-on-time
        require(deadline >= block.timestamp, "AlmigtswapV1: EXPIRED");
        _;
    }

    constructor(address factory_, address native_ ) {
        factory = factory_;
        native = native_;
    }

    receive() external payable {
        assert(msg.sender == native);
    }

    function createPool(address tokenA, address tokenB, uint24 fee, 
        uint256 deadline, AddLiquidityParam memory param)
        external payable ensure(deadline) 
        virtual override returns (address pair, uint256 amountA, uint256 amountB, uint256 liqudiity) {
            if (tokenB == address(0)) {
                require(msg.value > 0, "AlmightswapV1Router: INSUFFICIENT_TOKEN");
                tokenB = native;
            }
            pair = IAlmightswapV1Factory(factory).createPair(tokenA, 
                tokenB, fee);
            param.pool = pair;
            (amountA, amountB, liqudiity) = addLiquidity(msg.sender, deadline, param);
    }


    function _addLiquidity(
        address pool,
        // ammountA, amountB must coincide with reserve0 and reserve1 of pool
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB)  {
        require(IAlmightswapV1Factory(factory).isPoolRegistered(pool), 
            "AlmightswapV1Router: Pool is not registerd"
        );
        (uint256 reserveA, uint256 reserveB, ) = IAlmightswapV1Pair(pool).getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        }else {
            uint256 amountBOptimal = AlmightswapV1Library.quote(amountADesired, reserveA, reserveB);
            if(amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "AlmightswapV1Router: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = AlmightswapV1Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "AlmightswapV1Router: INSUFFICIENT_A_AMOUN");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address to,
        uint256 deadline,
        AddLiquidityParam memory param
    ) public payable virtual override ensure(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
            (, , address token0, address token1, ) = IAlmightswapV1Pair(param.pool).info();
            (amountA, amountB) = _addLiquidity(
                param.pool, 
                param.amountADesired, 
                param.usingNative ? msg.value : param.amountBDesired, 
                param.amountAMin, 
                param.amountBMin
            );
            if (param.usingNative) {
                (amountA, amountB) = token1 == native? (amountA, amountB): (amountB, amountA);
            }
            TransferHelper.safeTransferFrom(token0, msg.sender, param.pool, amountA);
            if(param.usingNative) {
                IWFIL(native).deposit{value: amountB}();
                assert(IWFIL(native).transfer(param.pool, amountB));
            }else {
                TransferHelper.safeTransferFrom(token1, msg.sender, param.pool, amountB);
            }

            liquidity = IAlmightswapV1Pair(param.pool).mint(to);
            // refund dust native
            if (param.usingNative && msg.value > amountB) {
                TransferHelper.safeTransferNative(msg.sender, msg.value - amountB);
            }
    }

    function removeLiquidity(
        address to,
        uint256 deadline,
        RemoveLiquidityParam calldata param
    ) public virtual override ensure(deadline)
        returns (uint256 amountA, uint256 amountB) {
            IAlmightswapV1Pair pool = IAlmightswapV1Pair(param.pool);
            // With Permit
            if (param.usingPermit) {
                uint256 value = param.approveMax ? type(uint256).max : param.liquidity;
                pool.permit(msg.sender, address(this), value, deadline, param.v, param.r, param.s);
            }
            pool.transferFrom(msg.sender, 
                param.pool, param.liquidity
            );
            (amountA, amountB) = pool.burn(!param.usingNative ? to : address(this));
            require(amountA >= param.amountAMin, "AlmightswapV1Router: INSUFFICIENT_A_AMOUNT");
            require(amountB >= param.amountBMin, "AlmightswapV1Router: INSUFFICIENT_B_AMOUNT");
            if (param.usingNative) {
                ( , , address token0, address token1,) = pool.info();
                (amountA, amountB) = token1 == native? (amountA, amountB) : (amountB, amountA);
                TransferHelper.safeTransfer(token1 == native ? token0 : token1, to, amountA);
                IWFIL(native).withdraw(amountB); 
                TransferHelper.safeTransferNative(to, amountB);
            }         
    }

    function _swap(
        address to_,
        address[] calldata pools,
        SwapStepInfo[] memory steps
    ) internal virtual {
        uint256 length = pools.length;
        for(uint256 i;  i < length; i++) {
            uint256 amountOut = steps[i].amountOut;
            (uint256 amount0Out, uint256 amount1Out) = steps[i].isInputZero ? 
                (uint256(0), amountOut ) : (amountOut, uint256(0));
            address to = i < length - 1 ? pools[i+1] : to_;
            IAlmightswapV1Pair(pools[i]).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swap(
        // When using native token for input this must be native() address
        address tokenIn,
        address to,
        uint256 deadline,
        address[] calldata path,
        SwapParam calldata param
    ) external payable virtual override ensure(deadline) returns(SwapStepInfo[] memory steps) {
        if(param.requiredOut) {
            require(param.tokenOut != address(0), "AlmightswapV1Router: INVALID_OUT");
        }
        steps = !param.requiredOut ? 
            AlmightswapV1Library.getAmountsOut(tokenIn, param.amount, path) : 
            AlmightswapV1Library.getAmountsIn(param.tokenOut, param.amount, path);
        
        if (param.requiredOut) {
            require(steps[0].amountIn <= param.amountBorder, "AlmightswapV1Router: EXCESSIVE_INPUT_AMOUN");
        }else {
            require(steps[steps.length - 1].amountOut >= param.amountBorder, 
                "AlmightswapV1Router: INSUFFICIENT_OUTPUT_AMOUNT"
            );
        }
        if(param.usingNative && !param.requiredOut && tokenIn == native) {
            require(msg.value >= steps[0].amountIn, "AlmightswapV1Router: INSUFFICIENT_TOKEN");
            IWFIL(native).deposit{value: steps[0].amountIn}();
            assert(IWFIL(native).transfer(path[0], steps[0].amountIn));
        }else {
            TransferHelper.safeTransferFrom(tokenIn, msg.sender, path[0], steps[0].amountIn);
        }
        
        address to_ = param.usingNative && param.requiredOut ? address(this): to;
        _swap(to_, path, steps);
        if (param.usingNative && param.requiredOut) {
            IWFIL(native).withdraw(steps[steps.length - 1].amountOut);
            TransferHelper.safeTransferNative(to, steps[steps.length - 1].amountOut);
        }


    }

    function quote( uint256 amountA, uint256 reserveA, uint256 reserveB) external pure 
        virtual override returns (uint256) {
            return AlmightswapV1Library.quote(amountA, reserveA, reserveB);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint24 fee) external pure    
        virtual override returns(uint256) {
            return AlmightswapV1Library.getAmountOut(amountIn, reserveIn, reserveOut, fee);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint24 fee)
        external pure virtual override returns(uint256) {
            return AlmightswapV1Library.getAmountIn(amountOut, reserveIn, reserveOut, fee);
    }

    function getAmountsOut(address tokenIn, uint256 amountIn, address[] calldata pools)
        external view virtual override returns(SwapStepInfo[] memory steps) {
            return AlmightswapV1Library.getAmountsOut(tokenIn, amountIn, pools);
    }

    function getAmountsIn(address tokenOut, uint256 amountOut, address[] calldata pools)
        external view virtual override returns(SwapStepInfo[] memory steps) {
            return AlmightswapV1Library.getAmountsIn(tokenOut, amountOut, pools);
    }





}


