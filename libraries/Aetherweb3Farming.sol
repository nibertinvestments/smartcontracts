// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Staking.sol";

/**
 * @title Aetherweb3Farming
 * @dev Yield farming utility library for farming strategy calculations
 * @notice Provides farming reward calculations, APY/APR computations, and farming optimizations
 */
library Aetherweb3Farming {
    using Aetherweb3Math for uint256;
    using Aetherweb3Staking for uint256;

    // Farming pool information
    struct FarmingPool {
        address stakingToken;     // Token to stake
        address rewardToken;      // Token to reward
        uint256 totalStaked;      // Total tokens staked
        uint256 rewardRate;       // Rewards per second
        uint256 lastUpdateTime;   // Last reward update
        uint256 rewardPerTokenStored; // Accumulated rewards per token
        uint256 totalRewards;     // Total rewards allocated
        uint256 remainingRewards; // Remaining rewards to distribute
        uint256 startTime;        // Farming start time
        uint256 endTime;         // Farming end time
        bool isActive;           // Whether pool is active
    }

    // User farming position
    struct FarmingPosition {
        uint256 amount;           // Staked amount
        uint256 rewardPerTokenPaid; // Rewards per token paid
        uint256 rewards;          // Accumulated rewards
        uint256 lastUpdateTime;   // Last position update
        uint256 lockEndTime;      // Lock end time
        uint256 multiplier;       // Reward multiplier
    }

    // Farming strategy
    struct FarmingStrategy {
        address[] pools;          // Pool addresses
        uint256[] allocations;    // Allocation percentages
        uint256 rebalanceThreshold; // Rebalance threshold
        uint256 lastRebalanceTime; // Last rebalance time
        bool autoCompound;        // Auto-compound rewards
        bool autoRebalance;       // Auto-rebalance allocations
    }

    /**
     * @dev Updates farming pool rewards
     * @param pool Current pool state
     * @param currentTime Current timestamp
     * @return updatedPool Updated pool state
     */
    function updatePoolRewards(
        FarmingPool memory pool,
        uint256 currentTime
    ) internal pure returns (FarmingPool memory updatedPool) {
        updatedPool = pool;

        if (!pool.isActive || pool.totalStaked == 0) {
            updatedPool.lastUpdateTime = currentTime;
            return updatedPool;
        }

        uint256 timeElapsed = Aetherweb3Math.min(
            currentTime - pool.lastUpdateTime,
            pool.endTime - pool.lastUpdateTime
        );

        if (timeElapsed == 0) {
            updatedPool.lastUpdateTime = currentTime;
            return updatedPool;
        }

        uint256 rewardsToDistribute = pool.rewardRate * timeElapsed;
        uint256 actualRewards = Aetherweb3Math.min(rewardsToDistribute, pool.remainingRewards);

        uint256 rewardPerToken = actualRewards.wdiv(pool.totalStaked);
        updatedPool.rewardPerTokenStored = pool.rewardPerTokenStored + rewardPerToken;
        updatedPool.remainingRewards = pool.remainingRewards - actualRewards;
        updatedPool.lastUpdateTime = currentTime;

        return updatedPool;
    }

    /**
     * @dev Calculates farming APY
     * @param pool Farming pool
     * @param stakingTokenPrice Price of staking token
     * @param rewardTokenPrice Price of reward token
     * @return apy Annual percentage yield
     */
    function calculateFarmingAPY(
        FarmingPool memory pool,
        uint256 stakingTokenPrice,
        uint256 rewardTokenPrice
    ) internal pure returns (uint256 apy) {
        if (pool.totalStaked == 0 || stakingTokenPrice == 0) return 0;

        uint256 yearlyRewards = pool.rewardRate * 365 days;
        uint256 yearlyRewardsValue = yearlyRewards.wmul(rewardTokenPrice);
        uint256 totalStakedValue = pool.totalStaked.wmul(stakingTokenPrice);

        apy = yearlyRewardsValue.wdiv(totalStakedValue);
    }

    /**
     * @dev Calculates farming APR
     * @param pool Farming pool
     * @param stakingTokenPrice Price of staking token
     * @param rewardTokenPrice Price of reward token
     * @return apr Annual percentage rate
     */
    function calculateFarmingAPR(
        FarmingPool memory pool,
        uint256 stakingTokenPrice,
        uint256 rewardTokenPrice
    ) internal pure returns (uint256 apr) {
        return calculateFarmingAPY(pool, stakingTokenPrice, rewardTokenPrice);
    }

    /**
     * @dev Calculates user farming rewards
     * @param position User farming position
     * @param pool Farming pool
     * @param currentTime Current timestamp
     * @return rewards Calculated rewards
     */
    function calculateFarmingRewards(
        FarmingPosition memory position,
        FarmingPool memory pool,
        uint256 currentTime
    ) internal pure returns (uint256 rewards) {
        if (position.amount == 0) return 0;

        uint256 rewardPerTokenDiff = pool.rewardPerTokenStored - position.rewardPerTokenPaid;
        uint256 newRewards = position.amount.wmul(rewardPerTokenDiff).wmul(position.multiplier);

        rewards = position.rewards + newRewards;
    }

    /**
     * @dev Calculates optimal farming allocation across multiple pools
     * @param pools Array of farming pools
     * @param totalAmount Total amount to allocate
     * @param riskTolerance Risk tolerance (0-100, higher = more risk)
     * @return allocations Optimal allocations for each pool
     */
    function calculateOptimalAllocations(
        FarmingPool[] memory pools,
        uint256 totalAmount,
        uint256 riskTolerance
    ) internal pure returns (uint256[] memory allocations) {
        allocations = new uint256[](pools.length);

        if (pools.length == 0) return allocations;

        // Simplified allocation based on APY and risk
        // In practice, this would use more sophisticated algorithms
        uint256 totalWeight = 0;
        uint256[] memory weights = new uint256[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            if (!pools[i].isActive) continue;

            // Weight = APY * (1 + riskTolerance/100)
            // Simplified APY calculation
            uint256 apy = pools[i].rewardRate * 365 days * 100 / pools[i].totalStaked;
            uint256 weight = apy * (100 + riskTolerance) / 100;
            weights[i] = weight;
            totalWeight += weight;
        }

        if (totalWeight == 0) return allocations;

        for (uint256 i = 0; i < pools.length; i++) {
            allocations[i] = totalAmount * weights[i] / totalWeight;
        }
    }

    /**
     * @dev Calculates impermanent loss for liquidity farming
     * @param initialPriceRatio Initial price ratio
     * @param currentPriceRatio Current price ratio
     * @return impermanentLoss IL percentage
     */
    function calculateImpermanentLoss(
        uint256 initialPriceRatio,
        uint256 currentPriceRatio
    ) internal pure returns (uint256 impermanentLoss) {
        if (initialPriceRatio == 0 || currentPriceRatio == 0) return 0;

        uint256 ratio = currentPriceRatio.wdiv(initialPriceRatio);
        uint256 sqrtRatio = Aetherweb3Math.sqrt(ratio);

        // IL = 2*sqrt(ratio)/(1+ratio) - 1
        uint256 numerator = 2 * sqrtRatio;
        uint256 denominator = Aetherweb3Math.WAD + ratio;
        uint256 value = numerator.wdiv(denominator);

        if (value < Aetherweb3Math.WAD) {
            impermanentLoss = Aetherweb3Math.WAD - value;
        } else {
            impermanentLoss = 0;
        }
    }

    /**
     * @dev Calculates farming efficiency
     * @param rewardsEarned Total rewards earned
     * @param gasCosts Total gas costs
     * @param timeElapsed Time elapsed
     * @return efficiency Farming efficiency percentage
     */
    function calculateFarmingEfficiency(
        uint256 rewardsEarned,
        uint256 gasCosts,
        uint256 timeElapsed
    ) internal pure returns (uint256 efficiency) {
        if (rewardsEarned == 0) return 0;

        uint256 netRewards = rewardsEarned > gasCosts ? rewardsEarned - gasCosts : 0;
        uint256 rewardRate = netRewards.wdiv(timeElapsed);

        // Efficiency as percentage of optimal reward rate
        // Simplified calculation
        efficiency = rewardRate * 100 / rewardsEarned;
    }

    /**
     * @dev Validates farming pool parameters
     * @param pool Farming pool to validate
     * @param currentTime Current timestamp
     * @return isValid True if pool is valid
     */
    function validateFarmingPool(
        FarmingPool memory pool,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (pool.stakingToken == address(0)) return false;
        if (pool.rewardToken == address(0)) return false;
        if (pool.startTime >= pool.endTime) return false;
        if (currentTime < pool.startTime) return false;
        if (pool.rewardRate == 0) return false;
        return true;
    }

    /**
     * @dev Calculates compound farming rewards
     * @param principal Initial stake amount
     * @param rewardRate Reward rate per second
     * @param compoundFrequency Compound frequency in seconds
     * @param timePeriod Total time period
     * @return compoundRewards Total compound rewards
     */
    function calculateCompoundFarmingRewards(
        uint256 principal,
        uint256 rewardRate,
        uint256 compoundFrequency,
        uint256 timePeriod
    ) internal pure returns (uint256 compoundRewards) {
        if (compoundFrequency == 0 || timePeriod == 0) return 0;

        uint256 periods = timePeriod / compoundFrequency;
        uint256 effectiveRate = rewardRate * compoundFrequency;

        uint256 compounded = principal;
        for (uint256 i = 0; i < periods; i++) {
            uint256 rewards = compounded.wmul(effectiveRate);
            compounded = compounded + rewards;
        }

        compoundRewards = compounded - principal;
    }

    /**
     * @dev Calculates farming position value
     * @param position Farming position
     * @param stakingTokenPrice Price of staking token
     * @param rewardTokenPrice Price of reward token
     * @return totalValue Total position value
     * @return stakedValue Value of staked tokens
     * @return rewardValue Value of accumulated rewards
     */
    function calculatePositionValue(
        FarmingPosition memory position,
        uint256 stakingTokenPrice,
        uint256 rewardTokenPrice
    ) internal pure returns (
        uint256 totalValue,
        uint256 stakedValue,
        uint256 rewardValue
    ) {
        stakedValue = position.amount.wmul(stakingTokenPrice);
        rewardValue = position.rewards.wmul(rewardTokenPrice);
        totalValue = stakedValue + rewardValue;
    }

    /**
     * @dev Calculates farming pool utilization
     * @param pool Farming pool
     * @param maxCapacity Maximum pool capacity
     * @return utilization Utilization percentage
     */
    function calculatePoolUtilization(
        FarmingPool memory pool,
        uint256 maxCapacity
    ) internal pure returns (uint256 utilization) {
        if (maxCapacity == 0) return 0;
        utilization = pool.totalStaked.wdiv(maxCapacity);
    }

    /**
     * @dev Checks if farming pool needs rebalancing
     * @param strategy Farming strategy
     * @param currentAllocations Current allocations
     * @param targetAllocations Target allocations
     * @return needsRebalance True if rebalancing is needed
     */
    function needsRebalancing(
        FarmingStrategy memory strategy,
        uint256[] memory currentAllocations,
        uint256[] memory targetAllocations
    ) internal pure returns (bool needsRebalance) {
        if (!strategy.autoRebalance) return false;
        if (currentAllocations.length != targetAllocations.length) return true;

        for (uint256 i = 0; i < currentAllocations.length; i++) {
            uint256 diff = currentAllocations[i] > targetAllocations[i] ?
                currentAllocations[i] - targetAllocations[i] :
                targetAllocations[i] - currentAllocations[i];

            if (diff > strategy.rebalanceThreshold) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Calculates farming strategy performance
     * @param strategy Farming strategy
     * @param initialValue Initial strategy value
     * @param currentValue Current strategy value
     * @param timeElapsed Time elapsed
     * @return performance Performance metrics
     */
    function calculateStrategyPerformance(
        FarmingStrategy memory strategy,
        uint256 initialValue,
        uint256 currentValue,
        uint256 timeElapsed
    ) internal pure returns (
        uint256 totalReturn,
        uint256 annualizedReturn,
        uint256 volatility
    ) {
        if (initialValue == 0 || timeElapsed == 0) {
            return (0, 0, 0);
        }

        totalReturn = ((currentValue - initialValue) * Aetherweb3Math.WAD) / initialValue;
        annualizedReturn = totalReturn * (365 days) / timeElapsed;

        // Simplified volatility calculation
        volatility = totalReturn / 10; // Placeholder
    }

    /**
     * @dev Estimates farming gas costs
     * @param operations Number of farming operations
     * @param gasPrice Current gas price
     * @return estimatedCost Estimated gas cost
     */
    function estimateFarmingGasCost(
        uint256 operations,
        uint256 gasPrice
    ) internal pure returns (uint256 estimatedCost) {
        uint256 gasPerOperation = 150000; // Estimated gas per farming operation
        estimatedCost = operations * gasPerOperation * gasPrice;
    }
}
