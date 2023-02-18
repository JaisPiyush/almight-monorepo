//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ITokenBalance {

    /// @notice total supply of token held by the vaul
    function totalSupply(address token) external view returns(uint256);

    /// @notice Returns the internal balance of the token held by the user
    function getBalance(address token, address user) external view returns(uint256);    

    /// @notice Returns balance of multiple tokens in single call
    function getInternalBalance(address owner, address[] calldata tokens) external view returns (uint256[] memory);

    ///@notice Returns address of all the tokens held in the internal balance by the owner
    function getAddressTokens(address owner) external view returns (address[] memory);
    /// @notice Returns bool -- indicating the spender is allowed to spend token on owner's behalf
    /// @param spender The address which can spend the amount
    /// @param owner The  address of the token owner
    /// @param token The address of the ERC20 token
    /// @param amount The amount of the token expecting to be spent
    function allowance(address spender, address owner, address token, uint256 amount) external view returns (bool);

   

    struct AllowanceData {
        uint256 amount;
        uint32 deadline;
    }

    ///@dev Approve `spender` over `owner`'s `token` for `amount` from internal balance of the spender.
    function approve(address token, address spender, uint256 amount) external;


    /// @param deadline deadline is the time limit upto which the approval is valid
    /// default deadline is `0` which means the approval is valid indefinitely
    function approve(address token, 
                                    address spender, uint256 amount, uint32 deadline) external;


    /// @notice Increase approved amount
    function approveIncrease(address token, address spender, uint256 amount) external;
    ///@notice Decrease approved amount upto 0
    function approveDecrease(address token, address spender, uint256 amount) external;

    function revokeAllowance(address token, address spender) external;



}