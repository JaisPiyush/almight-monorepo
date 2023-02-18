//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/vault/ITokenBalance.sol";
import "@almight/contract-interfaces/contracts/vault/IVaultAuthorizer.sol";

import "@almight/contract-interfaces/contracts/utils/IWFIL.sol";

import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


abstract contract TokenBalance is ITokenBalance {

    ///@notice address of WFIL (Filecoin) or WETH (Ethereum)
    //solhint-disable-next-line var-name-mixedcase
    address public immutable WRAPPED_NATIVE;

    // address public immutable userPositionController;

    ///@notice internal balance of `users => (token => balance)`
    mapping(address => mapping(address => uint256)) private _internalBalances;
    ///@notice address of the tokens held by the user in the internal balance
    mapping(address => address[]) private _tokenHoldings;
    ///@notice Flag indicating the which of the tokens are held in the internal balance
    /// of the user. Used to add unique token addresss in `_tokenHoldings`
    mapping(address => mapping(address => bool)) private _tokenHoldingsRecord;
    /// @notice Amount and deadline for the allowance to spend for the users token in internal balance
    mapping(address => mapping(address => mapping(address => AllowanceData))) private _allowance;
    /// @notice Total supplies of the token held by vault.
    mapping(address => uint256) _totalSupplies;



    event Approval(address indexed owner, address indexed spender, 
        address indexed token, uint256 amount);
    
    
    constructor(address wrappedNative) {
        WRAPPED_NATIVE = wrappedNative;
    }

    function totalSupply(address token) external view returns(uint256) {
        return _totalSupplies[token];
    }

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

            AllowanceData memory _allowanceData = _allowance[owner][spender][token];

            return _allowanceData.amount >= amount && 
                (_allowanceData.deadline == 0 ||
                
                uint32(block.timestamp) <= _allowanceData.deadline);
    }


    function approve(address token,address spender, uint256 amount, uint32 deadline)
            public
    {
       _approve(msg.sender, token, spender, amount, deadline);
    }

    function _approve(address owner, address token, address spender, uint256 amount, uint32 deadline) internal {
        _allowance[owner][spender][token] = AllowanceData(amount, deadline);
        emit Approval(owner, spender, token, amount);

    }

    function approve(address token, address spender, uint256 amount) public {
        _approve(msg.sender, token, spender, amount, 0);
    }

    function approveIncrease(address token, address spender, uint256 amount) public {
        _approveIncrease(token, msg.sender, spender,  amount);
    }


    function _approveIncrease(address token, address owner, address spender, uint256 amount) internal {
        AllowanceData memory data = _allowance[owner][spender][token];
        _approve(owner, token, spender, data.amount + amount, data.deadline);
    }

    function _approveDecrease(address token, address owner, address spender, uint256 amount) internal {
        AllowanceData memory data = _allowance[owner][spender][token];
        _approve(owner, token, spender, 
            amount >= data.amount ? 0 : data.amount - amount,
            data.deadline
        );
    }

    function approveDecrease(address token, address spender, uint256 amount) public {
        _approveDecrease(token, msg.sender, spender, amount);
    }

    function revokeAllowance(address token, address spender) public {
        approve(token, spender, 0);
    }


    function _increaseInternalBalance(address owner, address token, uint256 amount) internal {
        _internalBalances[owner][token] += amount;
        _totalSupplies[token] += amount;
        if (_tokenHoldingsRecord[owner][token] == false) {
            _tokenHoldings[owner].push(token);
            _tokenHoldingsRecord[owner][token] = true;
        }
    }

    function _decreaseInternalBalance(address owner, address token, uint256 amount) internal returns(uint256) {
        uint256 _balance = _internalBalances[owner][token];
        uint256 deductible = amount > _balance ? _balance : amount;
        _internalBalances[owner][token] -= deductible;
        _totalSupplies[token] -= deductible;
        return amount - deductible;

    }

    
}