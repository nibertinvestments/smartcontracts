# Aetherweb3 Modular Contracts System

A comprehensive modular contract system for the Aetherweb3 DeFi ecosystem featuring a leader contract that orchestrates 16 modular contract slots with advanced tuple-based execution hooks.

## 🌟 Overview

The Modular Contracts System is designed to provide maximum flexibility and composability while maintaining security and gas efficiency. The system consists of:

- **ModularLeader**: The orchestrator contract that manages 16 modular contract slots
- **Modular Contracts**: Gas-efficient, single-purpose contracts that do one thing well
- **Tuple System**: 16 execution hooks for lifecycle management
- **Interface System**: Standardized interfaces for seamless integration

## 📋 Key Features

### 🔧 Modular Architecture
- **16 Contract Slots**: Configurable contract slots with individual enable/disable controls
- **Single Responsibility**: Each modular contract focuses on one specific function
- **Gas Optimized**: Minimal overhead and efficient execution
- **Hot Swappable**: Contracts can be updated without system downtime

### 🎯 Tuple Execution System
The system provides 16 execution hooks that can be triggered at different stages:

| Tuple State | Description | Use Case |
|-------------|-------------|----------|
| `BEFORE_INIT` | Before contract initialization | Setup validation |
| `AFTER_INIT` | After contract initialization | Post-setup actions |
| `BEFORE_EXECUTE` | Before main execution | Pre-execution checks |
| `AFTER_EXECUTE` | After main execution | Post-execution cleanup |
| `BEFORE_VALIDATE` | Before validation | Input preprocessing |
| `AFTER_VALIDATE` | After validation | Validation result handling |
| `BEFORE_TRANSFER` | Before token transfers | Transfer authorization |
| `AFTER_TRANSFER` | After token transfers | Transfer logging |
| `BEFORE_MINT` | Before token minting | Minting limits |
| `AFTER_MINT` | After token minting | Minting events |
| `BEFORE_BURN` | Before token burning | Burn validation |
| `AFTER_BURN` | After token burning | Burn accounting |
| `BEFORE_SWAP` | Before token swaps | Swap validation |
| `AFTER_SWAP` | After token swaps | Swap settlement |
| `BEFORE_CLAIM` | Before reward claims | Claim validation |
| `AFTER_CLAIM` | After reward claims | Claim distribution |

### 🛡️ Security Features
- **Access Control**: Only owner can modify contract configuration
- **Emergency Controls**: Emergency stop functionality for all contracts
- **Input Validation**: Comprehensive parameter validation
- **Reentrancy Protection**: Built-in reentrancy guards
- **Pausable**: Emergency pause functionality

## 📁 Project Structure

```
contracts/modular/
├── ModularLeader.sol              # Main orchestrator contract
├── interfaces/
│   ├── IModularLeader.sol        # Leader contract interface
│   ├── IModularContract.sol      # Base modular contract interface
│   └── IModularTuple.sol         # Tuple system interface
└── contracts/
    ├── FeeCollectorModular.sol   # Fee collection contract
    ├── ValidatorModular.sol      # Parameter validation contract
    ├── LoggerModular.sol         # Event logging contract
    └── RewardDistributorModular.sol # Reward distribution contract
```

## 🚀 Quick Start

### 1. Deploy the Leader Contract

```solidity
// Deploy the ModularLeader contract
ModularLeader leader = new ModularLeader();
```

### 2. Deploy Modular Contracts

```solidity
// Deploy example modular contracts
FeeCollectorModular feeCollector = new FeeCollectorModular(
    address(leader),
    feeRecipientAddress
);

ValidatorModular validator = new ValidatorModular(address(leader));
LoggerModular logger = new LoggerModular(address(leader));

RewardDistributorModular rewardDistributor = new RewardDistributorModular(
    address(leader),
    rewardTokenAddress
);
```

### 3. Configure the Leader Contract

