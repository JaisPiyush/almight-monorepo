//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//solhint-disable func-name-mixedcase
//solhint-disable var-name-mixedcase


import "@almight/modules/forge-std/src/Test.sol";
import "../../protocols/pool-linear/contracts/AlmightswapV1Pair.sol";
import "../../protocols/pool-linear/contracts/AlmightswapV1Factory.sol";
import "./shared/MockAlmightswapV1ERC20.sol";


contract TestAlmightswapV1Pair is Test {

    AlmightswapV1Pair public pair;
    AlmightswapV1Factory public factory;
    uint24 public constant fee = 3000;
    MockAlmightswapV1ERC20 public token1;
    MockAlmightswapV1ERC20 public token2;
    uint256 public TOKEN_SUPPLY = 50000 * 1e18;
    uint256 private constant _maxUint256 = type(uint256).max;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function setUp() public  {
        token1 = new MockAlmightswapV1ERC20(TOKEN_SUPPLY);
        token2 = new MockAlmightswapV1ERC20(TOKEN_SUPPLY);
        factory = new AlmightswapV1Factory(address(this), address(0));
        pair = AlmightswapV1Pair(factory.createPair(address(token1), address(token2), fee));
    }


    function test_immutables() public {
        assertEq(pair.factory(), address(factory));
        assertEq(pair.token0(), address(token1));
        assertEq(pair.token1(), address(token2));
        assertEq(factory.feeCollector(), address(0));
    }

    function test_info() public  {
        (uint112 reserve0, uint112 reserve1, 
        address token0_, address token1_, uint24 fee_) = pair.info();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
        assertEq(token0_, address(token1));
        assertEq(token1_, address(token2));
        assertEq(fee, fee_);
    }

    function test_mintWithoutMinLiquidityAmount() public {
        token1.transfer(address(pair), 200);
        token2.transfer(address(pair), 20);
        bytes memory err = "AlmightswapV1: INSUFFICIENT_MIN_LIQUIDITY";
        vm.expectRevert(err);
        pair.mint(address(this));

    }

    function test_mint() public {
        uint256 amount1 = 70000;
        uint256 amount2 = 3000;
        token1.transfer(address(pair), amount1);
        token2.transfer(address(pair), amount2);
        vm.expectEmit(true, false, false, false);
        emit Mint(address(this), amount1, amount2);
        pair.mint(address(this));
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        assertEq(reserve0, amount1);
        assertEq(reserve1, amount2);

    }

    function addLiquidity( uint256 amount0, uint256 amount1, address recp) public 
        returns(uint256 liquidity) {
        token1.transfer(address(pair), amount0);
        token2.transfer(address(pair), amount1);
        return pair.mint(recp);

      
    }

    function addLiquidityInPair(AlmightswapV1Pair _pair, uint256 amount0, uint256 amount1, address recp) public 
        returns(uint256 liquidity) {
        token1.transfer(address(_pair), amount0);
        token2.transfer(address(_pair), amount1);
        
        liquidity =  _pair.mint(recp);      
    }

    function test_burn() public {
        address recp = vm.addr(4);
        uint256 liq = addLiquidity(3 * 1e18, 3 * 1e18, recp);
        uint256 eLiq = 3 * 1e18;
        assertEq(liq, eLiq - 1000);
        vm.prank(recp);
        IERC20(address(pair)).transfer(address(pair), liq);
        vm.expectEmit(true, false, false, true);
        emit Burn(address(this), 3 * 1e18 - 1000, 3 * 1e18 - 1000, address(this));
        pair.burn(address(this));

    }



    function test_swapTestCasesFails() public {
        address recp = vm.addr(4);
        uint64[4][7] memory swapTestCases = [
            [1 , 5, 10, 1662497915624478906],
            [1, 10, 5, 453305446940074565],

            [2, 5, 10, 2851015155847869602],
            [2, 10, 5, 831248957812239453],

            [1, 10, 10, 906610893880149131],
            [1, 100, 100, 987158034397061298],
            [1, 1000, 1000, 996006981039903216]
        ];
        for (uint i = 0; i < 7; i++) {
            uint64[4] memory swaps = swapTestCases[i];
            AlmightswapV1Pair _pair = AlmightswapV1Pair(factory.createPair(address(token1), address(token2), fee));
            addLiquidityInPair(_pair, uint256(swaps[1]) * 1e18, 
            uint256(swaps[2]) * 1e18, recp);
            token1.transfer(
                address(_pair), swaps[0] * 1e18
            );  
            bytes memory err = "AlmightswapV1: K";
            vm.expectRevert(err);
            _pair.swap(0, swaps[3] + 1, address(this), new bytes(0));
        }
    }

    function test_swapTesCasesPass() public  {
        address recp = vm.addr(4);
        uint64[4][7] memory swapTestCases = [
            [1 , 5, 10, 1662497915624478906],
            [1, 10, 5, 453305446940074565],

            [2, 5, 10, 2851015155847869602],
            [2, 10, 5, 831248957812239453],

            [1, 10, 10, 906610893880149131],
            [1, 100, 100, 987158034397061298],
            [1, 1000, 1000, 996006981039903216]
        ];
        for (uint i = 0; i < 7; i++) {
            uint64[4] memory swaps = swapTestCases[i];
            AlmightswapV1Pair _pair = AlmightswapV1Pair(factory.createPair(address(token1), address(token2), fee));
            addLiquidityInPair(_pair, uint256(swaps[1]) * 1e18, 
            uint256(swaps[2]) * 1e18, recp);
            token1.transfer(
                address(_pair), swaps[0] * 1e18
            );
            _pair.swap(0, swaps[3], address(this), new bytes(0));
        }
    }

    function test_optimisticSwapTestCasesFail() public {
        address recp = vm.addr(4);
        uint64[4][4] memory swapTestCases = [
            [997000000000000000, 5, 10, 1 * 1e18], // given amountIn, amountOut = floor(amountIn * .997)
            [997000000000000000, 10, 5, 1* 1e18],
            [997000000000000000, 5, 5, 1* 1e18],
            [1 * 1e18, 5, 5, 1003009027081243732]
        ];

        for (uint i = 0; i < 4; i++) {
            uint64[4] memory swaps = swapTestCases[i];
            AlmightswapV1Pair _pair = AlmightswapV1Pair(factory.createPair(address(token1), address(token2), fee));
            addLiquidityInPair(_pair, uint256(swaps[1]) * 1e18, 
            uint256(swaps[2]) * 1e18, recp);
            token1.transfer(
                address(_pair), swaps[3]
            );  
            bytes memory err = "AlmightswapV1: K";
            vm.expectRevert(err);
            _pair.swap(swaps[0] + 1, 0, address(this), new bytes(0));
        }

    }

    function test_optimisticSwapTestCasesPass() public {
        address recp = vm.addr(4);
        uint64[4][4] memory swapTestCases = [
            [997000000000000000, 5, 10, 1 * 1e18], // given amountIn, amountOut = floor(amountIn * .997)
            [997000000000000000, 10, 5, 1* 1e18],
            [997000000000000000, 5, 5, 1* 1e18],
            [1 * 1e18, 5, 5, 1003009027081243732]
        ];

        for (uint i = 0; i < 4; i++) {
            uint64[4] memory swaps = swapTestCases[i];
            AlmightswapV1Pair _pair = AlmightswapV1Pair(factory.createPair(address(token1), address(token2), fee));
            addLiquidityInPair(_pair, uint256(swaps[1]) * 1e18, 
            uint256(swaps[2]) * 1e18, recp);
            token1.transfer(
                address(_pair), swaps[3]
            );
            _pair.swap(swaps[0], 0, address(this), new bytes(0));
        }

    }


    function test_swapToken0() public {
        uint256 amount0 = 5 * 1e18;
        uint256 amount1 = 10 * 1e18;
        addLiquidity(amount0, amount1, address(this));
        uint256 swapAmount =  1e18;
        uint256 expectedAmount = 1662497915624478906;
        token1.transfer(
                address(pair), swapAmount
        );
        vm.expectEmit(true, false, false, false);
        emit Swap(address(this), swapAmount, 0, 0, expectedAmount, address(this));
        pair.swap(0, expectedAmount, address(this), new bytes(0));
        
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, amount0 + swapAmount);
        assertEq(reserve1, amount1 - expectedAmount);
        assertEq(token1.balanceOf(address(pair)), amount0 + swapAmount);
        assertEq(token2.balanceOf(address(pair)), amount1 - expectedAmount);

    }

    function test_swapToken1() public {
        uint256 amount0 = 5 * 1e18;
        uint256 amount1 = 10 * 1e18;
        addLiquidity(amount0, amount1, address(this));
        uint256 swapAmount = 1e18;
        uint256 expectedAmount = 453305446940074565;
        token2.transfer(
                address(pair), swapAmount
        );
        vm.expectEmit(true, false, false, false);
        emit Swap(address(this), swapAmount, 0, 0, expectedAmount, address(this));
        pair.swap(expectedAmount, 0, address(this), new bytes(0));
        
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, amount0 - expectedAmount);
        assertEq(reserve1, amount1 + swapAmount);
        assertEq(token1.balanceOf(address(pair)), amount0 - expectedAmount);
        assertEq(token2.balanceOf(address(pair)), amount1 + swapAmount);

    }

    // function test_swapGas() public  {

    //     uint256 amount0 = 5 * 1e18;
    //     uint256 amount1 = 10 * 1e18;
    //     addLiquidity(amount0, amount1, address(this));

    //     vm.warp(block.timestamp + 1);
    //     pair.sync();

    //     uint256 swapAmount =  1e18;
    //     uint256 expectedAmount = 453305446940074565;
    //     token2.transfer(
    //             address(pair), swapAmount
    //     );
    //     vm.warp(block.timestamp + 1);
    //     vm.expectEmit(true, false, false, false);
    //     emit Swap(address(this), swapAmount, 0, 0, expectedAmount, address(this));
    //     uint256 gasBefore = gasleft();
    //     pair.swap(expectedAmount, 0, address(this), new bytes(0));
    //     assertEq(gasBefore - gasleft(), 19894);
        
    // }

    function test_priceCummulativeLast() public  {
        uint256 amount0 = 3* 1e18;
        uint256 amount1 = 3 * 1e18;
        addLiquidity(amount0, amount1, address(this));

        uint32 timestamp = uint32(block.timestamp);
        vm.warp(timestamp + 1);
        pair.sync();

        (uint256 price0, uint256 price1) = ((amount0 * (2**112)) / amount1, 
            (amount1 * (2**112)) / amount0 );
        assertEq(pair.price0CumulativeLast(), price0);
        assertEq(pair.price1CumulativeLast(), price1);
        (,,uint32 t) = pair.getReserves();
        assertEq(t, timestamp + 1 );

        uint256 swapAmount = 3 * 1e18;
        token1.transfer(address(pair), swapAmount);
        vm.warp(timestamp + 10);
        
        pair.swap(0, 1e18, address(this), new bytes(0));

        assertEq(pair.price0CumulativeLast(), price0 * 10);
        assertEq(pair.price1CumulativeLast(), price1 * 10);


          


    }






}
