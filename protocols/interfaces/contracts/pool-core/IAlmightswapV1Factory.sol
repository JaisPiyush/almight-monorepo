//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IAlmightswapV1Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function migrator() external view returns (address);

    function getPair(address tokenA, address tokenB, uint24 fee) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function isPoolRegisterd(address pool) external view returns(bool);

    function createPair(address tokenA, address tokenB, uint24 fee) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setMigrator(address) external;
}