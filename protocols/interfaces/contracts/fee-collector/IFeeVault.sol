//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;



interface IFeeVault {

    function transfer(address token, address to, uint256 amount) external;
    function transferFrom(address token, address owner, address to, uint256 amount) external;
    function approve(address token,address owner, address spender, uint256 amount) external;
    function increaseApprove(address token,address owner, address spender, uint256 amount) external;
    function decreaseApprove(address token,address owner, address spender, uint256 amount) external;
    function allowance(address owner, address spender, address token, uint256 amount) external view returns(uint256);
}