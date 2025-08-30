# Aetherweb3VaultFactory

## Overview

The `Aetherweb3VaultFactory` is a factory contract that enables the creation of multiple `Aetherweb3StakingVault` instances with different configurations. This pattern allows for flexible vault deployment while maintaining centralized management and oversight.

## Features

- **Flexible Vault Creation**: Deploy vaults with custom parameters (staking tokens, reward tokens, rates, etc.)
- **Batch Deployment**: Create multiple vaults in a single transaction
- **Vault Registry**: Track all deployed vaults and their parameters
- **Access Control**: Owner-controlled factory with pausable functionality
- **Fee System**: Optional creation fees for vault deployment
- **Address Prediction**: Predict vault addresses before deployment
- **Query Functions**: Comprehensive vault discovery and filtering

## Architecture

```
Aetherweb3VaultFactory
├── Vault Creation
│   ├── Single vault deployment
│   ├── Batch vault deployment
│   └── Parameter validation
├── Vault Registry
│   ├── All vaults tracking
│   ├── Creator mapping
│   └── Parameter storage
├── Admin Controls
│   ├── Fee management
│   ├── Pause/unpause
│   └── Emergency functions
└── Query Interface
    ├── Vault discovery
    ├── Creator filtering
    └── Token filtering
```

## Contract Interface

### Core Functions

#### `createVault(VaultParams params)`
Creates a new staking vault with specified parameters.

**Parameters:**
- `stakingToken`: Address of the token to be staked
- `rewardToken`: Address of the reward token
- `dao`: Address of the DAO contract for governance
- `rewardRate`: Reward rate per second (in wei)
- `emergencyPenalty`: Emergency withdrawal penalty (basis points, max 5000 = 50%)
- `name`: Vault name
- `symbol`: Vault symbol

**Returns:** Address of the created vault

**Requirements:**
- All addresses must be valid (non-zero)
- `rewardRate` must be greater than 0
- `emergencyPenalty` must not exceed 5000 basis points
- Name and symbol must not be empty

#### `createVaults(VaultParams[] paramsArray)`
Creates multiple vaults in a single transaction.

**Parameters:**
- `paramsArray`: Array of vault parameters

**Returns:** Array of created vault addresses

#### `predictVaultAddress(VaultParams params, address deployer)`
Predicts the address of a vault before deployment.

**Parameters:**
- `params`: Vault parameters
- `deployer`: Address that will deploy the vault

**Returns:** Predicted vault address

### Query Functions

#### `getVaultInfo(address vault)`
Returns detailed information about a vault.

**Returns:**
- `params`: Vault parameters
- `creator`: Address that created the vault

#### `getAllVaults()`
Returns all deployed vault addresses.

#### `getVaultsByCreator(address creator)`
Returns all vaults created by a specific address.

#### `getVaultsByStakingToken(address stakingToken)`
Returns all vaults that accept a specific staking token.

#### `getVaultCount()`
Returns the total number of deployed vaults.

### Admin Functions

#### `setCreationFee(uint256 newFee)`
Updates the vault creation fee.

#### `setFeeRecipient(address newRecipient)`
Updates the address that receives creation fees.

#### `pause()`
Pauses vault creation.

#### `unpause()`
Resumes vault creation.

## Usage Examples

### Basic Vault Creation

```solidity
// Vault parameters
Aetherweb3VaultFactory.VaultParams memory params = Aetherweb3VaultFactory.VaultParams({
    stakingToken: address(aetherToken),
    rewardToken: address(rewardToken),
    dao: address(daoContract),
    rewardRate: 1000000000000000000, // 1 token per second
    emergencyPenalty: 1000, // 10% penalty
    name: "Aetherweb3 Staking Vault",
    symbol: "AETH-VAULT"
});

// Create vault
address vault = factory.createVault{value: creationFee}(params);
```

### Batch Vault Creation

