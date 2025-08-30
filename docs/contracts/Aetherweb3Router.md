# Aetherweb3Router

## Overview

Aetherweb3Router is the primary interface for users to interact with the Aetherweb3 AMM protocol. It provides functions for token swaps, liquidity provision, and position management, implementing Uniswap V3-style routing with multicall support for gas-efficient batch operations.

## Features

- **Token Swaps**: Exact input/output swaps with slippage protection
- **Liquidity Management**: Add/remove liquidity from pools
- **Multicall Support**: Batch multiple operations in a single transaction
- **Slippage Protection**: Minimum output amounts and deadlines
- **Fee Optimization**: Automatic fee tier selection
- **Gas Efficient**: Optimized routing algorithms

## Contract Details

### Constructor Parameters

```solidity
constructor(address _factory, address _WETH)
```

- `_factory`: Address of the Aetherweb3Factory contract
- `_WETH`: Address of the Wrapped ETH contract

### Key Functions

#### Swap Functions

- `swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)`: Swap exact input tokens for minimum output tokens
- `swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)`: Swap maximum input tokens for exact output tokens
- `swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)`: Swap exact ETH for minimum tokens
- `swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] calldata path, address to, uint256 deadline)`: Swap maximum tokens for exact ETH
- `swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)`: Swap exact tokens for minimum ETH
- `swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)`: Swap ETH for exact tokens

#### Liquidity Functions

- `addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`: Add liquidity to a pool
- `removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`: Remove liquidity from a pool
- `removeLiquidityWithPermit(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline, bool approveMax, uint8 v, bytes32 r, bytes32 s)`: Remove liquidity with permit signature

#### Multicall Functions

- `multicall(bytes[] calldata data)`: Execute multiple calls in a single transaction
- `multicall(uint256 deadline, bytes[] calldata data)`: Execute multiple calls with deadline

#### Utility Functions

- `quote(uint256 amountA, uint256 reserveA, uint256 reserveB)`: Get quote for token swap
- `getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)`: Calculate output amount
- `getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)`: Calculate input amount
- `getAmountsOut(uint256 amountIn, address[] memory path)`: Get amounts out for path
- `getAmountsIn(uint256 amountOut, address[] memory path)`: Get amounts in for path

## Usage Examples

### Basic Token Swap

```solidity
// Approve router to spend tokens
token.approve(router.address, amountIn);

// Define swap path
address[] memory path = new address[](2);
path[0] = tokenA.address;
path[1] = tokenB.address;

// Execute swap
router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    recipient,
    block.timestamp + 3600 // 1 hour deadline
);
```

### Adding Liquidity

```solidity
// Approve tokens for router
tokenA.approve(router.address, amountA);
tokenB.approve(router.address, amountB);

// Add liquidity
(uint256 amountAUsed, uint256 amountBUsed, uint256 liquidity) = router.addLiquidity(
    tokenA.address,
    tokenB.address,
    amountADesired,
    amountBDesired,
    amountAMin,
    amountBMin,
    liquidityProvider,
    block.timestamp + 3600
);
```

### Multicall Operations

```solidity
// Batch multiple operations
bytes[] memory calls = new bytes[](2);

// Approve and swap in one transaction
calls[0] = abi.encodeWithSelector(
    token.approve.selector,
    router.address,
    amountIn
);
calls[1] = abi.encodeWithSelector(
    router.swapExactTokensForTokens.selector,
    amountIn,
    amountOutMin,
    path,
    recipient,
    block.timestamp + 3600
);

router.multicall(calls);
```

## Deployment

### Prerequisites

- Aetherweb3Factory contract deployed
- WETH contract address
- Hardhat development environment

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    // Factory and WETH addresses
    const FACTORY_ADDRESS = "0x..."; // Deployed factory address
    const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Mainnet WETH

    console.log("Deploying Aetherweb3Router...");

    const Router = await ethers.getContractFactory("Aetherweb3Router");
    const router = await Router.deploy(FACTORY_ADDRESS, WETH_ADDRESS);
    await router.deployed();

    console.log("Aetherweb3Router deployed to:", router.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

## Security Considerations

- **Deadline Protection**: All operations include deadline parameters
- **Slippage Protection**: Minimum output amounts prevent unfavorable trades
- **Reentrancy Protection**: Protected against reentrancy attacks
- **Input Validation**: Validates all input parameters
- **Access Control**: Public functions with proper authorization

## Integration Guide

### With Frontend Applications

```javascript
// Get quote before swap
const amounts = await router.getAmountsOut(amountIn, path);
const expectedOut = amounts[amounts.length - 1];

// Execute swap with slippage protection
const slippage = 0.5; // 0.5%
const amountOutMin = expectedOut * (100 - slippage) / 100;

await router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    userAddress,
    Math.floor(Date.now() / 1000) + 3600
);
```

### With Smart Contracts

```solidity
contract MyContract {
    IAetherweb3Router public router;

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut
    ) external {
        // Transfer tokens to contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Approve router
        IERC20(tokenIn).approve(address(router), amountIn);

        // Define path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Execute swap
        router.swapExactTokensForTokens(
            amountIn,
            minOut,
            path,
            msg.sender,
            block.timestamp + 3600
        );
    }
}
```

## Events

- `LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity)`
- `LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity)`
- `Swap(address indexed sender, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut)`

## Gas Optimization

- Multicall for batch operations
- Efficient path calculation
- Minimal storage operations
- Optimized routing algorithms

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Router.test.js
```

### Test Coverage

- Token swaps with various paths
- Liquidity operations
- Multicall functionality
- Slippage protection
- Deadline handling
- Integration with factory and pools
- Gas usage optimization

## License

This contract is licensed under the MIT License.
