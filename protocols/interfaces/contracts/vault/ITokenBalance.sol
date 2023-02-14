//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ITokenBalance {


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

    enum ReserveType {
        Internal,
        External,
        Both
    }

    struct FundTransferParam {
        address sender;
        ReserveType reserveType;
        address recipient;
        bool toInternalBalance;
    }

    struct AllowanceData {
        uint256 amount;
        uint32 deadline;
    }

    /**
    @dev Sends `amount` of `token` to `fundTransferParam.recipient`. If the `toInternalBalance` is true, the token 
    is deposited in the internal balance of `recipient`.
    */
    function sendToken(address token, uint256 amount, FundTransferParam memory fundTransferParam) external;

     /**
    @dev Sends `amount` of `token` to `fundTransferParam.recipient`. If the `toInternalBalance` is true, the token 
    is deposited in the internal balance of `recipient`.
    */
    function sendTokenFrom(address spender, address token, uint256 amount, 
        FundTransferParam memory fundTransferParam) external;

    ///@notice convert wrapped currency into native currency and deposit in
    /// the internal balance of the transaction sender
    function deposit() external payable;

    /// @notice Deposit the tokens from recpient to internal balance of the recpient
    /// Any ERC20 token with less then the required amount will revert the entire function
    /// Can be called directly by the user or through the `UserPositionController`.
    /// The tokens must be approved by the user for `Vault`
    function depositTokens(address recpient, address[] calldata tokens, uint256[] calldata amount) external;

    /// @notice Withdraw the tokens from recpient internal balance to the original holding of the token
    /// Can be called directly by the user or through the `UserPositionController`
    function withdrawTokens(address recpient, address[] calldata tokens, uint256[] calldata amounts) external;


 
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