// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";

/**
 * @title Aetherweb3Staking
 * @dev Staking utility library for reward calculations and staking mechanics
 * @notice Provides staking reward calculations, lock multipliers, and staking utilities
 */
library Aetherweb3Staking {
    using Aetherweb3Math for uint256;

    // Staking lock periods
    struct LockPeriod {
        uint256 duration;    // Duration in seconds
        uint256 multiplier;  // Reward multiplier in wad (1e18 = 100%)
        string name;         // Human-readable name
    }

    // User staking position
    struct StakingPosition {
        uint256 amount;           // Staked amount
        uint256 lockPeriod;       // Lock duration in seconds
        uint256 lockMultiplier;   // Applied multiplier
        uint256 startTime;        // When staking started
        uint256 endTime;          // When staking ends
        uint256 lastRewardTime;   // Last time rewards were claimed
        uint256 accumulatedRewards; // Accumulated rewards
        bool emergencyUnlocked;   // If emergency withdrawal was used
    }

    // Pool reward information
    struct RewardPool {
        uint256 totalStaked;      // Total tokens staked
        uint256 rewardRate;       // Rewards per second
        uint256 lastUpdateTime;   // Last time rewards were updated
        uint256 rewardPerTokenStored; // Accumulated rewards per token
        uint256 emergencyPenalty; // Emergency withdrawal penalty (basis points)
    }

    // User reward information
    struct UserRewardInfo {
        uint256 rewardPerTokenPaid; // Rewards per token paid
        uint256 rewards;            // Accumulated rewards
    }

    /**
     * @dev Calculates reward multiplier based on lock duration
     * @param lockDuration Lock duration in seconds
     * @param lockPeriods Array of available lock periods
     * @return multiplier Reward multiplier in wad
     */
    function calculateLockMultiplier(
        uint256 lockDuration,
        LockPeriod[] memory lockPeriods
    ) internal pure returns (uint256 multiplier) {
        multiplier = Aetherweb3Math.WAD; // Default 100%

        for (uint256 i = 0; i < lockPeriods.length; i++) {
            if (lockDuration >= lockPeriods[i].duration) {
                multiplier = Aetherweb3Math.max(multiplier, lockPeriods[i].multiplier);
            }
        }
    }

    /**
     * @dev Calculates staking rewards for a position
     * @param position User's staking position
     * @param rewardPool Pool reward information
     * @param currentTime Current timestamp
     * @return rewards Calculated rewards
     */
    function calculateStakingRewards(
        StakingPosition memory position,
        RewardPool memory rewardPool,
        uint256 currentTime
    ) internal pure returns (uint256 rewards) {
        if (position.amount == 0) return 0;

        // Calculate time elapsed since last reward update
        uint256 timeElapsed = Aetherweb3Math.min(
            currentTime - position.lastRewardTime,
            position.endTime - position.lastRewardTime
        );

        if (timeElapsed == 0) return 0;

        // Calculate base rewards
        uint256 baseRewards = position.amount
            .wmul(rewardPool.rewardRate)
            .wmul(timeElapsed);

        // Apply lock multiplier
        rewards = baseRewards.wmul(position.lockMultiplier);

        return rewards;
    }

    /**
     * @dev Calculates emergency withdrawal penalty
     * @param position User's staking position
     * @param rewardPool Pool reward information
     * @param currentTime Current timestamp
     * @return penaltyAmount Amount to deduct as penalty
     */
    function calculateEmergencyPenalty(
        StakingPosition memory position,
        RewardPool memory rewardPool,
        uint256 currentTime
    ) internal pure returns (uint256 penaltyAmount) {
        if (currentTime >= position.endTime) return 0; // No penalty if lock expired

        uint256 remainingTime = position.endTime - currentTime;
        uint256 totalLockTime = position.endTime - position.startTime;

        // Calculate penalty based on remaining time
        uint256 penaltyPercentage = Aetherweb3Math.wmul(
            rewardPool.emergencyPenalty * Aetherweb3Math.WAD / 10000,
            remainingTime
        ) / totalLockTime;

        penaltyAmount = position.amount.wmul(penaltyPercentage);
        return penaltyAmount;
    }

    /**
     * @dev Updates reward pool information
     * @param rewardPool Current pool state
     * @param currentTime Current timestamp
     * @return updatedPool Updated pool state
     */
    function updateRewardPool(
        RewardPool memory rewardPool,
        uint256 currentTime
    ) internal pure returns (RewardPool memory updatedPool) {
        updatedPool = rewardPool;

        if (rewardPool.totalStaked == 0) {
            updatedPool.lastUpdateTime = currentTime;
            return updatedPool;
        }

        uint256 timeElapsed = currentTime - rewardPool.lastUpdateTime;
        uint256 rewardPerToken = rewardPool.rewardRate
            .wmul(timeElapsed)
            .wdiv(rewardPool.totalStaked);

        updatedPool.rewardPerTokenStored = rewardPool.rewardPerTokenStored + rewardPerToken;
        updatedPool.lastUpdateTime = currentTime;

        return updatedPool;
    }

    /**
     * @dev Calculates earned rewards for a user
     * @param amount User's staked amount
     * @param rewardPerTokenStored Current reward per token
     * @param userRewardPerTokenPaid User's last paid reward per token
     * @param userRewards User's accumulated rewards
     * @return earned Total earned rewards
     */
    function calculateEarnedRewards(
        uint256 amount,
        uint256 rewardPerTokenStored,
        uint256 userRewardPerTokenPaid,
        uint256 userRewards
    ) internal pure returns (uint256 earned) {
        uint256 rewardPerTokenDiff = rewardPerTokenStored - userRewardPerTokenPaid;
        uint256 newRewards = amount.wmul(rewardPerTokenDiff);
        earned = userRewards + newRewards;
        return earned;
    }

    /**
     * @dev Calculates APY (Annual Percentage Yield)
     * @param rewardRate Rewards per second
     * @param totalStaked Total tokens staked
     * @return apy Annual percentage yield in wad
     */
    function calculateAPY(
        uint256 rewardRate,
        uint256 totalStaked
    ) internal pure returns (uint256 apy) {
        if (totalStaked == 0) return 0;

        uint256 yearlyRewards = rewardRate * 365 days;
        apy = yearlyRewards.wdiv(totalStaked);
        return apy;
    }

    /**
     * @dev Calculates APR (Annual Percentage Rate)
     * @param rewardRate Rewards per second
     * @param totalStaked Total tokens staked
     * @return apr Annual percentage rate in wad
     */
    function calculateAPR(
        uint256 rewardRate,
        uint256 totalStaked
    ) internal pure returns (uint256 apr) {
        return calculateAPY(rewardRate, totalStaked);
    }

    /**
     * @dev Validates staking parameters
     * @param amount Amount to stake
     * @param lockDuration Lock duration
     * @param minStakeAmount Minimum stake amount
     * @param maxLockDuration Maximum lock duration
     * @return valid True if parameters are valid
     */
    function validateStakingParams(
        uint256 amount,
        uint256 lockDuration,
        uint256 minStakeAmount,
        uint256 maxLockDuration
    ) internal pure returns (bool valid) {
        if (amount < minStakeAmount) return false;
        if (lockDuration > maxLockDuration) return false;
        if (amount == 0) return false;
        return true;
    }

    /**
     * @dev Calculates compound rewards over time
     * @param principal Initial stake amount
     * @param rewardRate Reward rate per second
     * @param lockMultiplier Lock multiplier
     * @param timePeriod Time period in seconds
     * @return compoundRewards Total compound rewards
     */
    function calculateCompoundRewards(
        uint256 principal,
        uint256 rewardRate,
        uint256 lockMultiplier,
        uint256 timePeriod
    ) internal pure returns (uint256 compoundRewards) {
        uint256 effectiveRate = rewardRate.wmul(lockMultiplier);
        uint256 totalAmount = principal.wmul(
            Aetherweb3Math.WAD + effectiveRate.wmul(timePeriod)
        );
        compoundRewards = totalAmount - principal;
        return compoundRewards;
    }

    /**
     * @dev Gets staking efficiency metrics
     * @param position User's staking position
     * @param rewardPool Pool information
     * @param currentTime Current timestamp
     * @return efficiency Staking efficiency percentage in wad
     * @return projectedRewards Projected rewards for full period
     */
    function getStakingEfficiency(
        StakingPosition memory position,
        RewardPool memory rewardPool,
        uint256 currentTime
    ) internal pure returns (uint256 efficiency, uint256 projectedRewards) {
        uint256 totalLockTime = position.endTime - position.startTime;
        uint256 elapsedTime = currentTime - position.startTime;

        if (totalLockTime == 0) return (0, 0);

        efficiency = elapsedTime.wdiv(totalLockTime);

        uint256 fullPeriodRewards = calculateStakingRewards(
            position,
            rewardPool,
            position.endTime
        );

        projectedRewards = fullPeriodRewards.wmul(efficiency);
        return (efficiency, projectedRewards);
    }
}
