# Aetherweb3StakingVault

## Overview

Aetherweb3StakingVault is a sophisticated staking contract that allows users to stake Aetherweb3Tokens and earn rewards. It features multiple lock periods with different reward multipliers, emergency unstaking options, and integration with the DAO for governance.

## Features

- **Flexible Staking**: Multiple lock periods with reward multipliers
- **Reward Distribution**: Automated reward calculation and claiming
- **Emergency Unstaking**: Penalty-based early withdrawal option
- **Lock Multipliers**: Higher rewards for longer lock periods
- **DAO Integration**: Governance-controlled parameters
- **Gas Optimized**: Efficient reward calculations

## Contract Details

### Constructor Parameters

```solidity
constructor(address _stakingToken, address _rewardToken, address _dao)
```

- `_stakingToken`: Address of the token to be staked (Aetherweb3Token)
- `_rewardToken`: Address of the reward token
- `_dao`: Address of the Aetherweb3DAO contract

### Lock Periods

| Period | Duration | Multiplier | APR Boost |
|--------|----------|------------|-----------|
| No Lock | 0 days | 100% | Base rate |
| Short | 30 days | 110% | +10% |
| Medium | 90 days | 125% | +25% |
| Long | 180 days | 150% | +50% |

### Key Functions

#### Staking Functions

- `stake(amount, lockPeriodId)`: Stake tokens with lock period
- `unstake(amount)`: Unstake tokens after lock period
- `emergencyUnstake(amount)`: Emergency unstake with penalty

#### Reward Functions

- `claimReward()`: Claim accumulated rewards
- `earned(account)`: Get earned rewards for account

#### View Functions

- `getStakeInfo(account)`: Get staking information
- `getLockMultiplier(account)`: Get current lock multiplier
- `getAPR(lockPeriodId)`: Get APR for lock period
- `rewardPerToken()`: Get current reward per token

## Usage Examples

### Basic Staking

```solidity
// Approve tokens for staking
stakingToken.approve(stakingVault.address, amount);

// Stake with 90-day lock for 25% bonus
stakingVault.stake(amount, 90 days);
```

### Claiming Rewards

```solidity
// Check earned rewards
uint256 rewards = stakingVault.earned(userAddress);

// Claim rewards
if (rewards > 0) {
    stakingVault.claimReward();
}
```

### Emergency Unstaking

```solidity
// Emergency unstake with 10% penalty
uint256 penalty = (amount * 1000) / 10000; // 10%
uint256 returnAmount = amount - penalty;

stakingVault.emergencyUnstake(amount);
```

## Deployment

### Prerequisites

- Aetherweb3Token contract deployed
- Reward token contract deployed
- Aetherweb3DAO contract deployed
- Reward tokens allocated to vault

### Deployment Script

```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    // Contract addresses
    const STAKING_TOKEN = "0x..."; // Aetherweb3Token
    const REWARD_TOKEN = "0x..."; // Reward token
    const DAO = "0x..."; // Aetherweb3DAO

    console.log("Deploying Aetherweb3StakingVault...");

    const StakingVault = await ethers.getContractFactory("Aetherweb3StakingVault");
    const vault = await StakingVault.deploy(STAKING_TOKEN, REWARD_TOKEN, DAO);
    await vault.deployed();

    // Set initial reward rate (rewards per second)
    const rewardRate = ethers.utils.parseEther("1").div(86400); // 1 token per day
    await vault.setRewardRate(rewardRate);

    // Transfer reward tokens to vault
    const rewardAmount = ethers.utils.parseEther("100000"); // 100k tokens
    await rewardToken.transfer(vault.address, rewardAmount);

    console.log("Aetherweb3StakingVault deployed to:", vault.address);
}
```

## Security Considerations

- **Reentrancy Protection**: Guards against reentrancy attacks
- **Access Control**: DAO-controlled parameter updates
- **Penalty System**: Discourages emergency unstaking
- **Lock Periods**: Prevents immediate withdrawals
- **Input Validation**: Comprehensive parameter validation

## Integration Guide

### With Aetherweb3DAO

```solidity
// DAO proposal to update reward rate
address[] memory targets = [stakingVault.address];
uint256[] memory values = [0];
bytes[] memory calldatas = [abi.encodeWithSignature("setRewardRate(uint256)", newRate)];

dao.propose(targets, values, calldatas, "Update staking reward rate");
```

### With Frontend Applications

```javascript
// Get staking information
const stakeInfo = await vault.getStakeInfo(userAddress);
const earned = await vault.earned(userAddress);
const apr = await vault.getAPR(90 * 24 * 3600); // 90 days

// Calculate projected rewards
const projectedRewards = (stakedAmount * apr * lockDays) / (365 * 10000);
```

### With Reward Distribution

```solidity
// Distribute rewards periodically
contract RewardDistributor {
    function distributeRewards() external {
        uint256 rewardAmount = calculateRewards();
        rewardToken.mint(vault.address, rewardAmount);
        vault.setRewardRate(newRate);
    }
}
```

## Events

- `Staked(address indexed user, uint256 amount, uint256 lockPeriod)`
- `Unstaked(address indexed user, uint256 amount, bool emergency)`
- `RewardClaimed(address indexed user, uint256 amount)`
- `RewardRateUpdated(uint256 oldRate, uint256 newRate)`

## Gas Optimization

- Efficient reward calculations
- Minimal storage operations
- Batch processing support
- Optimized view functions

## Testing

Run the test suite:

```bash
npx hardhat test test/Aetherweb3StakingVault.test.js
```

### Test Coverage

- Staking and unstaking
- Reward calculations
- Lock period mechanics
- Emergency unstaking
- DAO integration
- Access control
- Edge cases

## License

This contract is licensed under the MIT License.
