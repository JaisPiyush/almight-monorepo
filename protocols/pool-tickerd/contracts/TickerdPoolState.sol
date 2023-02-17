//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-tickerd/ITickerdPoolState.sol";
import "@almight/contract-interfaces/contracts/pool-tickerd/ITickerdPoolImmutables.sol";
import "@almight/contract-interfaces/contracts/vault/IVault.sol";

import "@almight/contract-utils/contracts/helpers/TemporarilyPausable.sol";
import "@almight/contract-utils/contracts/pools/Tick.sol";
import "@almight/contract-utils/contracts/pools/TickBitMap.sol";
import "@almight/contract-utils/contracts/pools/Position.sol";
import "@almight/contract-utils/contracts/pools/Oracle.sol";



abstract contract TickerdPoolState is 
    TemporarilyPausable,
    ITickerdPoolState, ITickerdPoolImmutables {
    
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.TickObservation;


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
        uint160 sqrtPrixeX96;
        int24 tick;
        bool unlocked;
    }

    PoolInfo public override info;


    struct AccumulatedProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    AccumulatedProtocolFees public override protocolFees;

    mapping(int24 => Tick.Info) public override ticks;
    mapping(int16 => uint256) public override tickBitmap;
    mapping(bytes32 => Position.Info) public override positions;
    Oracle.TickObservation public  observation;


    constructor() TemporarilyPausable() {
        
    }





}