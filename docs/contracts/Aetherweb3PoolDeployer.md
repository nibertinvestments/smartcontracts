# Aetherweb3PoolDeployer

## Overview

Aetherweb3PoolDeployer is a utility contract responsible for the deterministic deployment of Aetherweb3Pool contracts using CREATE2. It ensures that pool addresses are predictable and gas-efficient, implementing Uniswap V3-style deployment patterns with proper initialization and parameter management.

## Features

- **Deterministic Deployment**: Uses CREATE2 for predictable pool addresses
- **Pool Parameter Management**: Configures pool parameters during deployment
- **Factory Integration**: Works closely with Aetherweb3Factory
- **Gas Optimized**: Efficient deployment and initialization
- **Access Control**: Restricted deployment to authorized factory

## Contract Details

### Constructor Parameters

```solidity
constructor()
```

The deployer is deployed independently and configured with factory address.

### Key Functions

#### Deployment Functions

- `deploy(address factory, address tokenA, address tokenB, uint24 fee, int24 tickSpacing)`: Deploy new pool contract
- `parameters()`: Get current deployment parameters

#### Configuration Functions

- `setFactory(address _factory)`: Set factory contract address
- `setPoolImplementation(address _implementation)`: Set pool implementation address

#### View Functions

- `factory()`: Get factory contract address
- `poolImplementation()`: Get pool implementation address

## Usage Examples

### Pool Deployment

```solidity
// Deploy through factory (recommended)
address pool = factory.createPool(tokenA, tokenB);

// Manual deployment (advanced)
bytes32 salt = keccak256(abi.encodePacked(tokenA, tokenB));
address poolAddress = deployer.deploy(
    factory.address,
    tokenA,
    tokenB,
    3000, // 0.3% fee
    60    // tick spacing
);
```

### Parameter Configuration

```solidity
// Set factory address
deployer.setFactory(factoryAddress);

// Set pool implementation
deployer.setPoolImplementation(poolImplementationAddress);
```

## Deployment

### Prerequisites

- Hardhat development environment
- Aetherweb3Factory contract address
- Pool implementation contract

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying Aetherweb3PoolDeployer...");

    const PoolDeployer = await ethers.getContractFactory("Aetherweb3PoolDeployer");
    const poolDeployer = await PoolDeployer.deploy();
    await poolDeployer.deployed();

    console.log("Aetherweb3PoolDeployer deployed to:", poolDeployer.address);

    // Deploy pool implementation
    const Pool = await ethers.getContractFactory("Aetherweb3Pool");
    const poolImplementation = await Pool.deploy();
    await poolImplementation.deployed();

    // Configure deployer
    await poolDeployer.setPoolImplementation(poolImplementation.address);

    console.log("Pool implementation deployed to:", poolImplementation.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Factory Integration

After deployment, configure the factory with deployer address:

```javascript
// Set deployer in factory
await factory.setPoolDeployer(poolDeployer.address);

// Set factory in deployer
await poolDeployer.setFactory(factory.address);
```

## Security Considerations

- **Access Control**: Only factory can trigger deployments
- **Parameter Validation**: Validates deployment parameters
- **Address Collision Prevention**: CREATE2 salt prevents collisions
- **Implementation Security**: Uses secure pool implementation

## Integration Guide

### With Aetherweb3Factory

```solidity
contract Aetherweb3Factory {
    address public poolDeployer;

    function createPool(address tokenA, address tokenB) external returns (address pool) {
        // Validate tokens
        require(tokenA != tokenB, "Identical tokens");

        // Sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        // Deploy pool
        pool = IAetherweb3PoolDeployer(poolDeployer).deploy(
            address(this),
            token0,
            token1,
            3000, // 0.3% fee
            60    // tick spacing
        );

        // Register pool
        pools[token0][token1] = pool;
        pools[token1][token0] = pool;
        allPools.push(pool);

        emit PoolCreated(token0, token1, pool, allPools.length);
    }
}
```

### Address Calculation

Calculate pool address before deployment:

```solidity
function getPoolAddress(address tokenA, address tokenB) public view returns (address) {
    (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

    bytes32 salt = keccak256(abi.encodePacked(token0, token1));
    bytes memory bytecode = abi.encodePacked(
        type(Aetherweb3Pool).creationCode,
        abi.encode(factory, token0, token1, fee, tickSpacing)
    );

    return address(uint160(uint256(keccak256(
        abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(bytecode)
        )
    ))));
}
```

## Events

- `PoolDeployed(address indexed pool, address indexed token0, address indexed token1, uint24 fee, int24 tickSpacing)`
- `FactoryUpdated(address indexed oldFactory, address indexed newFactory)`
- `ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation)`

## Gas Optimization

- CREATE2 for deterministic addresses
- Minimal storage operations
- Efficient parameter handling
- Batch deployment support

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3PoolDeployer.test.js
```

### Test Coverage

- Deterministic pool deployment
- Address calculation accuracy
- Parameter validation
- Factory integration
- CREATE2 collision prevention
- Gas usage optimization

## License

This contract is licensed under the MIT License.
