# Aetherweb3 Interfaces

## Overview

The Aetherweb3 ecosystem includes comprehensive interface definitions that standardize interactions between contracts. These interfaces ensure type safety, enable proper integration, and provide clear APIs for external contracts and applications.

## IAetherweb3Factory

### Interface Definition

```solidity
interface IAetherweb3Factory {
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address pool,
        uint256
    );

    function getPool(
        address tokenA,
        address tokenB
    ) external view returns (address pool);

    function createPool(
        address tokenA,
        address tokenB
    ) external returns (address pool);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setPoolDeployer(address) external;

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function poolDeployer() external view returns (address);

    function allPools(uint256) external view returns (address pool);
    function allPoolsLength() external view returns (uint256);
}
```

### Key Features

- **Pool Management**: Create and retrieve liquidity pools
- **Fee Configuration**: Set fee recipients and parameters
- **Registry**: Maintain complete pool registry
- **Events**: Emit pool creation events

### Usage

```solidity
// Get existing pool
address pool = factory.getPool(tokenA, tokenB);

// Create new pool if doesn't exist
if (pool == address(0)) {
    pool = factory.createPool(tokenA, tokenB);
}
```

## IAetherweb3Router

### Interface Definition

```solidity
interface IAetherweb3Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function getAmountsOut(
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] memory path
    ) external view returns (uint256[] memory amounts);

    function multicall(
        bytes[] calldata data
    ) external returns (bytes[] memory results);
}
```

### Key Features

- **Token Swaps**: Multiple swap functions with protection
- **Liquidity Management**: Add/remove liquidity operations
- **Path Calculation**: Get amounts for swap paths
- **Multicall**: Batch multiple operations

### Usage

```solidity
// Calculate expected output
uint256[] memory amounts = router.getAmountsOut(amountIn, path);
uint256 expectedOut = amounts[amounts.length - 1];

// Execute swap with slippage protection
router.swapExactTokensForTokens(
    amountIn,
    expectedOut * 995 / 1000, // 0.5% slippage
    path,
    recipient,
    block.timestamp + 3600
);
```

## IAetherweb3Pool

### Interface Definition

```solidity
interface IAetherweb3Pool {
    function initialize(uint160 sqrtPriceX96) external;

    function mint(
        address recipient,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 amount0Used, uint256 amount1Used, uint256 liquidity);

    function burn(
        address recipient
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes calldata data
    ) external returns (uint256 amountOut);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function liquidity() external view returns (uint128);

    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}
```

### Key Features

- **Pool Initialization**: Set initial price and parameters
- **Liquidity Operations**: Mint/burn liquidity tokens
- **Swaps**: Execute token exchanges
- **Flash Loans**: Flash swap functionality
- **State Queries**: Get pool state and parameters

### Usage

```solidity
// Get pool state
(uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();

// Execute swap
uint256 amountOut = pool.swap(
    recipient,
    zeroForOne,
    amountIn,
    amountOutMin,
    callbackData
);
```

## IAetherweb3Oracle

### Interface Definition

```solidity
interface IAetherweb3Oracle {
    function getPrice(
        address tokenA,
        address tokenB
    ) external view returns (uint256 price);

    function getPriceWithTimestamp(
        address tokenA,
        address tokenB
    ) external view returns (uint256 price, uint256 timestamp);

    function updatePrice(
        address tokenA,
        address tokenB,
        uint256 price,
        uint256 timestamp
    ) external;

    function updatePrices(
        address[] calldata tokenAs,
        address[] calldata tokenBs,
        uint256[] calldata prices,
        uint256[] calldata timestamps
    ) external;

    function addPriceSource(address source) external;
    function removePriceSource(address source) external;
    function getSources() external view returns (address[] memory);

    function setMaxPriceDeviation(uint256 deviation) external;
    function setMinSourcesRequired(uint256 minSources) external;
}
```

### Key Features

- **Price Queries**: Get current and historical prices
- **Price Updates**: Update prices from multiple sources
- **Source Management**: Add/remove price sources
- **Configuration**: Set deviation limits and requirements

### Usage

```solidity
// Get current price
uint256 price = oracle.getPrice(tokenA, tokenB);

// Update price
oracle.updatePrice(tokenA, tokenB, newPrice, block.timestamp);

// Add new source
oracle.addPriceSource(newSourceAddress);
```

## IAetherweb3VaultFactory

### Interface Definition

```solidity
interface IAetherweb3VaultFactory {
    // Structs
    struct VaultParams {
        address stakingToken;
        address rewardToken;
        address dao;
        uint256 rewardRate;
        uint256 emergencyPenalty;
        string name;
        string symbol;
    }

    // Events
    event VaultCreated(
        address indexed vault,
        address indexed creator,
        address stakingToken,
        address rewardToken,
        uint256 rewardRate
    );

    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FactoryPaused(address indexed account);
    event FactoryUnpaused(address indexed account);

    // Core functions
    function createVault(VaultParams calldata params) external payable returns (address vault);
    function createVaults(VaultParams[] calldata paramsArray) external payable returns (address[] memory vaults);
    function predictVaultAddress(VaultParams calldata params, address deployer) external view returns (address predictedAddress);

    // Query functions
    function getVaultInfo(address vault) external view returns (VaultParams memory params, address creator);
    function getAllVaults() external view returns (address[] memory);
    function getVaultsByCreator(address creator) external view returns (address[] memory vaults);
    function getVaultsByStakingToken(address stakingToken) external view returns (address[] memory vaults);
    function getVaultCount() external view returns (uint256);

    // State variables
    function allVaults(uint256 index) external view returns (address);
    function isVault(address vault) external view returns (bool);
    function vaultParams(address vault) external view returns (
        address stakingToken,
        address rewardToken,
        address dao,
        uint256 rewardRate,
        uint256 emergencyPenalty,
        string memory name,
        string memory symbol
    );
    function vaultCreators(address vault) external view returns (address);
    function creationFee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function isPaused() external view returns (bool);

    // Admin functions
    function setCreationFee(uint256 newFee) external;
    function setFeeRecipient(address newRecipient) external;
    function pause() external;
    function unpause() external;
    function emergencyWithdraw() external;
}
```