```solidity
// Create modular slot configurations
IModularLeader.ModularSlot[] memory slots = new IModularLeader.ModularSlot[](4);

slots[0] = IModularLeader.ModularSlot({
    contractAddress: address(feeCollector),
    enabled: true,
    name: "Fee Collector",
    contractType: keccak256("FEE_COLLECTOR")
});

slots[1] = IModularLeader.ModularSlot({
    contractAddress: address(validator),
    enabled: true,
    name: "Validator",
    contractType: keccak256("VALIDATOR")
});

slots[2] = IModularLeader.ModularSlot({
    contractAddress: address(logger),
    enabled: true,
    name: "Logger",
    contractType: keccak256("LOGGER")
});

slots[3] = IModularLeader.ModularSlot({
    contractAddress: address(rewardDistributor),
    enabled: true,
    name: "Reward Distributor",
    contractType: keccak256("REWARD_DISTRIBUTOR")
});

// Initialize the leader contract
leader.initialize(slots);
```

### 4. Configure Tuple System (Optional)

```solidity
// Enable specific tuple hooks
leader.setTupleState(IModularTuple.TupleState.BEFORE_EXECUTE, true);
leader.setTupleState(IModularTuple.TupleState.AFTER_EXECUTE, true);

// Assign contracts to tuple hooks
leader.setTupleContract(IModularTuple.TupleState.BEFORE_EXECUTE, address(validator));
leader.setTupleContract(IModularTuple.TupleState.AFTER_EXECUTE, address(logger));
```

### 5. Execute Modular Sequence

```solidity
// Prepare execution data
bytes memory executionData = abi.encode(
    userAddress,
    amount,
    block.timestamp
);

// Execute the modular contract sequence
(bool success, bytes[] memory results) = leader.executeSequence(executionData);

require(success, "Modular execution failed");
```

## 📖 API Reference

### ModularLeader Contract

#### Core Functions

```solidity
// Initialize with modular contracts
function initialize(ModularSlot[] calldata initialSlots) external

// Execute modular contract sequence
function executeSequence(bytes calldata executionData)
    external
    returns (bool success, bytes[] memory results)

// Set modular contract in slot
function setModularContract(
    uint8 slotIndex,
    address contractAddress,
    bool enabled,
    string calldata name
) external

// Get modular slot configuration
function getModularSlot(uint8 slotIndex)
    external
    view
    returns (ModularSlot memory slot)

// Enable/disable contract slot
function toggleSlot(uint8 slotIndex, bool enabled) external
```

#### Tuple System Functions

```solidity
// Execute tuple hook
function executeTuple(TupleState state, bytes calldata data)
    external
    returns (bool success, bytes memory result)

// Enable/disable tuple state
function setTupleState(TupleState state, bool enabled) external

// Set contract for tuple state
function setTupleContract(TupleState state, address contractAddress) external

// Get all tuple configurations
function getAllTuples()
    external
    view
    returns (
        TupleState[] memory states,
        bool[] memory enabled,
        address[] memory contracts
    )
```

#### Emergency Functions

```solidity
// Emergency stop all executions
function emergencyStop() external

// Resume executions
function emergencyResume() external

// Check emergency status
function isEmergencyStopped() external view returns (bool stopped)
```

### Modular Contract Interface

All modular contracts implement the `IModularContract` interface:

```solidity
function getContractName() external view returns (string memory)
function getContractVersion() external view returns (string memory)
function getContractType() external view returns (bytes32)
function execute(bytes calldata data) external returns (bool success, bytes memory result)
function validate(bytes calldata data) external view returns (bool valid)
function estimateGas(bytes calldata data) external view returns (uint256 gasEstimate)
function isActive() external view returns (bool active)
function getLeaderContract() external view returns (address leader)
function setPaused(bool paused) external
function getMetadata() external view returns (
    string memory name,
    string memory version,
    bytes32 contractType,
    bool active,
    address leader
)
```

## 🔧 Example Modular Contracts

### FeeCollectorModular

A gas-efficient contract for collecting and distributing fees:

```solidity
// Collect fees
bytes memory feeData = abi.encode(tokenAddress, amount);
(bool success,) = feeCollector.execute(feeData);

// Update fee recipient
feeCollector.updateFeeRecipient(newRecipient);
```

### ValidatorModular

Validates transaction parameters and conditions:

```solidity
// Set validation rules
validator.setMinAmount(100 * 10**18);
validator.setMaxAmount(10000 * 10**18);
validator.setRequiredSender(allowedSender);

// Validate parameters
bytes memory validationData = abi.encode(amount, sender, timestamp);
bool isValid = validator.validate(validationData);
```

