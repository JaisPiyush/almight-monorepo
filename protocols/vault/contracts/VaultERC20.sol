//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9; 

import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@almight/modules/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "@almight/contract-interfaces/contracts/vault/IVault.sol";

abstract contract VaultERC20 is IERC20, IERC20Metadata {
    string private _name;
    string private _symbol;
    address public immutable vault;

    constructor(address vault_, string memory name_, string memory symbol_) {
        vault = vault_;
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return ITokenBalance(vault).totalSupply(address(this));
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return ITokenBalance(vault).getBalance(address(this), account);
    }

    
}