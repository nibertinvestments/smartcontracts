// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAetherweb3StakingVault.sol";
import "./libraries/SafeCast.sol";

/**
 * @title Aetherweb3StakingVault
 * @dev Staking vault for Aetherweb3 tokens with reward distribution
 */
contract Aetherweb3StakingVault is IAetherweb3StakingVault, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    // Staking token
    IERC20 public immutable stakingToken;

    // Reward token (can be same as staking token or different)
    IERC20 public rewardToken;

    // DAO contract for governance
    address public dao;

    // Staking information
    struct StakeInfo {
        uint256 amount;          // Staked amount
        uint256 rewardDebt;      // Reward debt for calculation
        uint256 lastStakeTime;   // Last stake timestamp
        uint256 lockEndTime;     // Lock end timestamp
        bool emergencyUnstaked;  // Emergency unstake flag
    }

    // Lock period options
    struct LockPeriod {
        uint256 duration;        // Lock duration in seconds
        uint256 multiplier;      // Reward multiplier (basis points, 10000 = 100%)
        bool active;            // Whether this lock period is active
    }

    // State variables
    mapping(address => StakeInfo) public stakes;
    mapping(uint256 => LockPeriod) public lockPeriods;

    uint256 public totalStaked;
    uint256 public rewardPerTokenStored;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;              // Rewards per second
    uint256 public constant REWARD_PRECISION = 1e18;

    // Lock period IDs
    uint256 public constant NO_LOCK = 0;
    uint256 public constant SHORT_LOCK = 30 days;
    uint256 public constant MEDIUM_LOCK = 90 days;
    uint256 public constant LONG_LOCK = 180 days;

    // Emergency unstake penalty (basis points)
    uint256 public emergencyPenalty = 1000; // 10%

    // Events
    event Staked(address indexed user, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, uint256 amount, bool emergency);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event LockPeriodUpdated(uint256 lockId, uint256 duration, uint256 multiplier);
    event EmergencyPenaltyUpdated(uint256 oldPenalty, uint256 newPenalty);
    event RewardTokenUpdated(address indexed oldToken, address indexed newToken);
    event DAOUpdated(address indexed oldDAO, address indexed newDAO);

    // Modifiers
    modifier onlyDAO() {
        require(msg.sender == dao, "Aetherweb3StakingVault: caller must be DAO");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            stakes[account].rewardDebt = earned(account);
        }
        _;
    }

    /**
     * @dev Constructor
     * @param _stakingToken Address of the staking token
     * @param _rewardToken Address of the reward token
     * @param _dao Address of the DAO contract
     */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _dao
    ) {
        require(_stakingToken != address(0), "Aetherweb3StakingVault: invalid staking token");
        require(_rewardToken != address(0), "Aetherweb3StakingVault: invalid reward token");
        require(_dao != address(0), "Aetherweb3StakingVault: invalid DAO");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        dao = _dao;

        // Initialize lock periods
        lockPeriods[NO_LOCK] = LockPeriod(0, 10000, true);           // No lock, 100% multiplier
        lockPeriods[SHORT_LOCK] = LockPeriod(30 days, 11000, true);   // 30 days, 110% multiplier
        lockPeriods[MEDIUM_LOCK] = LockPeriod(90 days, 12500, true);  // 90 days, 125% multiplier
        lockPeriods[LONG_LOCK] = LockPeriod(180 days, 15000, true);   // 180 days, 150% multiplier
    }

    /**
     * @dev Stake tokens with optional lock period
     * @param amount Amount to stake
     * @param lockPeriodId Lock period ID
     */
    function stake(uint256 amount, uint256 lockPeriodId)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Aetherweb3StakingVault: cannot stake 0");
        require(lockPeriods[lockPeriodId].active, "Aetherweb3StakingVault: invalid lock period");

        StakeInfo storage userStake = stakes[msg.sender];

        // Transfer tokens from user
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update staking info
        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        userStake.lockEndTime = block.timestamp + lockPeriods[lockPeriodId].duration;
        userStake.emergencyUnstaked = false;

        totalStaked += amount;

        emit Staked(msg.sender, amount, lockPeriodId);
    }

    /**
     * @dev Unstake tokens
     * @param amount Amount to unstake
     */
    function unstake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Aetherweb3StakingVault: cannot unstake 0");

        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Aetherweb3StakingVault: insufficient staked amount");
        require(
            block.timestamp >= userStake.lockEndTime,
            "Aetherweb3StakingVault: tokens are locked"
        );
        require(!userStake.emergencyUnstaked, "Aetherweb3StakingVault: emergency unstaked");

        // Update staking info
        userStake.amount -= amount;
        totalStaked -= amount;

        // Transfer tokens back to user
        stakingToken.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, false);
    }

    /**
     * @dev Emergency unstake with penalty
     * @param amount Amount to emergency unstake
     */
    function emergencyUnstake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Aetherweb3StakingVault: cannot unstake 0");

        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Aetherweb3StakingVault: insufficient staked amount");
        require(!userStake.emergencyUnstaked, "Aetherweb3StakingVault: already emergency unstaked");

        // Calculate penalty
        uint256 penalty = (amount * emergencyPenalty) / 10000;
        uint256 returnAmount = amount - penalty;

        // Update staking info
        userStake.amount -= amount;
        userStake.emergencyUnstaked = true;
        totalStaked -= amount;

        // Transfer tokens back to user (minus penalty)
        if (returnAmount > 0) {
            stakingToken.safeTransfer(msg.sender, returnAmount);
        }

        emit Unstaked(msg.sender, returnAmount, true);
    }

    /**
     * @dev Claim accumulated rewards
     */
    function claimReward()
        external
        nonReentrant
        updateReward(msg.sender)
    {
        uint256 reward = stakes[msg.sender].rewardDebt;
        require(reward > 0, "Aetherweb3StakingVault: no rewards to claim");

        // Reset reward debt
        stakes[msg.sender].rewardDebt = 0;

        // Transfer rewards
        rewardToken.safeTransfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Get earned rewards for an account
     * @param account Account address
     * @return Earned rewards
     */
    function earned(address account) public view returns (uint256) {
        StakeInfo storage userStake = stakes[account];
        if (userStake.amount == 0) return 0;

        uint256 rewardPerTokenCurrent = rewardPerToken();
        uint256 rewardPerTokenDiff = rewardPerTokenCurrent - rewardPerTokenStored;

        // Calculate reward with lock multiplier
        uint256 baseReward = (userStake.amount * rewardPerTokenDiff) / REWARD_PRECISION;
        uint256 lockMultiplier = getLockMultiplier(account);

        return userStake.rewardDebt + (baseReward * lockMultiplier) / 10000;
    }

    /**
     * @dev Get current reward per token
     * @return Reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 reward = timeElapsed * rewardRate;

        return rewardPerTokenStored + (reward * REWARD_PRECISION) / totalStaked;
    }

    /**
     * @dev Get lock multiplier for an account
     * @param account Account address
     * @return Lock multiplier in basis points
     */
    function getLockMultiplier(address account) public view returns (uint256) {
        StakeInfo storage userStake = stakes[account];

        if (block.timestamp >= userStake.lockEndTime) {
            return 10000; // 100% multiplier after lock period
        }

        // Find the appropriate lock period
        uint256 remainingLock = userStake.lockEndTime - block.timestamp;

        if (remainingLock >= LONG_LOCK) return lockPeriods[LONG_LOCK].multiplier;
        if (remainingLock >= MEDIUM_LOCK) return lockPeriods[MEDIUM_LOCK].multiplier;
        if (remainingLock >= SHORT_LOCK) return lockPeriods[SHORT_LOCK].multiplier;

        return lockPeriods[NO_LOCK].multiplier;
    }

    /**
     * @dev Get APR for a lock period
     * @param lockPeriodId Lock period ID
     * @return APR in basis points
     */
    function getAPR(uint256 lockPeriodId) external view returns (uint256) {
        if (!lockPeriods[lockPeriodId].active || totalStaked == 0) return 0;

        uint256 yearlyRewards = rewardRate * 365 days;
        uint256 baseAPR = (yearlyRewards * 10000) / totalStaked;
        uint256 multiplier = lockPeriods[lockPeriodId].multiplier;

        return (baseAPR * multiplier) / 10000;
    }

    /**
     * @dev Get staking info for an account
     * @param account Account address
     * @return amount, rewardDebt, lastStakeTime, lockEndTime, emergencyUnstaked
     */
    function getStakeInfo(address account) external view returns (
        uint256 amount,
        uint256 rewardDebt,
        uint256 lastStakeTime,
        uint256 lockEndTime,
        bool emergencyUnstaked
    ) {
        StakeInfo storage userStake = stakes[account];
        return (
            userStake.amount,
            userStake.rewardDebt,
            userStake.lastStakeTime,
            userStake.lockEndTime,
            userStake.emergencyUnstaked
        );
    }

    // Admin functions

    /**
     * @dev Set reward rate (only owner or DAO)
     * @param newRate New reward rate per second
     */
    function setRewardRate(uint256 newRate) external {
        require(
            msg.sender == owner() || msg.sender == dao,
            "Aetherweb3StakingVault: unauthorized"
        );

        uint256 oldRate = rewardRate;
        rewardRate = newRate;

        emit RewardRateUpdated(oldRate, newRate);
    }

    /**
     * @dev Set emergency penalty (only owner)
     * @param newPenalty New emergency penalty in basis points
     */
    function setEmergencyPenalty(uint256 newPenalty) external onlyOwner {
        require(newPenalty <= 5000, "Aetherweb3StakingVault: penalty too high"); // Max 50%

        uint256 oldPenalty = emergencyPenalty;
        emergencyPenalty = newPenalty;

        emit EmergencyPenaltyUpdated(oldPenalty, newPenalty);
    }

    /**
     * @dev Update lock period (only owner)
     * @param lockId Lock period ID
     * @param duration Lock duration
     * @param multiplier Reward multiplier
     */
    function updateLockPeriod(
        uint256 lockId,
        uint256 duration,
        uint256 multiplier
    ) external onlyOwner {
        require(multiplier >= 10000, "Aetherweb3StakingVault: multiplier too low");

        lockPeriods[lockId] = LockPeriod(duration, multiplier, true);

        emit LockPeriodUpdated(lockId, duration, multiplier);
    }

    /**
     * @dev Set reward token (only owner)
     * @param newRewardToken New reward token address
     */
    function setRewardToken(address newRewardToken) external onlyOwner {
        require(newRewardToken != address(0), "Aetherweb3StakingVault: invalid reward token");

        address oldToken = address(rewardToken);
        rewardToken = IERC20(newRewardToken);

        emit RewardTokenUpdated(oldToken, newRewardToken);
    }

    /**
     * @dev Set DAO address (only owner)
     * @param newDAO New DAO address
     */
    function setDAO(address newDAO) external onlyOwner {
        require(newDAO != address(0), "Aetherweb3StakingVault: invalid DAO");

        address oldDAO = dao;
        dao = newDAO;

        emit DAOUpdated(oldDAO, newDAO);
    }

    /**
     * @dev Emergency withdraw rewards (only owner)
     * @param amount Amount to withdraw
     */
    function emergencyWithdrawRewards(uint256 amount) external onlyOwner {
        require(amount <= rewardToken.balanceOf(address(this)), "Aetherweb3StakingVault: insufficient balance");
        rewardToken.safeTransfer(owner(), amount);
    }
}
