//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@almight/modules/openzeppelin-contracts/contracts/utils/Address.sol";
import "@almight/modules/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


contract TimelockExecutor is ReentrancyGuard {

    address public immutable authorizer;

    constructor() {
        authorizer = msg.sender;
    }

    function execute(address target, bytes memory data) 
        external nonReentrant returns (bytes memory result) {
        require(msg.sender == address(authorizer), "ERR_SENDER_NOT_AUTHORIZER");
        return Address.functionCall(target, data);
    }
}