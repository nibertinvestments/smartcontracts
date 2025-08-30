# Aetherweb3Pool

## Overview

Aetherweb3Pool is the core liquidity pool contract for the Aetherweb3 AMM protocol. It manages token pairs, liquidity provision, and executes trades using constant product formula with customizable fee tiers, implementing Uniswap V3-style pool mechanics with gas optimizations.

## Features

- **Constant Product AMM**: x * y = k formula for price determination
- **Liquidity Management**: Add/remove liquidity with position tracking
- **Fee Collection**: Configurable fee tiers for different trading pairs
- **Price Oracle**: Built-in price tracking for efficient swaps
- **Flash Swaps**: Support for flash loan-style arbitrage
- **Gas Optimized**: Efficient swap and liquidity operations

## Contract Details

### Constructor Parameters

```solidity
constructor()
```

The pool is deployed through the Aetherweb3PoolDeployer using CREATE2 for deterministic addresses.

### Key Functions

#### Liquidity Functions

- `mint(address recipient, uint256 amount0, uint256 amount1)`: Add liquidity to pool
- `burn(address recipient)`: Remove liquidity from pool
- `collect(address recipient, uint256 amount0, uint256 amount1)`: Collect accumulated fees

#### Swap Functions

- `swap(address recipient, bool zeroForOne, uint256 amountIn, uint256 amountOutMin, bytes calldata data)`: Execute token swap
- `flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data)`: Execute flash swap

#### Position Management

- `positions(address owner)`: Get position information for address
- `transfer(address to, uint256 amount)`: Transfer liquidity tokens
- `transferFrom(address from, address to, uint256 amount)`: Transfer liquidity tokens on behalf

#### View Functions

- `token0()`: Get address of first token
- `token1()`: Get address of second token
- `fee()`: Get pool fee tier
- `liquidity()`: Get total liquidity
- `slot0()`: Get current price and tick information
- `tickSpacing()`: Get tick spacing for fee tier

## Usage Examples

### Adding Liquidity

```solidity
// Approve tokens for pool
token0.approve(pool.address, amount0);
token1.approve(pool.address, amount1);

// Add liquidity
(uint256 amount0Used, uint256 amount1Used, uint256 liquidityMinted) = pool.mint(
    liquidityProvider,
    amount0Desired,
    amount1Desired
);
```

### Executing Swaps

```solidity
// Approve input token
tokenIn.approve(pool.address, amountIn);

// Execute swap
pool.swap(
    recipient,
    tokenIn < tokenOut, // zeroForOne
    amountIn,
    amountOutMin,
    "" // callback data
);
```

### Flash Swaps

```solidity
// Execute flash swap
pool.flash(
    recipient,
    amount0Out,
    amount1Out,
    abi.encode(callbackData)
);

// In callback function
function uniswapV3FlashCallback(
    uint256 fee0,
    uint256 fee1,
    bytes calldata data
) external {
    // Perform arbitrage or liquidation
    // Pay back flash swap with fee
    if (fee0 > 0) token0.transfer(msg.sender, amount0Out + fee0);
    if (fee1 > 0) token1.transfer(msg.sender, amount1Out + fee1);
}
```

## Deployment

### Prerequisites

- Aetherweb3Factory contract deployed
- Token pair addresses
- Fee tier configuration

### Pool Creation

Pools are created through the factory contract:

```javascript
const { ethers } = require("hardhat");

async function createPool() {
    const factory = await ethers.getContractAt("IAetherweb3Factory", FACTORY_ADDRESS);

    // Create new pool
    const tx = await factory.createPool(tokenA, tokenB);
    const receipt = await tx.wait();

    // Get pool address from event
    const poolCreatedEvent = receipt.events.find(e => e.event === 'PoolCreated');
    const poolAddress = poolCreatedEvent.args.pool;

    console.log("Pool created at:", poolAddress);
}
```

### Initialization

After creation, initialize the pool with price and liquidity:

```javascript
const pool = await ethers.getContractAt("IAetherweb3Pool", poolAddress);

// Initialize with starting price
await pool.initialize(sqrtPriceX96);

// Add initial liquidity
await pool.mint(initialLiquidityProvider, amount0, amount1);
```

## Security Considerations

- **Reentrancy Protection**: Protected against reentrancy attacks
- **Input Validation**: Validates all input parameters
- **Price Manipulation Protection**: Slippage and deadline protection
- **Fee Validation**: Ensures fair fee collection
- **Access Control**: Factory-controlled deployment

## Integration Guide

### With Aetherweb3Router

```solidity
// Router calculates optimal path
address[] memory path = new address[](2);
path[0] = tokenIn;
path[1] = tokenOut;

// Get pool for pair
address pool = factory.getPool(path[0], path[1]);

// Execute swap through pool
IAetherweb3Pool(pool).swap(
    recipient,
    tokenIn < tokenOut,
    amountIn,
    amountOutMin,
    ""
);
```

### With Price Oracles

```solidity
// Get current price from pool
(uint160 sqrtPriceX96, , , , , ) = pool.slot0();

// Convert to regular price
uint256 price = (uint256(sqrtPriceX96) ** 2) / (2 ** 192);

// Update oracle with pool price
oracle.updatePrice(token0, token1, price, block.timestamp);
```

### With Lending Protocols

```solidity
// Check pool liquidity for liquidation
uint256 poolLiquidity = pool.liquidity();

// Calculate available liquidity for flash loans
uint256 availableForFlash = poolLiquidity / 10; // 10% of liquidity

// Execute flash loan if sufficient liquidity
if (availableForFlash >= requiredAmount) {
    pool.flash(recipient, amount0, amount1, callbackData);
}
```

## Events

- `Initialize(uint160 sqrtPriceX96, int24 tick)`
- `Mint(address indexed sender, address indexed owner, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0, uint256 amount1)`
- `Burn(address indexed owner, int24 tickLower, int24 tickUpper, uint128 amount, uint256 amount0, uint256 amount1)`
- `Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick)`
- `Flash(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1)`
- `Collect(address indexed owner, address recipient, int24 tickLower, int24 tickUpper, uint128 amount0, uint128 amount1)`

## Gas Optimization

- Efficient tick management
- Optimized swap calculations
- Minimal storage operations
- Batch liquidity operations

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Pool.test.js
```

### Test Coverage

- Liquidity provision and removal
- Token swaps with various amounts
- Flash swap functionality
- Fee collection and distribution
- Price oracle integration
- Edge cases and error handling
- Gas usage optimization

## License

This contract is licensed under the MIT License.
