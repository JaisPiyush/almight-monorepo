//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


interface IBasePool {



    /// @notice Return address of both the tokens
    function tokens() external view returns(address, address);
    /// @notice Return the balance of the both the tokens
    function balance() external view returns(uint256, uint256);

    /// @notice Return fee percentage of the pool;
    function fee() external view returns(uint256);

    struct PoolConfigInfo {
        // address of the pool deployer
        address factory;
        // address of the vault
        address vault;
        // address of the ProtocolFeeCollector
        address protocolFeeCollector;
    }
}