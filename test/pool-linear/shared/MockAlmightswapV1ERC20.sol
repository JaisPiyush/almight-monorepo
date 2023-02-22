//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "../../../protocols/pool-linear/contracts/AlmightswapV1ERC20.sol";


contract MockAlmightswapV1ERC20 is AlmightswapV1ERC20 {

    constructor(uint256 tokenSupply) AlmightswapV1ERC20() {
        _mint(msg.sender, tokenSupply);
    }
}