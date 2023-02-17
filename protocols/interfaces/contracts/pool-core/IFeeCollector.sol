//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFeeCollector {

    ///@notice Percentage of protocol fees taken.
    /// 100% = 1e6
    function protocolFeePercentage() external view returns(uint24);

}