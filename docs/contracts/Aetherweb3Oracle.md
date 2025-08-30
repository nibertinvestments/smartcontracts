# Aetherweb3Oracle

## Overview

Aetherweb3Oracle is a decentralized price oracle for the Aetherweb3 DeFi ecosystem. It aggregates price data from multiple sources to provide reliable, manipulation-resistant price feeds for token pairs, implementing Chainlink-style price feeds with fallback mechanisms.

## Features

- **Multi-Source Aggregation**: Combines data from multiple price sources
- **Price Manipulation Protection**: Statistical filtering and outlier detection
- **Fallback Mechanisms**: Graceful degradation when primary sources fail
- **Update Intervals**: Configurable update frequencies for different assets
- **Access Control**: Admin-controlled price source management
- **Gas Optimized**: Efficient price retrieval and updates

## Contract Details

### Constructor Parameters

```solidity
constructor(address _admin)
```

- `_admin`: Address of the contract administrator

### Key Functions

#### Price Update Functions

- `updatePrice(address tokenA, address tokenB, uint256 price, uint256 timestamp)`: Update price for a token pair
- `updatePrices(address[] calldata tokenAs, address[] calldata tokenBs, uint256[] calldata prices, uint256[] calldata timestamps)`: Batch update multiple prices
- `updatePriceFromSource(address source, address tokenA, address tokenB, uint256 price, uint256 timestamp)`: Update price from specific source

#### Price Query Functions

- `getPrice(address tokenA, address tokenB)`: Get current price for token pair
- `getPriceWithTimestamp(address tokenA, address tokenB)`: Get price with timestamp
- `getPrices(address[] calldata tokenAs, address[] calldata tokenBs)`: Get multiple prices
- `getAveragePrice(address tokenA, address tokenB, uint256 timeWindow)`: Get average price over time window

#### Source Management Functions

- `addPriceSource(address source)`: Add a new price source
- `removePriceSource(address source)`: Remove a price source
- `setSourceWeight(address source, uint256 weight)`: Set weight for price source
- `getSources()`: Get all registered price sources

#### Admin Functions

- `setAdmin(address newAdmin)`: Transfer admin privileges
- `setMaxPriceDeviation(uint256 deviation)`: Set maximum allowed price deviation
- `setMinSourcesRequired(uint256 minSources)`: Set minimum sources required for price
- `pause()`: Pause price updates
- `unpause()`: Resume price updates

## Usage Examples

### Basic Price Query

```solidity
// Get current price
uint256 price = oracle.getPrice(tokenA, tokenB);

// Get price with timestamp
(uint256 price, uint256 timestamp) = oracle.getPriceWithTimestamp(tokenA, tokenB);

// Check if price is fresh (within 1 hour)
require(block.timestamp - timestamp <= 3600, "Price too old");
```

### Price Update

```solidity
// Update single price
oracle.updatePrice(tokenA, tokenB, newPrice, block.timestamp);

// Batch update multiple prices
address[] memory tokenAs = new address[](2);
address[] memory tokenBs = new address[](2);
uint256[] memory prices = new uint256[](2);
uint256[] memory timestamps = new uint256[](2);

// Populate arrays...
oracle.updatePrices(tokenAs, tokenBs, prices, timestamps);
```

### Source Management

```solidity
// Add new price source
oracle.addPriceSource(newSourceAddress);

// Set source weight (higher weight = more influence)
oracle.setSourceWeight(sourceAddress, 100);

// Remove unreliable source
oracle.removePriceSource(badSourceAddress);
```

## Deployment

### Prerequisites

- Hardhat development environment
- Multiple price source contracts or oracles
- Admin address for initial setup

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying Aetherweb3Oracle...");

    const Oracle = await ethers.getContractFactory("Aetherweb3Oracle");
    const oracle = await Oracle.deploy(deployer.address);
    await oracle.deployed();

    console.log("Aetherweb3Oracle deployed to:", oracle.address);

    // Initialize with price sources
    const priceSources = [
        "0x...", // Chainlink ETH/USD
        "0x...", // Uniswap V3 Oracle
        "0x..."  // Custom price source
    ];

    for (const source of priceSources) {
        await oracle.addPriceSource(source);
        await oracle.setSourceWeight(source, 100);
    }

    // Set parameters
    await oracle.setMaxPriceDeviation(500); // 5% max deviation
    await oracle.setMinSourcesRequired(2);   // At least 2 sources
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

## Security Considerations

- **Source Validation**: Only authorized sources can update prices
- **Price Deviation Limits**: Prevents extreme price manipulations
- **Timestamp Validation**: Ensures price freshness
- **Admin Controls**: Emergency pause and parameter adjustments
- **Multi-Source Consensus**: Requires multiple sources for price validity

## Integration Guide

### With Aetherweb3Router

```solidity
// Get price for slippage calculation
(uint256 price,) = oracle.getPriceWithTimestamp(tokenIn, tokenOut);

// Calculate minimum output with slippage
uint256 slippagePercent = 50; // 0.5%
uint256 minOut = (amountIn * price * (10000 - slippagePercent)) / 10000;

// Execute swap with protection
router.swapExactTokensForTokens(amountIn, minOut, path, to, deadline);
```

### With Lending Protocols

```solidity
// Get asset price for collateral valuation
uint256 assetPrice = oracle.getPrice(asset, USD);

// Calculate collateral value
uint256 collateralValue = (collateralAmount * assetPrice) / 1e18;

// Check liquidation condition
if (debtValue > collateralValue * liquidationRatio / 100) {
    // Trigger liquidation
    liquidate(position);
}
```

### With Price Feeds

```solidity
contract PriceFeed {
    IAetherweb3Oracle public oracle;

    function getLatestPrice(address token) external view returns (uint256) {
        return oracle.getPrice(token, USD);
    }

    function getAveragePrice(address token, uint256 hoursBack)
        external
        view
        returns (uint256)
    {
        uint256 timeWindow = hoursBack * 3600;
        return oracle.getAveragePrice(token, USD, timeWindow);
    }
}
```

## Events

- `PriceUpdated(address indexed tokenA, address indexed tokenB, uint256 price, uint256 timestamp)`
- `SourceAdded(address indexed source)`
- `SourceRemoved(address indexed source)`
- `SourceWeightUpdated(address indexed source, uint256 weight)`
- `AdminChanged(address indexed oldAdmin, address indexed newAdmin)`
- `Paused(address account)`
- `Unpaused(address account)`

## Gas Optimization

- Batch price updates
- Efficient storage of price data
- Minimal computation for price queries
- Optimized source management

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Oracle.test.js
```

### Test Coverage

- Price updates from multiple sources
- Price aggregation and averaging
- Source management
- Price deviation detection
- Timestamp validation
- Emergency pause functionality
- Integration with other contracts

## License

This contract is licensed under the MIT License.