```solidity
// Multiple vault parameters
Aetherweb3VaultFactory.VaultParams[] memory paramsArray = new Aetherweb3VaultFactory.VaultParams[](2);

paramsArray[0] = Aetherweb3VaultFactory.VaultParams({
    stakingToken: address(tokenA),
    rewardToken: address(rewardA),
    dao: address(dao),
    rewardRate: 500000000000000000, // 0.5 tokens per second
    emergencyPenalty: 500, // 5% penalty
    name: "TokenA Vault",
    symbol: "TA-VAULT"
});

paramsArray[1] = Aetherweb3VaultFactory.VaultParams({
    stakingToken: address(tokenB),
    rewardToken: address(rewardB),
    dao: address(dao),
    rewardRate: 2000000000000000000, // 2 tokens per second
    emergencyPenalty: 1500, // 15% penalty
    name: "TokenB Vault",
    symbol: "TB-VAULT"
});

// Create vaults
address[] memory vaults = factory.createVaults{value: creationFee * 2}(paramsArray);
```

### Querying Vaults

```solidity
// Get all vaults
address[] memory allVaults = factory.getAllVaults();

// Get vaults by creator
address[] memory myVaults = factory.getVaultsByCreator(msg.sender);

// Get vaults for specific token
address[] memory tokenVaults = factory.getVaultsByStakingToken(address(stakingToken));

// Get vault information
(Aetherweb3VaultFactory.VaultParams memory params, address creator) = factory.getVaultInfo(vaultAddress);
```

## Security Considerations

### Access Control
- Factory is owned by a single address with admin privileges
- Vault creation can be paused in emergencies
- Fee system prevents spam deployments

### Parameter Validation
- All addresses are validated to prevent zero-address deployments
- Reward rates must be positive to ensure meaningful rewards
- Emergency penalties are capped to prevent excessive losses
- String parameters are validated for non-emptiness

### Fee Management
- Creation fees are optional and configurable
- Excess fees in batch creation are refunded
- Emergency withdrawal function for stuck ETH

### Integration Security
- Works with existing DAO and token contracts
- Maintains compatibility with staking vault interface
- Predictable vault addresses for integration planning

## Integration Guide

### With DAO Governance

```solidity
// DAO can create vaults through proposals
function createVaultProposal(
    address factory,
    Aetherweb3VaultFactory.VaultParams memory params
) external onlyDAO {
    // Create vault through factory
    address vault = IAetherweb3VaultFactory(factory).createVault(params);

    // Register vault with DAO
    dao.registerVault(vault);
}
```

### With Frontend Applications

```javascript
// Frontend integration example
async function createVault(params) {
    const factory = new ethers.Contract(factoryAddress, factoryABI, signer);

    // Estimate creation fee
    const creationFee = await factory.creationFee();

    // Create vault
    const tx = await factory.createVault(params, {
        value: creationFee
    });

    const receipt = await tx.wait();

    // Get vault address from event
    const vaultCreatedEvent = receipt.events.find(e => e.event === 'VaultCreated');
    const vaultAddress = vaultCreatedEvent.args.vault;

    return vaultAddress;
}
```

### With DeFi Protocols

```solidity
// Integration with yield farming
contract YieldFarm {
    address public factory;

    function createStakingVault(
        address stakingToken,
        address rewardToken,
        uint256 rewardRate
    ) external returns (address) {
        Aetherweb3VaultFactory.VaultParams memory params = Aetherweb3VaultFactory.VaultParams({
            stakingToken: stakingToken,
            rewardToken: rewardToken,
            dao: address(this), // Farm acts as DAO
            rewardRate: rewardRate,
            emergencyPenalty: 1000,
            name: "Yield Farm Vault",
            symbol: "YF-VAULT"
        });

        return IAetherweb3VaultFactory(factory).createVault(params);
    }
}
```

## Deployment

### Constructor Parameters

```solidity
constructor(address _feeRecipient)
```

**Parameters:**
- `_feeRecipient`: Address to receive vault creation fees

### Deployment Script

```javascript
async function deployVaultFactory() {
    const VaultFactory = await ethers.getContractFactory("Aetherweb3VaultFactory");

    // Deploy with fee recipient
    const factory = await VaultFactory.deploy(feeRecipientAddress);
    await factory.deployed();

    console.log("Vault Factory deployed to:", factory.address);
    return factory.address;
}
```

