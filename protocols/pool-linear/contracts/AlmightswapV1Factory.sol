//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Factory.sol";
import "./AlmightswapV1Pair.sol";

contract AlmightswapV1Factory is IAlmightswapV1Factory {

    address public feeCollector;
    address public feeCollectorSetter;
    mapping(address => bool) public  isPoolRegisterd;
    address[] public override allPairs;

    constructor(address collectorSetter)  {
        feeCollectorSetter = collectorSetter;
    }

    function allPairsLength() external override view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB, uint24 fee) external returns(address pair) {
        require(tokenA != tokenB, "AlmightswapV1: IDENTICAL_ADDRESSES");
        require(tokenA != address(0) && tokenB != address(0), "AlmightswapV1: ZERO_ADDRESS");
        AlmightswapV1Pair pool = new AlmightswapV1Pair(tokenA, tokenB, fee);
        pair = address(pool);
        isPoolRegisterd[pair] = true;
        allPairs.push(pair);
        emit PairCreated(tokenA, tokenB, pair, allPairs.length);
    }

    function setFeeCollector(address feeCollector_) external override {
        require(msg.sender == feeCollectorSetter, "AlmightswapV1Factory: FORBIDDEN");
        feeCollector = feeCollector_;
    }

    function setFeeCollectorSetter(address setter) external override {
        require(msg.sender == feeCollectorSetter, "AlmightswapV1Factory: FORBIDDEN");
        feeCollectorSetter = setter;
    }
}