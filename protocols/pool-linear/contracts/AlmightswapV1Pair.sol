//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1ERC20.sol";
import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Pair.sol";
import "@almight/contract-interfaces/contracts/pool-linear/IAlmightswapV1Callee.sol";
import "@almight/contract-interfaces/contracts/pool-core/IAlmightswapV1Factory.sol";



import "./libraries/UQ112x112.sol";
import "./libraries/AlmightswapV1Library.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/Math.sol";

import "./AlmightswapV1ERC20.sol";

contract AlmightswapV1Pair is AlmightswapV1ERC20 {
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;

    bool private _unlocked = true;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    // fee when 100%  = 1e6
    // 0.3 = 3000, 1 = 10000, 0.05 = 500 and so on
    uint24 public fee;

    uint112 private _reserve0;
    uint112 private _reserve1;
    uint32  private _blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    event Mint(address indexed sender, uint amount0, uint amount1);
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


    constructor(address token0_, address token1_, uint24 fee_) {
        factory = msg.sender;
        token0 = token0_;
        token1 = token1_;
        fee = fee_;
    }

    modifier lock() {
        require(_unlocked, "AlmightswapV1: LOCKED");
        _unlocked = false;
        _;
        _unlocked = true;
    }


    function _update(
        uint256 balance0, uint256 balance1, 
        uint112 reserve0, uint112 reserve1
    ) private {
        require(balance0 <= type(uint112).max && 
                balance1 <= type(uint112).max,
                "AlmightswapV1: OVERFLOW"
        );
        uint32 blockTimestamp = uint32(block.timestamp);
        uint32 timeElapsed = blockTimestamp - _blockTimestampLast;
        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            price0CumulativeLast += uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
        }

        _reserve0 = uint112(balance0);
        _reserve1 = uint112(balance1);
        _blockTimestampLast = blockTimestamp;
        emit Sync(_reserve0, _reserve1);
    }

    function _mintFee(uint112 reserve0, uint112 reserve1) private returns (bool feeOn) {
        address feeTo = IAlmightswapV1Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint256(reserve0 * reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = (rootK * 5) + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }


    function getReserves() public view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
            reserve0 = _reserve0;
            reserve1 = _reserve1;
            blockTimestampLast = _blockTimestampLast;
    }

    function mint(address to) external lock returns(uint256 liquidity) {
        uint112 reserve0 = _reserve0;
        uint112 reserve1 = _reserve1;
        uint256 balance0 = IAlmightswapV1ERC20(token0).balanceOf(address(this));
        uint256 balance1 = IAlmightswapV1ERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply; 
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min((amount0 * _totalSupply) / reserve0, (amount1 * _totalSupply) / reserve1);
        }
        require(liquidity > 0, "AlmightswapV1: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, reserve0, reserve1);
        if (feeOn) kLast = uint256(_reserve0 * _reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        uint112 reserve0 = _reserve0;
        uint112 reserve1 = _reserve1;
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IAlmightswapV1ERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IAlmightswapV1ERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(reserve0, reserve1);
        // gas savings, must be defined here since totalSupply can update in _mintFee
        uint256 _totalSupply = totalSupply; 
        // using balances ensures pro-rata distribution
        amount0 = (liquidity * balance0) / _totalSupply; 
        // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply; 
        require(amount0 > 0 && amount1 > 0, "AlmightswapV1: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        TransferHelper.safeTransfer(_token0, to, amount0);
        TransferHelper.safeTransfer(_token1, to, amount1);
        balance0 = IAlmightswapV1ERC20(_token0).balanceOf(address(this));
        balance1 = IAlmightswapV1ERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(_reserve0 * _reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);

    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "AlmightswapV1: INSUFFICIENT_OUTPUT_AMOUNT");
        uint112 reserve0 = _reserve0;
        uint112 reserve1 = _reserve1;
        require(amount0Out < reserve0 && amount1Out < reserve1, "AlmightswapV1: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "AlmightswapV1: INVALID_TO");
            if (amount0Out > 0) 
                TransferHelper.safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) 
                TransferHelper.safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) 
                IAlmightswapV1Callee(to).almightswapV1Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > reserve0 - amount0Out ? balance0 - (reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > reserve1 - amount1Out ? balance1 - (reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "AlmightswapV1: INSUFFICIENT_INPUT_AMOUNT");
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 feeLimit = AlmightswapV1Library.FEE_LIMIT;
            uint256 balance0Adjusted = (balance0 * feeLimit) - (amount0In * fee);
            uint256 balance1Adjusted = (balance1 * feeLimit) - (amount1In * fee);
            require( balance0Adjusted * balance1Adjusted >=
                uint256(reserve0 * reserve1 * (feeLimit**2))
                ,"AlmightswapV1: K"
            );
        }

        _update(balance0, balance1, reserve0, reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }


    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        TransferHelper.safeTransfer(_token0, to, 
            IERC20(_token0).balanceOf(address(this)) - _reserve0
        );
        TransferHelper.safeTransfer(_token1, to, 
            IERC20(_token1).balanceOf(address(this)) - _reserve1
        );
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), 
            IERC20(token1).balanceOf(address(this)), 
            _reserve0, 
            _reserve1
        );
    }

    // TODO: Add governance based actions (setFee, pause, unpause)

    


}