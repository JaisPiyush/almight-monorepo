//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-tickerd/IAlmightSwapCallback.sol";
import "@almight/contract-interfaces/contracts/pool-tickerd/IAlmightMintCallback.sol";

import "@almight/contract-interfaces/contracts/pool-tickerd/ITickerdPool.sol";

import "@almight/contract-interfaces/contracts/pool-core/IAlmightPoolFactory.sol"; 

import "@almight/contract-utils/contracts/pools/SqrtPriceMath.sol";
import "@almight/contract-utils/contracts/pools/LiquidityMath.sol";
import "@almight/contract-utils/contracts/pools/SwapMath.sol";
import "@almight/contract-utils/contracts/pools/TickMath.sol";
import "@almight/contract-utils/contracts/helpers/NoDelegateCall.sol";

import "./TickerdPoolState.sol";

contract TickerdPool is 
    ITickerdPoolDerivedState, 
    ITickerdPoolEvents, 
    ITickerdPoolActions, 
    TickerdPoolState, 
    NoDelegateCall {

        using Tick for mapping(int24 => Tick.Info);
        using TickBitmap for mapping(int16 => uint256);
        using Position for mapping(bytes32 => Position.Info);
        using Position for Position.Info;
        using Oracle for Oracle.TickObservation;

        mapping(int24 => Tick.Info) public override ticks;
        mapping(int16 => uint256) public override tickBitmap;
        mapping(bytes32 => Position.Info) public override positions;
        Oracle.TickObservation private  _observation;


        // @dev Mutually exclusive reentrancy protection into the pool to/from a method. 
        /// This method also prevents entrance to a function before the pool is initialized. 
        /// The reentrancy guard is required throughout the contract because
        /// we use balance checks to determine the payment status of interactions such as mint, 
        /// swap and flash.
        modifier lock() {
            require(info.unlocked, "LOK");
            info.unlocked = false;
            _;
            info.unlocked = true;
        }


        function balance0() public view returns(uint256) {
            return IVault(vault).getBalance(token0, address(this));
        }

        function balance1() public view returns(uint256) {
             return IVault(vault).getBalance(token1, address(this));
        }


        /// @dev Common checks for valid tick inputs.
        function _checkTicks(int24 tickLower, int24 tickUpper) private pure {
            require(tickLower < tickUpper, "TLU");
            require(tickLower >= TickMath.MIN_TICK, "TLM");
            require(tickUpper <= TickMath.MAX_TICK, "TUM");
        }

        function observe() 
            public view
            returns (int56 tickCummulatives, uint160 secondsPerLiquidityCumulativeX128) {
                return _observation.observe();
        }

        function snapshotCummulativeInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCummulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        ) {
            _checkTicks(tickLower, tickUpper);
            int56 tickCumulativeLower;
            int56 tickCumulativeUpper;
            uint160 secondsPerLiquidityOutsideLowerX128;
            uint160 secondsPerLiquidityOutsideUpperX128;
            uint32 secondsOutsideLower;
            uint32 secondsOutsideUpper;
            {
                Tick.Info storage lower = ticks[tickLower];
                Tick.Info storage upper = ticks[tickUpper];
                bool initializedLower;
                (tickCumulativeLower, secondsPerLiquidityOutsideLowerX128, secondsOutsideLower, initializedLower) = (
                    lower.tickCumulativeOutside,
                    lower.secondsPerLiquidityOutsideX128,
                    lower.secondsOutside,
                    lower.initialized
                );
                ///TODO: Add error code "UnInitialisedLowerTick"
                require(initializedLower, "UILT");

                bool initializedUpper;
                (tickCumulativeUpper, secondsPerLiquidityOutsideUpperX128, secondsOutsideUpper, initializedUpper) = (
                    upper.tickCumulativeOutside,
                    upper.secondsPerLiquidityOutsideX128,
                    upper.secondsOutside,
                    upper.initialized
                );
                require(initializedUpper, "UIUT");
            }
            PoolInfo memory _slot0 = info;
            if (_slot0.tick < tickLower) {
                return (
                    tickCumulativeLower - tickCumulativeUpper,
                    secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
                    secondsOutsideLower - secondsOutsideUpper
                );
            } else if (_slot0.tick < tickUpper) {
                uint32 time = uint32(block.timestamp);
                (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) = observe();
                return (
                    tickCumulative - tickCumulativeLower - tickCumulativeUpper,
                    secondsPerLiquidityCumulativeX128 -
                        secondsPerLiquidityOutsideLowerX128 -
                        secondsPerLiquidityOutsideUpperX128,
                    time - secondsOutsideLower - secondsOutsideUpper
                )   ;
            } else {
                return (
                    tickCumulativeUpper - tickCumulativeLower,
                    secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
                    secondsOutsideUpper - secondsOutsideLower
                );
            }

        }


        function initialize(uint160 sqrtPriceX96) external override {
            //TODO: Add error code to "AlreadyInitialized"
            require(info.sqrtPriceX96 == 0, "AI"); 

            int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
            info = PoolInfo({
                sqrtPriceX96: sqrtPriceX96,
                tick: tick,
                unlocked: true
            });
        }

        struct ModifyPositionParams {
            // the adress that owns the position
            address owner;
            // the lower and upper tick of the position
            int24 tickLower;
            int24 tickUpper;
            // any change in liquidity
            int128 liquidityDelta;
        }

        /// @dev Effect some changes to a position
        /// @param params the position details and the change to the position's liquidity to effect
        /// @return position a storage pointer referencing the position with the given owner and tick range
        /// @return amount0 the amount of token0 owed to the pool, negative if the pool should pay the recipient
        /// @return amount1 the amount of token1 owed to the pool, negative if the pool should pay the recipient
        function _modifyPosition(ModifyPositionParams memory params)
            private
            noDelegateCall
            returns (
                Position.Info storage position,
                int256 amount0,
                int256 amount1
            )
        {
            _checkTicks(params.tickLower, params.tickUpper);

            PoolInfo memory _slot0 = info; // SLOAD for gas optimization

            position = _updatePosition(
                params.owner,
                params.tickLower,
                params.tickUpper,
                params.liquidityDelta,
                _slot0.tick
            );

            if (params.liquidityDelta != 0) {
                if (_slot0.tick < params.tickLower) {
                    // current tick is below the passed range; liquidity can only become 
                    // in range by crossing from left to right, when we'll need 
                    //_more_ token0 (it's becoming more valuable) so user must provide it
                    amount0 = SqrtPriceMath.getAmount0Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower),
                        TickMath.getSqrtRatioAtTick(params.tickUpper),
                        params.liquidityDelta
                    );
                } else if (_slot0.tick < params.tickUpper) {
                    // current tick is inside the passed range
                    uint128 liquidityBefore = liquidity; // SLOAD for gas optimization

                    // write an oracle entry
                    _observation.write(
                        uint32(block.timestamp),
                        _slot0.tick,
                        liquidityBefore
                    );

                    amount0 = SqrtPriceMath.getAmount0Delta(
                        _slot0.sqrtPriceX96,
                        TickMath.getSqrtRatioAtTick(params.tickUpper),
                        params.liquidityDelta
                    );
                    amount1 = SqrtPriceMath.getAmount1Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower),
                        _slot0.sqrtPriceX96,
                        params.liquidityDelta
                    );

                    
                    liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
                } else {
                    // current tick is above the passed range; liquidity can only become 
                    //in range by crossing from right to
                    // left, when we'll need _more_ token1 (it's becoming more valuable) so user must provide it
                    amount1 = SqrtPriceMath.getAmount1Delta(
                        TickMath.getSqrtRatioAtTick(params.tickLower),
                        TickMath.getSqrtRatioAtTick(params.tickUpper),
                        params.liquidityDelta
                    );
                }
            }
        }

        /// @dev Gets and updates a position with the given liquidity delta
        /// @param owner the owner of the position
        /// @param tickLower the lower tick of the position's tick range
        /// @param tickUpper the upper tick of the position's tick range
        /// @param tick the current tick, passed to avoid sloads
        function _updatePosition(
            address owner,
            int24 tickLower,
            int24 tickUpper,
            int128 liquidityDelta,
            int24 tick
        ) private returns (Position.Info storage position) {
            position = positions.get(owner, tickLower, tickUpper);

            uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
            uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

            // if we need to update the ticks, do it
            bool flippedLower;
            bool flippedUpper;
            if (liquidityDelta != 0) {
                uint32 time = uint32(block.timestamp);
                (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) = observe();

                flippedLower = ticks.update(
                    tickLower,
                    tick,
                    liquidityDelta,
                    _feeGrowthGlobal0X128,
                    _feeGrowthGlobal1X128,
                    secondsPerLiquidityCumulativeX128,
                    tickCumulative,
                    time,
                    false,
                    maxLiquidityPerTick
                );
                flippedUpper = ticks.update(
                    tickUpper,
                    tick,
                    liquidityDelta,
                    _feeGrowthGlobal0X128,
                    _feeGrowthGlobal1X128,
                    secondsPerLiquidityCumulativeX128,
                    tickCumulative,
                    time,
                    true,
                    maxLiquidityPerTick
                );

                if (flippedLower) {
                    tickBitmap.flipTick(tickLower, tickSpacing);
                }
                if (flippedUpper) {
                    tickBitmap.flipTick(tickUpper, tickSpacing);
                }
            }

            (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(
                tickLower,
                tickUpper,
                tick,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128
            );

            position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

            // clear any tick data that is no longer needed
            if (liquidityDelta < 0) {
                if (flippedLower) {
                    ticks.clear(tickLower);
                }
                if (flippedUpper) {
                    ticks.clear(tickUpper);
                }
            }
        }


        /// @dev noDelegateCall is applied indirectly via _modifyPosition
        function mint(
            address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
        ) external override lock returns (uint256 amount0, uint256 amount1) {
            require(amount > 0, "0LIQ");
            uint128 lastLiquidity = liquidity;
            (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int128(amount)
                })
            );

            amount0 = uint256(amount0Int);
            amount1 = uint256(amount1Int);

            uint256 balance0Before;
            uint256 balance1Before;
            if (amount0 > 0) balance0Before = balance0();
            if (amount1 > 0) balance1Before = balance1();
            IAlmightMintCallback(msg.sender).almightMintCallback(amount0, amount1, data);
            if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), "M0");
            if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), "M1");
            ///TODO" Mint the LP tokens

            emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
        }


        function collect(
            address recipient,
            int24 tickLower,
            int24 tickUpper,
            uint128 amount0Requested,
            uint128 amount1Requested
        ) external override lock returns (uint128 amount0, uint128 amount1) {
            // we don't need to checkTicks here, because invalid positions will never have non-zero tokensOwed{0,1}
            Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

            amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
            amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

            if (amount0 > 0) {
                position.tokensOwed0 -= amount0;
                TransferHelper.safeTransfer(token0, recipient, amount0);
            }
            if (amount1 > 0) {
                position.tokensOwed1 -= amount1;
                TransferHelper.safeTransfer(token1, recipient, amount1);
            }



            emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
        }

        /// @dev noDelegateCall is applied indirectly via _modifyPosition
        function burn(
            int24 tickLower,
            int24 tickUpper,
            uint128 amount
        ) external override lock returns (uint256 amount0, uint256 amount1) {
            (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int128(amount)
                })
            );

            amount0 = uint256(-amount0Int);
            amount1 = uint256(-amount1Int);

            if (amount0 > 0 || amount1 > 0) {
                (position.tokensOwed0, position.tokensOwed1) = (
                    position.tokensOwed0 + uint128(amount0),
                    position.tokensOwed1 + uint128(amount1)
                );
            }

            emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
        }

        struct SwapCache {
            // the protocol fee for the input token
            uint8 feeProtocol;
            // liquidity at the beginning of the swap
            uint128 liquidityStart;
            // the timestamp of the current block
            uint32 blockTimestamp;
            // the current value of the tick accumulator, computed only if we cross an initialized tick
            int56 tickCumulative;
            // the current value of seconds per liquidity accumulator, computed only if we cross an initialized tick
            uint160 secondsPerLiquidityCumulativeX128;
            // whether we've computed and cached the above two accumulators
            bool computedLatestObservation;
        }

        // the top level state of the swap, the results of which are recorded in storage at the end
        struct SwapState {
            // the amount remaining to be swapped in/out of the input/output asset
            int256 amountSpecifiedRemaining;
            // the amount already swapped out/in of the output/input asset
            int256 amountCalculated;
            // current sqrt(price)
            uint160 sqrtPriceX96;
            // the tick associated with the current price
            int24 tick;
            // the global fee growth of the input token
            uint256 feeGrowthGlobalX128;
            // amount of input token paid as protocol fee
            uint128 protocolFee;
            // the current liquidity in range
            uint128 liquidity;
        }

        struct StepComputations {
            // the price at the beginning of the step
            uint160 sqrtPriceStartX96;
            // the next tick to swap to from the current tick in the swap direction
            int24 tickNext;
            // whether tickNext is initialized or not
            bool initialized;
            // sqrt(price) for the next tick (1/0)
            uint160 sqrtPriceNextX96;
            // how much is being swapped in in this step
            uint256 amountIn;
            // how much is being swapped out
            uint256 amountOut;
            // how much fee is being paid in
            uint256 feeAmount;
        }

    
        function swap(
            address recipient,
            bool zeroForOne,
            int256 amountSpecified,
            uint160 sqrtPriceLimitX96,
            bytes calldata data
        ) external override noDelegateCall returns (int256 amount0, int256 amount1) {
            require(amountSpecified != 0, "AS");

            PoolInfo memory slot0Start = info;

            require(slot0Start.unlocked, "LOK");
            require(
                zeroForOne
                    ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && 
                        sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                    : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && 
                        sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
                "SPL"
            );

            info.unlocked = false;

            SwapCache memory cache = SwapCache({
                liquidityStart: liquidity,
                blockTimestamp: uint32(block.timestamp),
                feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
                secondsPerLiquidityCumulativeX128: 0,
                tickCumulative: 0,
                computedLatestObservation: false
            });

            bool exactInput = amountSpecified > 0;

            SwapState memory state = SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: slot0Start.sqrtPriceX96,
                tick: slot0Start.tick,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

            // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
            while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
                StepComputations memory step;

                step.sqrtPriceStartX96 = state.sqrtPriceX96;

                (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                    state.tick,
                    tickSpacing,
                    zeroForOne
                );

                // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
                if (step.tickNext < TickMath.MIN_TICK) {
                    step.tickNext = TickMath.MIN_TICK;
                } else if (step.tickNext > TickMath.MAX_TICK) {
                    step.tickNext = TickMath.MAX_TICK;
                }

                // get the price for the next tick
                step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

                // compute values to swap to the target tick, price limit, 
                // or point where input/output amount is exhausted
                (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                    state.sqrtPriceX96,
                    (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : 
                        step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                        ? sqrtPriceLimitX96
                        : step.sqrtPriceNextX96,
                    state.liquidity,
                    state.amountSpecifiedRemaining,
                    fee
                );

                if (exactInput) {
                    state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                    state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
                } else {
                    state.amountSpecifiedRemaining += step.amountOut.toInt256();
                    state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
                }

                // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
                if (cache.feeProtocol > 0) {
                    uint256 delta = step.feeAmount / cache.feeProtocol;
                    step.feeAmount -= delta;
                    state.protocolFee += uint128(delta);
                }

                // update global fee tracker
                if (state.liquidity > 0)
                    state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

                // shift tick if we reached the next price
                if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                    // if the tick is initialized, run the tick transition
                    if (step.initialized) {
                        // check for the placeholder value, which we replace with the actual value the first time the swap
                        // crosses an initialized tick
                        if (!cache.computedLatestObservation) {
                            (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observe();
                            cache.computedLatestObservation = true;
                        }
                        int128 liquidityNet = ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulativeX128,
                            cache.tickCumulative,
                            cache.blockTimestamp
                        );
                        // if we're moving leftward, we interpret liquidityNet as the opposite sign
                        // safe because liquidityNet cannot be type(int128).min
                        if (zeroForOne) liquidityNet = -liquidityNet;

                        state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                    }

                    state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
                } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                    // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), 
                    // and haven't moved
                    state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
                }
            }   

            // update tick and write an oracle entry if the tick change
            if (state.tick != slot0Start.tick) {
                (uint16 observationIndex, uint16 observationCardinality) = _observation.write(
                    cache.blockTimestamp,
                    slot0Start.tick,
                    cache.liquidityStart
                );
                (info.sqrtPriceX96, info.tick) = (
                state.sqrtPriceX96,
                state.tick
                );
            } else {
                // otherwise just update the price
                info.sqrtPriceX96 = state.sqrtPriceX96;
            }

            // update liquidity if it changed
            if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

            // update fee growth global and, if necessary, protocol fees
            // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
            if (zeroForOne) {
                feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
                if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
            } else {
                feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
                if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
            }

            (amount0, amount1) = zeroForOne == exactInput
                ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

            // do the transfers and collect payment
            if (zeroForOne) {
                if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

                uint256 balance0Before = balance0();
                IAlmightSwapCallback(msg.sender).almightSwapCallback(amount0, amount1, data);
                require(balance0Before.add(uint256(amount0)) <= balance0(), "IIA");
            } else {
                if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

                uint256 balance1Before = balance1();
                IAlmightSwapCallback(msg.sender).almightSwapCallback(amount0, amount1, data);
                require(balance1Before.add(uint256(amount1)) <= balance1(), "IIA");
        }

            emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
            info.unlocked = true;
        }

}