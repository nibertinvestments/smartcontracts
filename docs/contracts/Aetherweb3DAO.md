# Aetherweb3DAO

## Overview

Aetherweb3DAO is a decentralized autonomous organization that enables governance of the Aetherweb3 DeFi ecosystem. It allows Aetherweb3Token holders to create proposals, vote on them, and execute approved proposals through a timelock mechanism.

## Features

- **Proposal Creation**: Token holders can create governance proposals
- **Voting System**: Quadratic voting based on token holdings
- **Timelock Execution**: Delayed execution for security
- **Quorum Requirements**: Minimum participation thresholds
- **Gasless Voting**: Support for meta-transaction voting
- **Proposal Cancellation**: Emergency proposal cancellation

## Contract Details

### Constructor Parameters

```solidity
constructor(address _governanceToken, address _timelock)
```

- `_governanceToken`: Address of the Aetherweb3Token contract
- `_timelock`: Address of the Aetherweb3Timelock contract

### Governance Parameters

- **VOTING_PERIOD**: 7 days voting period
- **VOTING_DELAY**: 1 day delay before voting starts
- **PROPOSAL_THRESHOLD**: 100,000 tokens to create proposal
- **QUORUM_PERCENTAGE**: 10% of total supply needed

### Key Functions

#### Proposal Management

- `propose(targets, values, calldatas, description)`: Create a new proposal
- `execute(proposalId)`: Execute a successful proposal
- `cancel(proposalId)`: Cancel a pending proposal

#### Voting Functions

- `castVote(proposalId, support)`: Cast a vote (0=Against, 1=For, 2=Abstain)
- `castVoteWithReason(proposalId, support, reason)`: Vote with reason
- `castVoteBySig(proposalId, support, v, r, s)`: Gasless voting with signature

#### View Functions

- `state(proposalId)`: Get proposal state (Pending, Active, Succeeded, etc.)
- `getProposal(proposalId)`: Get detailed proposal information
- `getReceipt(proposalId, voter)`: Get voting receipt for a voter

## Usage Examples

### Creating a Proposal

```solidity
// Create a proposal to update the staking reward rate
address[] memory targets = new address[](1);
targets[0] = stakingVaultAddress;

uint256[] memory values = new uint256[](1);
values[0] = 0;

bytes[] memory calldatas = new bytes[](1);
calldatas[0] = abi.encodeWithSignature("setRewardRate(uint256)", newRate);

string memory description = "Update staking reward rate to 10% APR";

uint256 proposalId = dao.propose(targets, values, calldatas, description);
```

### Voting on a Proposal

```solidity
// Cast a vote in favor
dao.castVote(proposalId, 1);

// Or vote with a reason
dao.castVoteWithReason(proposalId, 1, "This will improve protocol sustainability");
```

### Executing a Proposal

```solidity
// Check if proposal can be executed
if (dao.state(proposalId) == IAetherweb3DAO.ProposalState.Succeeded) {
    dao.execute(proposalId);
}
```

## Deployment

### Prerequisites

- Aetherweb3Token contract deployed
- Aetherweb3Timelock contract deployed
- Governance token supply distributed

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    // Deploy Timelock first
    const Timelock = await ethers.getContractFactory("Aetherweb3Timelock");
    const timelock = await Timelock.deploy(2 * 24 * 3600); // 2 days delay
    await timelock.deployed();

    // Deploy DAO
    const DAO = await ethers.getContractFactory("Aetherweb3DAO");
    const dao = await DAO.deploy(tokenAddress, timelock.address);
    await dao.deployed();

    // Transfer timelock ownership to DAO
    await timelock.transferOwnership(dao.address);

    console.log("Aetherweb3DAO deployed to:", dao.address);
    console.log("Aetherweb3Timelock deployed to:", timelock.address);
}
```

## Security Considerations

- **Proposal Threshold**: Prevents spam proposals
- **Voting Delay**: Allows time for review before voting
- **Quorum Requirements**: Ensures sufficient participation
- **Timelock**: Prevents flash loan attacks on governance
- **Access Control**: Only authorized addresses can execute

## Integration Guide

### With Aetherweb3Token

```solidity
// Check voting power
uint256 votingPower = governanceToken.balanceOf(voterAddress);

// Use in governance calculations
uint256 totalSupply = governanceToken.totalSupply();
uint256 quorumRequired = (totalSupply * QUORUM_PERCENTAGE) / 100;
```

### With Aetherweb3Timelock

```solidity
// Queue proposal execution
bytes32 txHash = timelock.queueTransaction(
    target,
    value,
    data,
    block.timestamp + delay
);

// Execute after delay
timelock.executeTransaction(target, value, data, eta);
```

## Events

- `ProposalCreated(uint256 indexed proposalId, address indexed proposer, ...)`
- `VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 votes, string reason)`
- `ProposalExecuted(uint256 indexed proposalId)`
- `ProposalCanceled(uint256 indexed proposalId)`

## Gas Optimization

- Efficient proposal storage
- Batch voting support
- Minimal state changes
- Optimized view functions

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3DAO.test.js
```

### Test Coverage

- Proposal creation and execution
- Voting mechanisms
- Quorum calculations
- Timelock integration
- Access control
- Emergency functions

## License

This contract is licensed under the MIT License.
