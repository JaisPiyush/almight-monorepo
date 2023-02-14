//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/vault/ITokenBalance.sol";
import "@almight/contract-utils/contracts/helpers/TemporarilyPausable.sol";
import "@almight/contract-interfaces/contracts/IWFIL.sol";

import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@almight/modules/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

abstract contract TokenBalance is ITokenBalance, TemporarilyPausable, ReentrancyGuard {


    address public immutable WRAPPED_NATIVE;



    constructor(address wrappedNative) TemporarilyPausable(0) {
        WRAPPED_NATIVE = wrappedNative;
    }


    mapping(address => mapping(address => uint256)) private _internalBalances;
    mapping(address => address[]) private _tokenHoldings;
    mapping(address => mapping(address => bool)) _tokenHoldingsRecord;
    mapping(address => mapping(address => mapping(address => AllowanceData))) private _allowance;


    event Approval(address indexed owner, address indexed spender, 
        address indexed token, uint256 amount);
    
    event Deposit(address indexed owner, address indexed token, uint256 amount);
    event Withdraw(address indexed recp, address indexed token, uint256 amount);
    event Transfer(address indexed sender, ReserveType indexed reserveType,
                   address indexed recipient, bool toInternalBalance, uint256 amount
    );


    function getBalance(address owner, address token) public view returns(uint256) {
        return _internalBalances[owner][token];
    }

   function getAddressTokens(address owner) public view returns(address[] memory) {
        return _tokenHoldings[owner];
   }

    function getInternalBalance(address owner, address[] calldata tokens) 
        public 
        view 
        returns(uint256[] memory balances) {
            balances = new uint256[](tokens.length);
            for(uint256  i = 0; i < tokens.length; i++) {
                balances[i] = getBalance(owner, tokens[i]);
            }
    }

    function allowance(address spender, address owner, address token, uint256 amount)
        public
        view
        returns (bool) {
            if (msg.sender == spender) {
                return true;
            }
            AllowanceData memory _allowanceData = _allowance[owner][spender][token];
            return _allowanceData.amount >= amount && 
                (_allowanceData.deadline == 0 ||
                uint32(block.timestamp) <= _allowanceData.deadline);
    }


    function approve(address token,address spender, uint256 amount, uint32 deadline)
            public whenNotPaused
    {
        _allowance[msg.sender][spender][token] = AllowanceData(amount, deadline);
        emit Approval(msg.sender, spender, token, amount);
    }

    function approve(address token, address spender, uint256 amount) public {
        _allowance[msg.sender][spender][token] = AllowanceData(amount, 0);
    }

    function approveIncrease(address token, address spender, uint256 amount) public {
        AllowanceData memory data = _allowance[msg.sender][spender][token];
        approve(token, spender, data.amount + amount, data.deadline);
    }

    function approveDecrease(address token, address spender, uint256 amount) public {
        AllowanceData memory data = _allowance[msg.sender][spender][token];
        approve(token, spender, 
            amount == data.amount ? 0 : data.amount - amount,
            data.deadline
        );
    }

    function revokeAllowance(address token, address spender) public {
        approve(token, spender, 0);
    }


    function _increaseInternalBalance(address owner, address token, uint256 amount) private {
        _internalBalances[owner][token] += amount;
        if (_tokenHoldingsRecord[owner][token] == false) {
            _tokenHoldings[owner].push(token);
            _tokenHoldingsRecord[owner][token] = true;
        }
    }

    function _decreaseInternalBalance(address owner, address token, uint256 amount) private returns(uint256) {
        uint256 _balance = _internalBalances[owner][token];
        if (amount > _balance) {
            _internalBalances[owner][token] = 0;
            return amount - _balance ;
        }
        _internalBalances[owner][token] -= amount;
        return 0;

    }


    function sendToken(address token, uint256 amount, 
            FundTransferParam calldata  fundTransferParam
        ) public whenNotPaused nonReentrant {
            
            if(fundTransferParam.reserveType == ReserveType.Internal) {
                //TODO: Add error code "SenderNotApproved"
                require(allowance(msg.sender, 
                    fundTransferParam.sender, token, amount), "SPNA");
                //TODO: Add error code "InsufficientAmount"
                require(getBalance(fundTransferParam.sender, token) >= amount, "INSA");
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
                    // External to External
                     IERC20(token).transferFrom(fundTransferParam.sender, fundTransferParam.recipient, amount);
                }
            }else if(fundTransferParam.reserveType == ReserveType.Both) {
                if (fundTransferParam.toInternalBalance) {
                    require(fundTransferParam.sender != fundTransferParam.recipient, "CIRCULAR_TRANSFER");
                    // Check for allowance to spend sender's token
                    require(allowance(msg.sender, 
                        fundTransferParam.sender, token, amount), "SPNA");
                    uint256 delta = _decreaseInternalBalance(
                        fundTransferParam.sender, token, amount
                    );
                    _increaseInternalBalance(fundTransferParam.recipient, token, amount);

                    if (delta > 0) {
                        IERC20(token).transferFrom(fundTransferParam.sender, address(this), delta);
                    }
                }else {
                    require(allowance(msg.sender, 
                        fundTransferParam.sender, token, amount), "SPNA");
                    uint256 delta = _decreaseInternalBalance(
                        fundTransferParam.sender, token, amount
                    );
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