## Testing

### Unit Tests

```javascript
describe("Aetherweb3VaultFactory", function () {
    it("Should create vault with valid parameters", async function () {
        const params = {
            stakingToken: stakingToken.address,
            rewardToken: rewardToken.address,
            dao: dao.address,
            rewardRate: ethers.utils.parseEther("1"),
            emergencyPenalty: 1000,
            name: "Test Vault",
            symbol: "TEST-VAULT"
        };

        const tx = await factory.createVault(params, { value: creationFee });
        const receipt = await tx.wait();

        // Verify vault creation
        expect(receipt.events).to.have.lengthOf(1);
        expect(receipt.events[0].event).to.equal("VaultCreated");
    });

    it("Should reject invalid parameters", async function () {
        const invalidParams = {
            stakingToken: ethers.constants.AddressZero,
            rewardToken: rewardToken.address,
            dao: dao.address,
            rewardRate: 0,
            emergencyPenalty: 10000, // Too high
            name: "",
            symbol: "TEST"
        };

        await expect(factory.createVault(invalidParams)).to.be.reverted;
    });
});
```

## Gas Optimization

### Efficient Storage
- Uses mappings for O(1) lookups
- Arrays for enumeration with caching
- Packed structs for parameter storage

### Batch Operations
- Batch vault creation reduces gas costs
- Single transaction for multiple deployments
- Optimized loop structures

### Address Prediction
- Enables gas-efficient integrations
- Allows pre-computation of vault addresses
- Reduces need for additional storage

## Events

### `VaultCreated`
Emitted when a new vault is created.

```solidity
event VaultCreated(
    address indexed vault,
    address indexed creator,
    address stakingToken,
    address rewardToken,
    uint256 rewardRate
);
```

### `CreationFeeUpdated`
Emitted when creation fee is updated.

```solidity
event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
```

### `FeeRecipientUpdated`
Emitted when fee recipient is updated.

```solidity
event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
```

### `FactoryPaused`
Emitted when factory is paused.

```solidity
event FactoryPaused(address indexed account);
```

### `FactoryUnpaused`
Emitted when factory is unpaused.

```solidity
event FactoryUnpaused(address indexed account);
```

## Error Messages

- `"Aetherweb3VaultFactory: factory is paused"`: Factory is paused
- `"Aetherweb3VaultFactory: invalid address"`: Invalid address provided
- `"Aetherweb3VaultFactory: invalid staking token"`: Invalid staking token address
- `"Aetherweb3VaultFactory: invalid reward token"`: Invalid reward token address
- `"Aetherweb3VaultFactory: invalid DAO address"`: Invalid DAO address
- `"Aetherweb3VaultFactory: reward rate must be > 0"`: Reward rate is zero
- `"Aetherweb3VaultFactory: penalty too high"`: Emergency penalty exceeds maximum
- `"Aetherweb3VaultFactory: name required"`: Vault name is empty
- `"Aetherweb3VaultFactory: symbol required"`: Vault symbol is empty
- `"Aetherweb3VaultFactory: insufficient fee"`: Insufficient creation fee
- `"Aetherweb3VaultFactory: not a factory vault"`: Address is not a factory-created vault
- `"Aetherweb3VaultFactory: no balance to withdraw"`: No ETH balance to withdraw

## Future Enhancements

### Planned Features
- **Vault Templates**: Pre-configured vault templates for common use cases
- **Upgradeable Vaults**: Proxy-based vaults with upgrade capabilities
- **Cross-chain Deployment**: Multi-chain vault deployment support
- **Vault Analytics**: Built-in analytics and performance tracking
- **Automated Fee Adjustment**: Dynamic fee adjustment based on network conditions

### Integration Possibilities
- **Liquidity Mining**: Integration with AMM protocols
- **Insurance Pools**: Vault-based insurance mechanisms
- **NFT Staking**: NFT-backed staking vaults
- **DAO Treasury**: Treasury management through vault system
- **Cross-protocol Yield**: Multi-protocol yield aggregation
