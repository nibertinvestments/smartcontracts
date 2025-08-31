// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IModularContract.sol";

/**
 * @title RewardDistributorModular
 * @notice Modular contract for distributing rewards to users
 * @dev A gas-efficient reward distribution contract that handles token rewards
 */
contract RewardDistributorModular is IModularContract, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Contract metadata
    string public constant override getContractName = "RewardDistributorModular";
    string public constant override getContractVersion = "1.0.0";
    bytes32 public constant override getContractType = keccak256("REWARD_DISTRIBUTOR");

    // State variables
    address public leaderContract;
    bool public active;

    // Reward configuration
    address public rewardToken;
    uint256 public totalRewardsDistributed;
    uint256 public rewardRate; // Rewards per distribution
    uint256 public minRewardThreshold; // Minimum reward amount

    // User reward tracking
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public lastClaimTime;
    mapping(address => bool) public isEligible;

    // Events
    event RewardDistributed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardEligibilityUpdated(address indexed user, bool eligible);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MinThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    constructor(address _leaderContract, address _rewardToken) {
        require(_leaderContract != address(0), "RewardDistributorModular: Invalid leader contract");
        require(_rewardToken != address(0), "RewardDistributorModular: Invalid reward token");

        leaderContract = _leaderContract;
        rewardToken = _rewardToken;
        active = true;
        rewardRate = 100 * 10**18; // Default 100 tokens
        minRewardThreshold = 10 * 10**18; // Minimum 10 tokens
    }

    /**
     * @notice Execute reward distribution
     * @param data Encoded distribution data (user address, custom amount)
     * @return success Whether distribution was successful
     * @return result Encoded result data
     */
    function execute(bytes calldata data)
        external
        override
        nonReentrant
        returns (bool success, bytes memory result)
    {
        require(msg.sender == leaderContract, "RewardDistributorModular: Only leader can execute");
        require(active, "RewardDistributorModular: Contract not active");

        (address user, uint256 customAmount) = abi.decode(data, (address, uint256));
        require(user != address(0), "RewardDistributorModular: Invalid user address");

        uint256 rewardAmount = customAmount > 0 ? customAmount : rewardRate;
        require(rewardAmount >= minRewardThreshold, "RewardDistributorModular: Reward below minimum threshold");

        // Check contract balance
        uint256 contractBalance = IERC20(rewardToken).balanceOf(address(this));
        require(contractBalance >= rewardAmount, "RewardDistributorModular: Insufficient contract balance");

        // Update user rewards
        userRewards[user] += rewardAmount;
        totalRewardsDistributed += rewardAmount;

        emit RewardDistributed(user, rewardAmount, block.timestamp);

        return (true, abi.encode(user, rewardAmount, block.timestamp));
    }

    /**
     * @notice Validate reward distribution parameters
     * @param data Encoded validation data
     * @return valid Whether parameters are valid
     */
    function validate(bytes calldata data) external view override returns (bool valid) {
        if (!active || data.length == 0) return false;

        (address user, uint256 customAmount) = abi.decode(data, (address, uint256));

        if (user == address(0)) return false;

        uint256 rewardAmount = customAmount > 0 ? customAmount : rewardRate;
        if (rewardAmount < minRewardThreshold) return false;

        // Check contract balance
        uint256 contractBalance = IERC20(rewardToken).balanceOf(address(this));
        if (contractBalance < rewardAmount) return false;

        return true;
    }

    /**
     * @notice Estimate gas cost for reward distribution
     * @param data Encoded data for estimation
     * @return gasEstimate Estimated gas cost
     */
    function estimateGas(bytes calldata data) external pure override returns (uint256 gasEstimate) {
        // Base gas for reward distribution
        uint256 baseGas = 80000; // ERC20 transfer + storage updates

        // Additional gas based on data size
        baseGas += data.length * 5;

        return baseGas;
    }

    /**
     * @notice Check if contract is active
     * @return Whether contract is active
     */
    function isActive() external view override returns (bool) {
        return active;
    }

    /**
     * @notice Get leader contract address
     * @return Leader contract address
     */
    function getLeaderContract() external view override returns (address) {
        return leaderContract;
    }

    /**
     * @notice Emergency pause/unpause
     * @param paused Whether to pause contract
     */
    function setPaused(bool paused) external override onlyOwner {
        active = !paused;
    }

    /**
     * @notice Get contract metadata
     * @return name Contract name
     * @return version Contract version
     * @return contractType Contract type
     * @return active Whether contract is active
     * @return leader Leader contract address
     */
    function getMetadata() external view override returns (
        string memory name,
        string memory version,
        bytes32 contractType_,
        bool active_,
        address leader
    ) {
        return (getContractName, getContractVersion, getContractType, active, leaderContract);
    }

    /**
     * @notice Claim accumulated rewards
     * @param amount Amount to claim (0 for all available)
     */
    function claimRewards(uint256 amount) external nonReentrant {
        require(active, "RewardDistributorModular: Contract not active");
        require(isEligible[msg.sender], "RewardDistributorModular: User not eligible");

        uint256 availableRewards = userRewards[msg.sender];
        require(availableRewards > 0, "RewardDistributorModular: No rewards available");

        uint256 claimAmount = amount > 0 ? amount : availableRewards;
        require(claimAmount <= availableRewards, "RewardDistributorModular: Insufficient rewards");

        // Update user rewards
        userRewards[msg.sender] -= claimAmount;
        lastClaimTime[msg.sender] = block.timestamp;

        // Transfer rewards
        IERC20(rewardToken).safeTransfer(msg.sender, claimAmount);

        emit RewardClaimed(msg.sender, claimAmount, block.timestamp);
    }

    /**
     * @notice Set user eligibility for rewards
     * @param user User address
     * @param eligible Whether user is eligible
     */
    function setUserEligibility(address user, bool eligible) external onlyOwner {
        require(user != address(0), "RewardDistributorModular: Invalid user address");

        isEligible[user] = eligible;
        emit RewardEligibilityUpdated(user, eligible);
    }

    /**
     * @notice Set reward rate
     * @param newRate New reward rate
     */
    function setRewardRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "RewardDistributorModular: Invalid reward rate");

        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        emit RewardRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Set minimum reward threshold
     * @param newThreshold New minimum threshold
     */
    function setMinRewardThreshold(uint256 newThreshold) external onlyOwner {
        uint256 oldThreshold = minRewardThreshold;
        minRewardThreshold = newThreshold;
        emit MinThresholdUpdated(oldThreshold, newThreshold);
    }

    /**
     * @notice Get user reward information
     * @param user User address
     * @return availableRewards Available rewards
     * @return lastClaim Last claim timestamp
     * @return eligible Whether user is eligible
     */
    function getUserRewardInfo(address user) external view returns (
        uint256 availableRewards,
        uint256 lastClaim,
        bool eligible
    ) {
        return (userRewards[user], lastClaimTime[user], isEligible[user]);
    }

    /**
     * @notice Deposit reward tokens to contract
     * @param amount Amount to deposit
     */
    function depositRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "RewardDistributorModular: Invalid amount");

        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Withdraw reward tokens from contract (emergency)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "RewardDistributorModular: Invalid amount");

        uint256 contractBalance = IERC20(rewardToken).balanceOf(address(this));
        require(amount <= contractBalance, "RewardDistributorModular: Insufficient balance");

        IERC20(rewardToken).safeTransfer(owner(), amount);
    }

    /**
     * @notice Get contract reward balance
     * @return Balance of reward tokens in contract
     */
    function getContractBalance() external view returns (uint256) {
        return IERC20(rewardToken).balanceOf(address(this));
    }
}