### Key Features

- **Vault Creation**: Deploy staking vaults with custom parameters
- **Batch Operations**: Create multiple vaults simultaneously
- **Registry Management**: Track all deployed vaults and their configurations
- **Fee System**: Configurable creation fees
- **Access Control**: Owner-controlled factory operations
- **Address Prediction**: Predict vault addresses before deployment

### Usage Examples

```solidity
// Create a single vault
IAetherweb3VaultFactory.VaultParams memory params = IAetherweb3VaultFactory.VaultParams({
    stakingToken: address(stakingToken),
    rewardToken: address(rewardToken),
    dao: address(dao),
    rewardRate: 1000000000000000000, // 1 token per second
    emergencyPenalty: 1000, // 10%
    name: "My Staking Vault",
    symbol: "MY-VAULT"
});

address vault = factory.createVault{value: creationFee}(params);

// Create multiple vaults
IAetherweb3VaultFactory.VaultParams[] memory paramsArray = new IAetherweb3VaultFactory.VaultParams[](2);
// ... populate paramsArray

address[] memory vaults = factory.createVaults{value: creationFee * 2}(paramsArray);

// Query vaults
address[] memory allVaults = factory.getAllVaults();
address[] memory userVaults = factory.getVaultsByCreator(msg.sender);
```

## Pool-Specific Interfaces

### IAetherweb3PoolActions

Contains pool action functions:

```solidity
interface IAetherweb3PoolActions {
    function initialize(uint160 sqrtPriceX96) external;
    function mint(address recipient, int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
    function burn(int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256 amount0, uint256 amount1);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data) external returns (int256 amount0, int256 amount1);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}
```

### IAetherweb3PoolDerivedState

Contains derived state functions:

```solidity
interface IAetherweb3PoolDerivedState {
    function observe(uint32[] calldata secondsAgos) external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper) external view returns (int56 tickCumulativeInside, uint160 secondsPerLiquidityInsideX128, uint32 secondsInside);
}
```

### IAetherweb3PoolEvents

Contains event definitions:

```solidity
interface IAetherweb3PoolEvents {
    event Initialize(uint160 sqrtPriceX96, int24 tick);
    event Mint(address sender, address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Collect(address indexed owner, address recipient, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount0Collect, uint128 amount1Collect);
    event Burn(address indexed owner, int24 indexed tickLower, int24 indexed tickUpper, uint128 amount, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, address indexed recipient, int256 amount0, int256 amount1, uint160 sqrtPriceX96, uint128 liquidity, int24 tick);
    event Flash(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1, uint256 paid0, uint256 paid1);
    event IncreaseObservationCardinalityNext(uint16 observationCardinalityNextOld, uint16 observationCardinalityNextNew);
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}
```

### IAetherweb3PoolImmutables

Contains immutable state:

```solidity
interface IAetherweb3PoolImmutables {
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function tickSpacing() external view returns (int24);
    function maxLiquidityPerTick() external view returns (uint128);
}
```

### IAetherweb3PoolOwnerActions

Contains owner action functions:

```solidity
interface IAetherweb3PoolOwnerActions {
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested) external returns (uint128 amount0, uint128 amount1);
}
```

### IAetherweb3PoolState

Contains state view functions:

```solidity
interface IAetherweb3PoolState {
    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked);
    function feeGrowthGlobal0X128() external view returns (uint256);
    function feeGrowthGlobal1X128() external view returns (uint256);
    function protocolFees() external view returns (uint128 token0, uint128 token1);
    function liquidity() external view returns (uint128);
    function ticks(int24 tick) external view returns (uint128 liquidityGross, int128 liquidityNet, uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128, int56 tickCumulativeOutside, uint160 secondsPerLiquidityOutsideX128, uint32 secondsOutside, bool initialized);
    function tickBitmap(int16 wordPosition) external view returns (uint256);
    function positions(bytes32 key) external view returns (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128, uint128 tokensOwed0, uint128 tokensOwed1);
    function observations(uint256 index) external view returns (uint32 blockTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, bool initialized);
}
```

## Usage Guidelines

### Interface Implementation

```solidity
contract MyContract {
    IAetherweb3Router public router;
    IAetherweb3Factory public factory;
    IAetherweb3Oracle public oracle;

    constructor(address _router, address _factory, address _oracle) {
        router = IAetherweb3Router(_router);
        factory = IAetherweb3Factory(_factory);
        oracle = IAetherweb3Oracle(_oracle);
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external {
        // Use interfaces for type-safe interactions
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        router.swapExactTokensForTokens(
            amountIn,
            0, // amountOutMin - implement slippage protection
            path,
            msg.sender,
            block.timestamp + 3600
        );
    }
}
```

### Best Practices

1. **Type Safety**: Always use interfaces for external contract interactions
2. **Version Compatibility**: Ensure interface versions match contract implementations
3. **Gas Optimization**: Use view functions for read-only operations
4. **Error Handling**: Implement proper error handling for interface calls
5. **Testing**: Test interface integrations thoroughly

## License

This interface documentation is licensed under the MIT License.
