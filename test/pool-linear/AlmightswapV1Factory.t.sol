//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//solhint-disable func-name-mixedcase
//solhint-disable var-name-mixedcase


import "@almight/modules/forge-std/src/Test.sol";
import "../../protocols/pool-linear/contracts/AlmightswapV1Factory.sol";
import "./shared/MockAlmightswapV1ERC20.sol";


contract TestAlmightswapV1Factory is Test {

    AlmightswapV1Factory public factory;
    address public token1;
    address public token2;
    uint256 public TOKEN_SUPPLY = 100000;
    uint256 private constant _maxUint256 = type(uint256).max;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function setUp() public  {
        token1 = address(new MockAlmightswapV1ERC20(TOKEN_SUPPLY));
        token2 = address(new MockAlmightswapV1ERC20(TOKEN_SUPPLY));
        factory = new AlmightswapV1Factory(address(this));
    }

    function test_createPairSameTokenFailure() public {
        bytes memory err = "AlmightswapV1: IDENTICAL_ADDRESSES";
        vm.expectRevert(err);
        factory.createPair(token1, token1, 3000);
    }

    function test_createPairZeroAddressFailure() public {
        bytes memory err = "AlmightswapV1: ZERO_ADDRESS";
        vm.expectRevert(err);
        factory.createPair(token1, address(0), 300);
    }

    function test_createPair() public {
        address pool = factory.createPair(token1, token2, 3000);
        assertTrue(factory.isPoolRegistered(pool));
        assertEq(factory.allPairsLength(), 1);
    }

    function test_setFeeCollectorFailure(address publisher) public {
        address collector = vm.addr(43);
        if(publisher == address(this)) {
            return;
        }
        bytes memory err = "AlmightswapV1Factory: FORBIDDEN";
        vm.expectRevert(err);
        vm.prank(publisher);
        factory.setFeeCollector(collector);

    }

    function test_setFeeCollector() public {
        address collector = vm.addr(43);
        factory.setFeeCollector(collector);
        assertEq(factory.feeCollector(), collector);
    }

    function test_setFeeCollectorSetterFailure(address publisher) public {
        
        address setter = vm.addr(43);
        if(publisher == address(this)) {
            return;
        }
        bytes memory err = "AlmightswapV1Factory: FORBIDDEN";
        vm.expectRevert(err);
        vm.prank(publisher);
        factory.setFeeCollectorSetter(setter);

    }

    function test_setFeeCollectorSetter() public {
        address collector = vm.addr(43);
        factory.setFeeCollectorSetter(collector);
        assertEq(factory.feeCollectorSetter(), collector);
    }








}

