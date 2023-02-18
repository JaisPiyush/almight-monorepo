//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ITickerdPoolDerivedState {

    function observe()
        external view
        returns (int56 tickCummulatives, uint160 secondsPerLiquidityCumulativeX128);
    

    function snapshotCummulativeInside(int24 lower, int24 upper)
        external
        view
        returns (
            int56 tickCummulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
    
    
    
}