//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

//solhint-disable func-name-mixedcase
//solhint-disable var-name-mixedcase


import "@almight/modules/forge-std/src/Test.sol";
import "../../protocols/pool-linear/contracts/AlmightswapV1Router.sol";
import "../../protocols/pool-linear/contracts/AlmightswapV1Factory.sol";
import "./shared/MockAlmightswapV1ERC20.sol";

contract WFIL is AlmightswapV1ERC20 {

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "INSF_ACC");
        _burn(msg.sender, amount);
        (bool success,) = address(msg.sender).call{value: amount}(new bytes(0));
        require(success, "FAILED");
    }
}


contract TestAlmightV1Router is Test {

    uint24 public constant fee = 3000;
    AlmightswapV1Pair public pair;
    AlmightswapV1Pair public wfilPool;
    address public factory;
    AlmightswapV1Router public router;
    MockAlmightswapV1ERC20 public token1;
    MockAlmightswapV1ERC20 public token2;
    WFIL public wfil;
    uint256 public TOKEN_SUPPLY = 50000 * 1e18;
    uint256 private constant _maxUint256 = type(uint256).max;


    function setUp() public  {
        vm.deal(address(this), TOKEN_SUPPLY);
        token1 = new MockAlmightswapV1ERC20(TOKEN_SUPPLY);
        token2 = new MockAlmightswapV1ERC20(TOKEN_SUPPLY);
        wfil = new WFIL();
        factory = address(new AlmightswapV1Factory(address(this), address(0)));
        pair = AlmightswapV1Pair(
            AlmightswapV1Factory(factory).createPair(address(token1), address(token2), fee)
        );

        wfilPool = AlmightswapV1Pair(
            AlmightswapV1Factory(factory).createPair(address(token1), 
            address(wfil), fee
        )
        );
        router = new AlmightswapV1Router(
            factory,
            address(wfil)
        );

    }

    receive() external payable {}

    function test_factoryAndNativeAddress() public {
        assertEq(router.factory(), factory);
        assertEq(router.native(), address(wfil));
    }


    function _getAddLiquidityParam(address pool, 
        uint256 amount0, 
        uint256 amount1,
        uint256 amount0Min,
        uint256 amount1Min,
        bool native
        ) internal pure returns(IAlmightswapV1Router.AddLiquidityParam memory param) {
            return IAlmightswapV1Router.AddLiquidityParam(
                pool,
                amount0,
                amount1,
                amount0Min,
                amount1Min,
                native
            );
    }

    function test_addLiquidity() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 4 * 1e18;
        uint256 expected = 2 * 1e18;
        token1.approve(address(router), _maxUint256);
        token2.approve(address(router), _maxUint256);

        (,,uint256 liq) = router.addLiquidity(
            address(this),
            _maxUint256,
            _getAddLiquidityParam(address(pair), amount0, 
            amount1, 0, 0, false)
        );

        assertEq(liq, expected - 1000);
    }

    function test_createPool() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 4 * 1e18;
        token1.approve(address(router), _maxUint256);
        token2.approve(address(router), _maxUint256);

        (address pool, , , ) = router.createPool(
            address(token1), address(token2), fee, _maxUint256, 
                _getAddLiquidityParam(address(0), amount0, 
            amount1, 0, 0, false)
        );

        assertTrue(AlmightswapV1Factory(factory).isPoolRegistered(pool));

    }


    function test_addLiquidityNative() public {
        uint256 amount0 = 1e18;
        uint256 nativeAmount = 4e18;
        uint256 expected = 2e18;
        token1.approve(address(router), _maxUint256);
        (,, uint256 liq) = router.addLiquidity{value: nativeAmount}(
            address(this),
            _maxUint256,
            _getAddLiquidityParam(address(wfilPool), amount0, 
            0, 0, 0, true)
        );
        assertEq(liq, expected - 1000);
    }


    function test_createPoolNative() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 4 * 1e18;
        token1.approve(address(router), _maxUint256);
 
        (address pool, , , ) = router.createPool{value: amount1}(
            address(token1), address(0), fee, _maxUint256, 
                _getAddLiquidityParam(address(0), amount0, 
            amount1, 0, 0, true)
        );

        assertTrue(AlmightswapV1Factory(factory).isPoolRegistered(pool));

    }

    function addLiquidity(address pool, MockAlmightswapV1ERC20 token, uint256 amount0, uint256 amount1) 
        public returns(uint256) {
        token1.transfer(pool, amount0);
        token.transfer(pool, amount1);
        return AlmightswapV1Pair(pool).mint(address(this));
    }

    function test_removeLiquidity() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 4e18;

        uint256 liq = addLiquidity(address(pair), 
            token2, amount0, amount1);

        pair.approve(address(router), _maxUint256);
        router.removeLiquidity(address(this), _maxUint256, 
            IAlmightswapV1Router.RemoveLiquidityParam(
                address(pair),liq, 0, 0,
                false, false, false, 0 , "0x", "0x" 
            )
        );

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(token1.balanceOf(address(this)), token1.totalSupply() - 500);
        assertEq(token2.balanceOf(address(this)), token2.totalSupply() - 2000);
    }


    function test_removeLiquidityNative() public {
        uint256 amount0 = 1e18;
        uint256 amount1 = 4e18;
        address pool = address(wfilPool);
        token1.transfer(pool, amount0);
        wfil.deposit{value:amount1}();
        wfil.transfer(pool, amount1);
        
        uint256 liq = wfilPool.mint(address(this));

        wfilPool.approve(address(router), _maxUint256);
        router.removeLiquidity(address(this), _maxUint256, 
            IAlmightswapV1Router.RemoveLiquidityParam(
                pool,liq, 0, 0,
                true, false, false, 0 , "0x", "0x" 
            )
        );

        assertEq(wfil.balanceOf(address(this)), 0);
        assertEq(token1.balanceOf(address(this)), token1.totalSupply() - 500);
        assertEq(address(this).balance, TOKEN_SUPPLY - 2000);
    }


    function test_removeLiquidityWithPermit() public {
        address owner = vm.addr(4);
        uint256 amount0 = 1e18;
        uint256 amount1 = 4e18;

        uint256 liq = addLiquidity(address(pair), 
            token2, amount0, amount1);
        pair.transfer(owner, liq);
        
        uint256 nonce = pair.nonces(address(this));
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                pair.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(
                pair.PERMIT_TYPEHASH(), 
                owner, 
                address(router), 
                _maxUint256, nonce++, _maxUint256))
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(4, digest);
        vm.prank(owner);
        router.removeLiquidity(address(this), _maxUint256, 
            IAlmightswapV1Router.RemoveLiquidityParam(
                address(pair),liq, 0, 0,
                false, true, true, v , r, s 
            )
        );

        assertEq(pair.balanceOf(owner), 0);
        assertEq(token1.balanceOf(address(this)), token1.totalSupply() - 500);
        assertEq(token2.balanceOf(address(this)), token2.totalSupply() - 2000);
    }


    function test_swapInputProvided() public {
        uint256 amount0 = 5e18;
        uint256 amount1 = 1e19;
        uint256 swapAmount = 1e18;
        uint256 expected = 1662497915624478906;

        addLiquidity(address(pair), token2, amount0, amount1);
        token1.approve(address(router), _maxUint256);

        uint256 token2Balance = token2.balanceOf(address(this));
        address[] memory pools = new address[](1);
        pools[0] = address(pair);

        IAlmightswapV1Router.SwapStepInfo[] memory steps = router.swap(
            address(token1),
            address(this),
            _maxUint256,
            pools,
            IAlmightswapV1Router.SwapParam(
                false,
                swapAmount,
                0,
                false,
                address(0)
            )
        );
        assertEq(steps.length, 1);
        assertEq(token2.balanceOf(address(this)), token2Balance + expected);

    }

    function test_swapOutputExpected() public {
        uint256 amount0 = 5e18;
        uint256 amount1 = 1e19;
        uint256 outputAmount = 1e18;
        uint256 expected = 557227237267357629;

        addLiquidity(address(pair), token2, amount0, amount1);
        token1.approve(address(router), _maxUint256);

        uint256 token1Balance = token1.balanceOf(address(this));
        address[] memory pools = new address[](1);
        pools[0] = address(pair);

        IAlmightswapV1Router.SwapStepInfo[] memory steps = router.swap(
            address(token1),
            address(this),
            _maxUint256,
            pools,
            IAlmightswapV1Router.SwapParam(
                true,
                outputAmount,
                _maxUint256,
                false,
                address(token2)
            )
        );
        assertEq(steps.length, 1);
        assertEq(steps[0].amountOut, outputAmount);
        assertEq(token1.balanceOf(address(this)), token1Balance - expected);
    }

    function test_swapNativeAsInput() public {
        uint256 amount0 = 1e19;
        uint256 nativeAmount = 5e18;
        uint256 swapAmount = 1e18;
        uint256 output = 1662497915624478906;
        address pool = address(wfilPool);

        token1.transfer(pool, amount0);
        wfil.deposit{value:nativeAmount}();
        wfil.transfer(pool, nativeAmount);
        wfilPool.mint(address(this));

        token1.approve(address(router), _maxUint256);

        address recp = vm.addr(4);
        address[] memory pools = new address[](1);
        pools[0] = address(pool);

        IAlmightswapV1Router.SwapStepInfo[] memory steps = router.swap{value: swapAmount}(
            address(wfil),
            recp,
            _maxUint256,
            pools,
            IAlmightswapV1Router.SwapParam(
                false,
                swapAmount,
                0,
                true,
                address(0)
            )
        );

        assertEq(steps.length, 1);
        assertEq(steps[0].amountOut, output);
        assertEq(token1.balanceOf(recp), output);


    }
    function test_swapNativeAsOutputInputProvided() public {
        uint256 amount0 = 5e18;
        uint256 nativeAmount = 1e19;
        uint256 swapAmount = 557227237267357629;
        uint256 outputAmount = 1e18;

        address pool = address(wfilPool);

        token1.transfer(pool, amount0);
        wfil.deposit{value: nativeAmount}();
        wfil.transfer(pool, nativeAmount);
        wfilPool.mint(address(this));

        token1.approve(address(router), _maxUint256);

        address recp = vm.addr(4);
        address[] memory pools = new address[](1);
        pools[0] = address(pool);

        IAlmightswapV1Router.SwapStepInfo[] memory steps = router.swap{value: swapAmount}(
            address(token1),
            recp,
            _maxUint256,
            pools,
            IAlmightswapV1Router.SwapParam(
                true,
                outputAmount,
                _maxUint256,
                true,
                address(wfil)
            )
        );

        assertEq(steps[0].amountIn, swapAmount);
        assertEq(recp.balance, outputAmount);


    }

    function test_batchSwapInputProvided() public {
        uint256 amount1Pool1 = 5e18;
        uint256 amount0Pool1 = 1e19;
        uint256 swapAmountPool1 = 1e18;
        uint256 expectedPool1 = 1662497915624478906;

        
        // Adding liquidity
        token1.transfer(address(pair), amount0Pool1);
        token2.transfer(address(pair), amount1Pool1);
        pair.mint(address(this));

        token1.transfer(address(wfilPool), amount1Pool1);
        wfil.deposit{value: amount0Pool1}();
        wfil.transfer(address(wfilPool), amount0Pool1);
        wfilPool.mint(address(this));

        (uint256 reserveIn, uint256 reserveOut, ) = wfilPool.getReserves();
        uint256 outputPool2 = router.getAmountOut(
            expectedPool1, reserveIn, reserveOut, fee
        );


        address[] memory pools = new address[](2);
        pools[0] = address(pair);
        pools[1] = address(wfilPool);

        address recp = vm.addr(4);
        token2.approve(address(router), swapAmountPool1);

        IAlmightswapV1Router.SwapStepInfo[] memory steps = router.swap(
            address(token2),
            recp,
            _maxUint256,
            pools,
            IAlmightswapV1Router.SwapParam(
                false,
                swapAmountPool1,
                0,
                false,
                address(wfil)
            )
        );

        assertEq(steps.length, 2);
        assertEq(steps[0].amountOut, expectedPool1);
        assertEq(steps[1].amountOut, outputPool2);



    }




    

}