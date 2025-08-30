# Aetherweb3Timelock

## Overview

Aetherweb3Timelock is a timelock contract that provides delayed execution of governance proposals. It acts as a security mechanism to prevent flash loan attacks and allows time for review and potential cancellation of malicious proposals.

## Features

- **Delayed Execution**: Configurable delay before execution
- **Grace Period**: Time window for execution after delay
- **Transaction Queuing**: Queue transactions for future execution
- **Emergency Cancellation**: Cancel queued transactions
- **Multi-Executor Support**: Multiple authorized executors
- **ETH Support**: Handle ETH value transactions

## Contract Details

### Constructor Parameters

```solidity
constructor(uint256 _delay)
```

- `_delay`: Initial delay period for transaction execution

### Time Parameters

- **MINIMUM_DELAY**: 2 days minimum delay
- **MAXIMUM_DELAY**: 30 days maximum delay
- **GRACE_PERIOD**: 14 days execution window

### Key Functions

#### Transaction Management

- `queueTransaction(target, value, data, eta)`: Queue transaction for execution
- `executeTransaction(target, value, data, eta)`: Execute queued transaction
- `cancelTransaction(target, value, data, eta)`: Cancel queued transaction

#### View Functions

- `getTransaction(txHash)`: Get transaction details
- `isTransactionReady(txHash)`: Check if transaction can be executed

#### Admin Functions

- `setDelay(newDelay)`: Update delay period
- `authorizeExecutor(executor)`: Add authorized executor
- `revokeExecutor(executor)`: Remove executor authorization

## Usage Examples

### Queuing a Transaction

```solidity
// Queue a transaction with 2-day delay
uint256 eta = block.timestamp + 2 days;
bytes32 txHash = timelock.queueTransaction(
    targetContract,
    0, // No ETH
    abi.encodeWithSignature("updateParameter(uint256)", newValue),
    eta
);
```

### Executing a Transaction

```solidity
// Execute after delay period
bytes memory result = timelock.executeTransaction(
    targetContract,
    0,
    abi.encodeWithSignature("updateParameter(uint256)", newValue),
    eta
);
```

### Emergency Cancellation

```solidity
// Cancel a malicious transaction
timelock.cancelTransaction(
    targetContract,
    0,
    abi.encodeWithSignature("updateParameter(uint256)", newValue),
    eta
);
```

## Deployment

### Prerequisites

- Aetherweb3DAO contract deployed
- Authorized executors identified
- Delay period determined

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    // 2 days delay (172800 seconds)
    const DELAY = 2 * 24 * 3600;

    console.log("Deploying Aetherweb3Timelock...");

    const Timelock = await ethers.getContractFactory("Aetherweb3Timelock");
    const timelock = await Timelock.deploy(DELAY);
    await timelock.deployed();

    // Authorize DAO as executor
    await timelock.authorizeExecutor(daoAddress);

    console.log("Aetherweb3Timelock deployed to:", timelock.address);
}
```

## Security Considerations

- **Delay Protection**: Prevents flash loan governance attacks
- **Grace Period**: Allows execution within reasonable timeframe
- **Access Control**: Only authorized executors can queue/execute
- **Cancellation Rights**: Emergency cancellation capabilities
- **Input Validation**: Comprehensive parameter validation

## Integration Guide

### With Aetherweb3DAO

```solidity
// DAO executes proposal through timelock
function executeProposal(uint256 proposalId) external {
    Proposal storage proposal = proposals[proposalId];

    // Queue each action in timelock
    for (uint256 i = 0; i < proposal.targets.length; i++) {
        timelock.queueTransaction(
            proposal.targets[i],
            proposal.values[i],
            proposal.calldatas[i],
            block.timestamp + delay
        );
    }
}
```

### With Multi-Sig Wallets

```solidity
// Multi-sig can queue critical operations
contract MultiSigTimelock {
    function queueCriticalUpdate(
        address target,
        bytes memory data
    ) external onlyMultiSig {
        uint256 eta = block.timestamp + timelock.delay();
        timelock.queueTransaction(target, 0, data, eta);
    }
}
```

### With Frontend Applications

```javascript
// Check transaction status
const txDetails = await timelock.getTransaction(txHash);
const isReady = await timelock.isTransactionReady(txHash);

if (isReady && !txDetails.executed) {
    // Execute transaction
    await timelock.executeTransaction(target, value, data, eta);
}
```

## Events

- `TransactionQueued(bytes32 indexed txHash, address indexed target, uint256 value, bytes data, uint256 eta)`
- `TransactionExecuted(bytes32 indexed txHash, address indexed target, uint256 value, bytes data)`
- `TransactionCanceled(bytes32 indexed txHash)`
- `DelayUpdated(uint256 oldDelay, uint256 newDelay)`

## Gas Optimization

- Efficient transaction storage
- Minimal state changes
- Optimized execution path
- Batch operation support

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3Timelock.test.js
```

### Test Coverage

- Transaction queuing and execution
- Delay and grace period mechanics
- Access control and authorization
- Emergency cancellation
- Multi-executor scenarios
- Edge cases and error handling

## License

This contract is licensed under the MIT License.
