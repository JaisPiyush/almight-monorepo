//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9; 

import "./ITokenBalance.sol";

interface ITokenHandler is ITokenBalance {

    struct FundTransferParam {
        address sender;
        ReserveType reserveType;
        address recipient;
        bool toInternalBalance;
    }

  
    enum ReserveType {
        Internal,
        External,
        Both
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

    /// @notice Deposit the tokens from msg.sender to internal balance of the msg.sender
    /// Any ERC20 token with less then the required amount will revert the entire function
    /// Can be called directly by the user or through the `UserPositionController`.
    /// The tokens must be approved by the user for `Vault`
    function depositTokens(address[] calldata tokens, uint256[] calldata amount) external;

    /// @notice Withdraw the tokens from msg.sender internal balance to the original holding of the token
    /// Can be called directly by the user or through the `UserPositionController`
    function withdrawTokens(address[] calldata tokens, uint256[] calldata amounts) external;

    /// @notice mint same as ERC20
    function mint(address account, uint256 amount) external;

    /// @notice burn same as ERC20
    function burn(address account, uint256 amount) external;
}