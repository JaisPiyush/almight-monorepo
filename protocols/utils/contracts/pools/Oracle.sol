//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;



library Oracle {

    struct TickObservation {
        /// the block timestamp of the observation
        uint32 blockTimestamp;
        /// the tick accumulator, i.e tick * time elapsed since the pool was first initialized
        int56 tickCummulative;
        /// the seconds per liquidity i.e seconds elapsed / max(!, liquidity) since the pool
        /// was initialized
        uint160 secondsPerLiquidityCumulativeX128;
    }


    function _transform(
        TickObservation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns(TickObservation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return TickObservation({
            blockTimestamp: blockTimestamp,
            tickCummulative: last.tickCummulative + int56(tick * int32(delta)),
            secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1))
        });
    }


    function initialize(TickObservation storage self, uint32 time) 
        internal  {
            self.blockTimestamp = time;
            self.tickCummulative = 0;
            self.secondsPerLiquidityCumulativeX128 = 0;
    }

    function write(
        TickObservation storage self,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) internal {
        TickObservation memory last = self;

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return;

        last = _transform(last, blockTimestamp, tick, liquidity);
        self.blockTimestamp = last.blockTimestamp;
        self.tickCummulative = last.tickCummulative;
        self.secondsPerLiquidityCumulativeX128 = last.secondsPerLiquidityCumulativeX128;
    }
}
