// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract YNXSimpleAMMPair is ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant FEE_BPS = 30;
    uint256 public constant BPS = 10_000;
    uint256 private constant MINIMUM_LIQUIDITY = 1_000;

    address public immutable token0;
    address public immutable token1;
    uint112 public reserve0;
    uint112 public reserve1;

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut, address indexed recipient);

    error IdenticalTokens();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientOutputAmount(uint256 amountOut, uint256 minAmountOut);
    error InvalidToken(address token);

    constructor(address tokenA, address tokenB, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        if (tokenA == tokenB) revert IdenticalTokens();
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function quote(address tokenIn, uint256 amountIn) external view returns (uint256 amountOut) {
        (uint112 reserveIn, uint112 reserveOut) = reservesFor(tokenIn);
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function addLiquidity(uint256 amount0Desired, uint256 amount1Desired, address recipient)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0Desired);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1Desired);

        uint256 total = totalSupply();
        if (total == 0) {
            liquidity = _sqrt(amount0Desired * amount1Desired) - MINIMUM_LIQUIDITY;
            _mint(address(0x000000000000000000000000000000000000dEaD), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min((amount0Desired * total) / reserve0, (amount1Desired * total) / reserve1);
        }
        if (liquidity == 0) revert InsufficientLiquidity();
        _mint(recipient, liquidity);
        _updateReserves();
        emit LiquidityAdded(recipient, amount0Desired, amount1Desired, liquidity);
    }

    function removeLiquidity(uint256 liquidity, address recipient)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidity == 0) revert ZeroAmount();
        uint256 total = totalSupply();
        amount0 = (liquidity * reserve0) / total;
        amount1 = (liquidity * reserve1) / total;
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();
        _burn(msg.sender, liquidity);
        IERC20(token0).safeTransfer(recipient, amount0);
        IERC20(token1).safeTransfer(recipient, amount1);
        _updateReserves();
        emit LiquidityRemoved(recipient, amount0, amount1, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut, address recipient)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        bool zeroForOne = tokenIn == token0;
        if (!zeroForOne && tokenIn != token1) revert InvalidToken(tokenIn);
        (uint112 reserveIn, uint112 reserveOut) = zeroForOne ? (reserve0, reserve1) : (reserve1, reserve0);
        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < minAmountOut) revert InsufficientOutputAmount(amountOut, minAmountOut);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(zeroForOne ? token1 : token0).safeTransfer(recipient, amountOut);
        _updateReserves();
        emit Swap(msg.sender, tokenIn, amountIn, amountOut, recipient);
    }

    function reservesFor(address tokenIn) public view returns (uint112 reserveIn, uint112 reserveOut) {
        if (tokenIn == token0) return (reserve0, reserve1);
        if (tokenIn == token1) return (reserve1, reserve0);
        revert InvalidToken(tokenIn);
    }

    function _getAmountOut(uint256 amountIn, uint112 reserveIn, uint112 reserveOut) internal pure returns (uint256) {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        uint256 amountInWithFee = amountIn * (BPS - FEE_BPS);
        return (amountInWithFee * reserveOut) / ((uint256(reserveIn) * BPS) + amountInWithFee);
    }

    function _updateReserves() internal {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        if (balance0 > type(uint112).max || balance1 > type(uint112).max) revert InsufficientLiquidity();
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
