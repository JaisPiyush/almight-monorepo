//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9; 

import "./TokenBalance.sol";
abstract contract TokenHandler is TokenBalance {

    event Deposit(address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed recp, address indexed token, uint256 amount);
    event Transfer(address indexed sender, ReserveType indexed reserveType,
                   address indexed recipient, bool toInternalBalance, uint256 amount
    );


    function sendTokenFrom(address spender, address token, uint256 amount, 
            FundTransferParam calldata  fundTransferParam
        ) public whenNotPaused nonReentrant {
            require(fundTransferParam.sender != address(0), "0ADDR");
            if(fundTransferParam.reserveType == ReserveType.Internal) {
                //TODO: Add error code "SenderNotApproved"
                require(allowance(spender, 
                    fundTransferParam.sender, token, amount), "SPNA");
                //TODO: Add error code "InsufficientAmount"
                require(getBalance(fundTransferParam.sender, token) >= amount, "INSA");
                // Decrease token expenditure allowance for msg.sender
                if (msg.sender != fundTransferParam.sender) {
                    approveDecrease(token, msg.sender, amount);
                }
                // Internal Balance to Internal Balance transfer
                if(fundTransferParam.toInternalBalance) {
                    require(fundTransferParam.sender != fundTransferParam.recipient, "CIRCULAR_TRANSFER");
                    
                    _decreaseInternalBalance(fundTransferParam.sender, token, amount);
                    _increaseInternalBalance(fundTransferParam.recipient, token, amount);

                }else {
                    // Internal Balance to External 
                    // Decrease the internal token balance of the sender
                    _decreaseInternalBalance(fundTransferParam.sender, token, amount);
                    // Transfer token from Vault to recpient
                    IERC20(token).transfer(fundTransferParam.recipient, amount);

                    if (fundTransferParam.sender == fundTransferParam.recipient) {
                        emit Withdraw(fundTransferParam.recipient, token, amount);
                        return;
                    }
                }
            }else if(fundTransferParam.reserveType == ReserveType.External) {

                // External to Internal
                if (fundTransferParam.toInternalBalance) {
                    // Increase the internal balance of recp
                    _increaseInternalBalance(fundTransferParam.recipient, token, amount);
                    // Transfer token from `senders` balance to the vault
                    IERC20(token).transferFrom(fundTransferParam.sender, address(this), amount);

                    if (fundTransferParam.sender == fundTransferParam.recipient) {
                        emit Deposit(fundTransferParam.recipient, token, amount);
                        return;
                    }

                }else {
                    require(fundTransferParam.sender != fundTransferParam.recipient, "CIRCULAR_TRANSFER");
                    // External to External
                     IERC20(token).transferFrom(fundTransferParam.sender, fundTransferParam.recipient, amount);
                }
            }else if(fundTransferParam.reserveType == ReserveType.Both) {
                if (fundTransferParam.toInternalBalance) {
                    require(fundTransferParam.sender != fundTransferParam.recipient, "CIRCULAR_TRANSFER");
                    // Check for allowance to spend sender's token
                    uint256 _balance = getBalance(fundTransferParam.sender, token);
                    require(allowance(spender, 
                        fundTransferParam.sender, token, 
                        amount <= _balance ? amount: _balance
                    ), "SPNA");
                    uint256 delta = _decreaseInternalBalance(
                        fundTransferParam.sender, token, amount
                    );
                    // Decrease token expenditure allowance for msg.sender
                    if (msg.sender != fundTransferParam.sender) {
                        approveDecrease(token, msg.sender, amount);
                    }
                    _increaseInternalBalance(fundTransferParam.recipient, token, amount);

                    if (delta > 0) {
                        IERC20(token).transferFrom(fundTransferParam.sender, address(this), delta);
                    }
                }else {
                    require(allowance(spender, 
                        fundTransferParam.sender, token, amount), "SPNA");
                    uint256 delta = _decreaseInternalBalance(
                        fundTransferParam.sender, token, amount - delta
                    );
                    // Decrease token expenditure allowance for msg.sender
                    if (msg.sender != fundTransferParam.sender) {
                        approveDecrease(token, msg.sender, amount - delta);
                    }
                    // Transfer token from Vault to recpient
                    IERC20(token).transfer(fundTransferParam.recipient, amount);
                    IERC20(token).transferFrom(fundTransferParam.sender, fundTransferParam.recipient, delta);

                }
            }
            emit Transfer(fundTransferParam.sender, fundTransferParam.reserveType, 
                                fundTransferParam.recipient, fundTransferParam.toInternalBalance,
                                amount
                        );
            }

    }


    function sendToken(address token, uint256 amount, FundTransferParam memory fundTransferParam) external {
        sendTokenFrom(msg.sender, token, amount, fundTransferParam);    11
    }




    function deposit() external payable whenNotPaused noReentrant {
        require(msg.value > 0, "INSA");
        _increaseInternalBalance(msg.sender, WRAPPED_NATIVE. msg.value); 
        IWFIL(WRAPPED_NATIVE).deposit{value: msg.value}();     
    }


    function depositTokens(address recipient, address[] calldata tokens, uint256[] calldata amounts) 
        external whentNotPaused noReentrant {
            require(tokens.length == amounts.length, "INCORRECT_DATA");
            for(uint256 i = 0; i < tokens.length; i++) {
                sendToken(tokens[i], amounts[i], FundTransferParam(
                    msg.sender,
                    ReserveType.External,
                    owner,
                    true
                ));
            }
    }


    function withdrawTokens(address recipient, address[] calldata tokens, uint256[] calldata amounts )
        external whentNotPaused noReentrant {
            require(tokens.length == amounts.length, "INCORRECT_DATA");
            for(uint256 i = 0; i < tokens.length; i++) {
                sendToken(tokens[i], amounts[i], FundTransferParam(
                    msg.sender,
                    ReserveType.Internal,
                    owner,
                    false
                ));
            }

    }


}