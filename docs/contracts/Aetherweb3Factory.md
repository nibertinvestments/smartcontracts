# Aetherweb3Factory

## Overview

Aetherweb3Factory is the core factory contract for the Aetherweb3 AMM (Automated Market Maker) protocol. It manages the creation and tracking of liquidity pools, implementing Uniswap V3-style deterministic pool addresses using CREATE2 for gas-efficient deployments.

## Features

- **Deterministic Pool Creation**: Uses CREATE2 for predictable pool addresses
- **Pool Registry**: Maintains a registry of all created pools
- **Fee Management**: Configurable fee tiers for different trading pairs
- **Access Control**: Owner-controlled pool creation and parameter management
- **Gas Optimized**: Efficient pool lookup and creation mechanisms

## Contract Details

### Constructor Parameters

```solidity
constructor(address _poolDeployer)
```

- `_poolDeployer`: Address of the Aetherweb3PoolDeployer contract

### Key Functions

#### Public Functions

- `createPool(address tokenA, address tokenB)`: Create a new liquidity pool for token pair
- `getPool(address tokenA, address tokenB)`: Get the pool address for a token pair
- `allPools(uint256 index)`: Get pool address by index
- `allPoolsLength()`: Get total number of pools created

#### Owner Functions

- `setFeeTo(address _feeTo)`: Set fee recipient address
- `setFeeToSetter(address _feeToSetter)`: Set fee setter address
- `setPoolDeployer(address _poolDeployer)`: Update pool deployer address

#### View Functions

- `feeTo()`: Returns the fee recipient address
- `feeToSetter()`: Returns the fee setter address
- `poolDeployer()`: Returns the pool deployer address

## Usage Examples

### Creating a New Pool

```solidity
// Create a new trading pair pool
address pool = factory.createPool(tokenA, tokenB);

// Check if pool already exists
address existingPool = factory.getPool(tokenA, tokenB);
if (existingPool == address(0)) {
    // Pool doesn't exist, create it
    pool = factory.createPool(tokenA, tokenB);
}
```

### Iterating Through All Pools

```solidity
uint256 poolCount = factory.allPoolsLength();
for (uint256 i = 0; i < poolCount; i++) {
    address pool = factory.allPools(i);
    // Process pool
}
```

## Deployment

### Prerequisites

- Aetherweb3PoolDeployer contract deployed
- Hardhat development environment
- OpenZeppelin contracts library

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying contracts...");

    // Deploy PoolDeployer first
    const PoolDeployer = await ethers.getContractFactory("Aetherweb3PoolDeployer");
    const poolDeployer = await PoolDeployer.deploy();
    await poolDeployer.deployed();

    // Deploy Factory
    const Factory = await ethers.getContractFactory("Aetherweb3Factory");
    const factory = await Factory.deploy(poolDeployer.address);
    await factory.deployed();

    console.log("Aetherweb3Factory deployed to:", factory.address);
    console.log("Aetherweb3PoolDeployer deployed to:", poolDeployer.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Initialization

After deployment, initialize the pool deployer with factory address:

```javascript
// Set factory address in pool deployer
await poolDeployer.setFactory(factory.address);
```

## Security Considerations

- **Access Control**: Only owner can create pools and set parameters
- **Address Validation**: Validates token addresses before pool creation
- **Reentrancy Protection**: Protected against reentrancy attacks
- **CREATE2 Security**: Deterministic addresses prevent address collisions

## Integration Guide

### With Aetherweb3Router

```solidity
// Router uses factory to get/create pools
address pool = factory.getPool(tokenA, tokenB);
if (pool == address(0)) {
    pool = factory.createPool(tokenA, tokenB);
}

// Use pool for swaps
IAetherweb3Pool(pool).swap(...);
```

### With Aetherweb3Pool

```solidity
// Pool queries factory for fee settings
address feeRecipient = factory.feeTo();
uint256 feeAmount = factory.feeToSetter() == msg.sender ? customFee : defaultFee;
```

## Events

- `PoolCreated(address indexed token0, address indexed token1, address pool, uint256)`
- `FeeToUpdated(address indexed oldFeeTo, address indexed newFeeTo)`
- `FeeToSetterUpdated(address indexed oldFeeToSetter, address indexed newFeeToSetter)`

## Gas Optimization

- CREATE2 for deterministic pool addresses
- Efficient pool lookup with mapping
- Minimal storage operations
- Batch pool creation support

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Factory.test.js
```

### Test Coverage

- Pool creation and retrieval
- Fee management
- Access control
- Integration with router and pools
- Gas usage optimization
- Edge cases and error handling

## License

This contract is licensed under the MIT License.
