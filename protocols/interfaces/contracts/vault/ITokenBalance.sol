//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ITokenBalance {

    /// @notice Returns the internal balance of the token held by the user
    function getBalance(address token, address user) external view returns(uint256);    

    /// @notice Returns bool -- indicating the spender is allowed to spend token on owner's behalf
    /// @param spender The address which can spend the amount
    /// @param owner The  address of the token owner
    /// @param token The address of the ERC20 token
    /// @param amount The amount of the token expecting to be spent
    function allowance(address spender, address owner, address token, uint256 amount) external view returns (bool);

    struct FundTransferParam {
        address spender;
        bool onlyFromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    /**
    @dev Sends `amount` of `token` to `fundTransferParam.recipient`. If the `toInternalBalance` is true, the token 
    is deposited in the internal balance of `recipient`.

    If `onlyFromInternalBalance` is true, the token will transferred only from internal balance and throws error
    if internal balance of spender holds less amount. Otherwise, it will optimistically transfer the amount 
    from the internal balance and then transfer rest of the amount from sender's personal token holdings.

    This method has to check the existance of required amount of token in spender's internal balance as well
    as personal token holdings.

    @notice The function can only be called from `UserPositionController`

    */
    function sendToken(address token, uint256 amount, FundTransferParam memory fundTransferParam) external;

    /**
    @dev Approve `spender` over `owner`'s `token` for `amount` from internal balance of the spender.
    
    @notice The function can only be called from `UserPositionController`
    */

    function approveInternalBalance(address token, address owner, address spender, uint256 amount) external;

    /// @param deadline deadline is the time limit upto which the approval is valid
    /// default deadline is `0` which means the approval is valid indefinitely
    /// 
    function approveInternalBalance(address token, address owner, 
                                    address spender, uint256 amount, uint32 deadline) external;


     



}