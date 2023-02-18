//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-tickerd/ITickerdPoolState.sol";
import "@almight/contract-interfaces/contracts/pool-tickerd/ITickerdPoolImmutables.sol";
import "@almight/contract-interfaces/contracts/vault/IVault.sol";

import "@almight/contract-utils/contracts/helpers/ControlledTemporarilyPausable.sol";
import "@almight/contract-utils/contracts/pools/Tick.sol";
import "@almight/contract-utils/contracts/pools/TickBitMap.sol";
import "@almight/contract-utils/contracts/pools/Position.sol";
import "@almight/contract-utils/contracts/pools/Oracle.sol";



abstract contract TickerdPoolState is 
    ITickerdPoolState, 
    ITickerdPoolImmutables,
    ControlledTemporarilyPausable
    {
    
    


    address public immutable vault;
        
    address public immutable factory;
    /// @notice token pair of the swap
    address public immutable token0;
    address public immutable token1;
    /// @notice swap fee (100% = 10,00,000)
    uint24 public immutable override fee;

    int24 public immutable override tickSpacing;

    uint128 public immutable override maxLiquidityPerTick;

    uint128 public override liquidity;
    uint256 public override feeGrowthGlobal0X128;
    uint256 public override feeGrowthGlobal1X128;


    struct PoolInfo {
        uint160 sqrtPriceX96;
        int24 tick;
        bool unlocked;
    }

    PoolInfo public override info;


    struct AccumulatedProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    AccumulatedProtocolFees public override protocolFees;

    
    


    constructor(
        address vault_,
        address factory_,
        address token0_,
        address token1_,
        uint24 fee_,
        int24 tickSpacing_
    ) ControlledTemporarilyPausable(vault_) {
        vault = vault_;
        factory = factory_;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
        tickSpacing = tickSpacing_;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing_);
        
    }

    

    function reserves() public view returns(uint256 balance0, uint256 balance1) {
        balance0 = IVault(vault).getBalance(token0, address(this));
        balance1 = IVault(vault).getBalance(token1, address(this));
    }


}