### LoggerModular

Records events and transaction data:

```solidity
// Log an event
bytes memory logData = abi.encode(eventType, eventData);
(bool success,) = logger.execute(logData);

// Query logs
LoggerModular.LogEntry memory entry = logger.getLogEntry(index);
LoggerModular.LogEntry[] memory logs = logger.getLogsInTimeRange(startTime, endTime);
```

### RewardDistributorModular

Distributes rewards to eligible users:

```solidity
// Distribute rewards
bytes memory rewardData = abi.encode(userAddress, rewardAmount);
(bool success,) = rewardDistributor.execute(rewardData);

// User claims rewards
rewardDistributor.claimRewards(amount);

// Set user eligibility
rewardDistributor.setUserEligibility(userAddress, true);
```

## 🧪 Testing

### Run Tests

```bash
# Test the modular contracts system
npx hardhat test test/ModularLeader.test.js
npx hardhat test test/ModularContracts.test.js

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

### Test Coverage

```bash
npx hardhat coverage
```

## 📊 Gas Optimization

The modular system is designed for gas efficiency:

- **Minimal Overhead**: Leader contract adds ~5,000 gas per execution
- **Batch Operations**: Execute multiple contracts in single transaction
- **Optimized Storage**: Efficient state management
- **Lazy Evaluation**: Only execute enabled contracts

## 🔒 Security Considerations

### Access Control
- Only contract owner can modify configuration
- Modular contracts validate caller permissions
- Emergency controls for critical situations

### Input Validation
- Comprehensive parameter validation
- Bounds checking for all inputs
- Safe math operations

### Emergency Features
- Emergency stop for all contract executions
- Emergency pause for individual contracts
- Emergency withdrawal functions

## 🚀 Deployment

### Local Development

```bash
# Start local Hardhat network
npx hardhat node

# Deploy modular contracts
npx hardhat run scripts/deploy-modular.js --network localhost
```

### Testnet Deployment

```bash
# Deploy to Sepolia
npx hardhat run scripts/deploy-modular.js --network sepolia

# Deploy to other testnets
npx hardhat run scripts/deploy-modular.js --network <network-name>
```

### Mainnet Deployment

```bash
# Deploy to mainnet (use with caution)
npx hardhat run scripts/deploy-modular.js --network mainnet
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file:

```env
# Network Configuration
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY
TESTNET_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY

# Private Key (NEVER commit this)
PRIVATE_KEY=0x...

# Contract Addresses
FEE_RECIPIENT=0x...
REWARD_TOKEN=0x...
```

### Hardhat Configuration

The system supports multiple networks in `hardhat.config.js`:

```javascript
module.exports = {
  networks: {
    mainnet: { ... },
    sepolia: { ... },
    polygon: { ... },
    // Add more networks as needed
  }
};
```

## 📈 Use Cases

### DeFi Protocol
- **Automated Market Maker**: Use validator for trade validation, logger for trade records
- **Yield Farming**: Reward distributor for farming rewards, fee collector for protocol fees
- **Lending Protocol**: Validator for loan parameters, logger for loan events

### NFT Marketplace
- **Minting**: Validator for minting rules, fee collector for platform fees
- **Trading**: Logger for trade history, reward distributor for trading incentives
- **Royalties**: Fee collector for creator royalties

### DAO Governance
- **Proposal Validation**: Validator for proposal parameters
- **Voting Records**: Logger for voting history
- **Reward Distribution**: Reward distributor for voter incentives

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Update documentation
5. Submit a pull request

### Development Guidelines

- Follow Solidity style guide
- Write gas-efficient code
- Add comprehensive tests
- Update documentation
- Use descriptive commit messages

## 📄 License

This project is licensed under the GPL-2.0-or-later License - see the [LICENSE](../LICENSE) file for details.

## 🙋 Support

- **Documentation**: [Aetherweb3 Modular Docs](./docs/modular/)
- **GitHub Issues**: [Report bugs and request features](https://github.com/nibertinvestments/smartcontracts/issues)
- **Discord**: [Join our community](https://discord.gg/aetherweb3)

---

**Built with ❤️ for the Aetherweb3 ecosystem - Maximum modularity, minimum complexity**
