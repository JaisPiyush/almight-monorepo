//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFeeCollector {

    function protocolFeePercentage() external view returns(uint256);
    function treasuryFeePercentage() external view returns(uint256);

    function collectFees(address token, uint256 amount) external;

}
