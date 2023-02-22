//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//solhint-disable func-name-mixedcase
//solhint-disable var-name-mixedcase


import "@almight/modules/forge-std/src/Test.sol";
import "./shared/MockAlmightswapV1ERC20.sol";


contract TestAlmightswapV1ERC20 is Test {
    MockAlmightswapV1ERC20 public token;
    uint256 public TOKEN_SUPPLY = 100000;
    uint256 private constant _maxUint256 = type(uint256).max;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function setUp() public  {
        token = new MockAlmightswapV1ERC20(TOKEN_SUPPLY);
    }

    function test_nameSymbolDecimalsToSAnsBalOf() public {
        assertEq(token.name(), "Almightswap LP Token");
        assertEq(token.symbol(),"ALP-V1" );
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), TOKEN_SUPPLY);
        assertEq(token.balanceOf(address(this)), TOKEN_SUPPLY);
    } 

    function test_approve() public {
        uint256 amount = 5000;
        address recp = vm.addr(2);
        vm.expectEmit(true, true, false, false);
        emit Approval(
            address(this),
            recp,
            amount
        );
        token.approve(recp, amount);
        assertEq(token.allowance(address(this), recp), amount);
    }

    function test_transfer() public {
        uint256 amount = 5000;
        address recp = vm.addr(2);
        vm.expectEmit(true, true, false, false);
        emit Transfer(address(this), recp, amount);
        assertEq(token.balanceOf(recp), 0);
        token.transfer(recp, amount);
        assertEq(token.balanceOf(recp), amount);
        assertEq(token.balanceOf(address(this)), TOKEN_SUPPLY - amount);

    }

    function test_transferFailWithZeroBalance() public {
        address wallet = vm.addr(4);
        vm.prank(wallet);
        vm.expectRevert();
        token.transfer(address(this), 1);
    }

    function test_transferFailWithOverflowBalance() public {
        vm.expectRevert();
        token.transfer(vm.addr(4), TOKEN_SUPPLY + 1);
    }

    function test_tranferFrom(address recp, uint256 approved, uint256 transferAmount) public {
        console2.log(recp, approved, transferAmount);
        token.approve(recp, approved);
        vm.prank(recp);
        if (transferAmount > approved || transferAmount > TOKEN_SUPPLY) {
            vm.expectRevert();
            token.transferFrom(address(this), recp, transferAmount);
            return;
        }
        token.transferFrom(address(this), recp, transferAmount);
        assertEq(token.allowance(address(this), recp),
            approved == _maxUint256 ? _maxUint256 : approved - transferAmount);
        assertEq(token.balanceOf(recp), transferAmount);
        assertEq(token.balanceOf(address(this)), TOKEN_SUPPLY - transferAmount);
    }

}