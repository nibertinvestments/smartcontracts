// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAetherweb3StakingVault
 * @dev Interface for the Aetherweb3StakingVault contract
 */
interface IAetherweb3StakingVault {
    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
        uint256 lockEndTime;
        bool emergencyUnstaked;
    }

    struct LockPeriod {
        uint256 duration;
        uint256 multiplier;
        bool active;
    }

    function stake(uint256 amount, uint256 lockPeriodId) external;
    function unstake(uint256 amount) external;
    function emergencyUnstake(uint256 amount) external;
    function claimReward() external;

    function earned(address account) external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function getLockMultiplier(address account) external view returns (uint256);
    function getAPR(uint256 lockPeriodId) external view returns (uint256);
    function getStakeInfo(address account) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 lastStakeTime,
        uint256 lockEndTime,
        bool emergencyUnstaked
    );

    function setRewardRate(uint256 newRate) external;
    function setEmergencyPenalty(uint256 newPenalty) external;
    function updateLockPeriod(uint256 lockId, uint256 duration, uint256 multiplier) external;
    function setRewardToken(address newRewardToken) external;
    function setDAO(address newDAO) external;
    function emergencyWithdrawRewards(uint256 amount) external;

    function stakingToken() external view returns (address);
    function rewardToken() external view returns (address);
    function dao() external view returns (address);
    function totalStaked() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function emergencyPenalty() external view returns (uint256);
    function lockPeriods(uint256 lockId) external view returns (
        uint256 duration,
        uint256 multiplier,
        bool active
    );
    function stakes(address account) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 lastStakeTime,
        uint256 lockEndTime,
        bool emergencyUnstaked
    );
}
