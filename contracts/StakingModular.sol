// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract StakingModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct StakingPool {
        address stakingToken;
        address rewardToken;
        uint256 totalStaked;
        uint256 rewardRate;          // Rewards per second per token staked
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 minStakeAmount;
        uint256 maxStakeAmount;
        uint256 lockPeriod;          // Lock period in seconds
        bool isActive;
    }

    struct UserStake {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
        uint256 lockExpiry;
        bool isLocked;
    }

    mapping(uint256 => StakingPool) public stakingPools;
    mapping(uint256 => mapping(address => UserStake)) public userStakes;
    mapping(address => uint256[]) public userPoolIds;

    uint256 public poolCount;
    uint256 public constant MAX_POOLS = 50;
    uint256 public constant PRECISION = 1e18;

    event PoolCreated(uint256 indexed poolId, address stakingToken, address rewardToken);
    event Staked(uint256 indexed poolId, address indexed user, uint256 amount);
    event Unstaked(uint256 indexed poolId, address indexed user, uint256 amount);
    event RewardsClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event PoolUpdated(uint256 indexed poolId, uint256 newRewardRate);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier validPool(uint256 poolId) {
        require(poolId < poolCount && stakingPools[poolId].isActive, "Invalid pool");
        _;
    }

    constructor() {
        // Create default staking pool
        _createPool(
            0xA0b86a33E6441e88C5F2712C3E9b74F5b8F1e6E7, // USDC
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI (reward token)
            1000000 * PRECISION, // 1M rewards per second (scaled)
            100 ether,           // Min stake
            100000 ether,        // Max stake
            604800               // 7 day lock
        );
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function createPool(
        address stakingToken,
        address rewardToken,
        uint256 rewardRate,
        uint256 minStake,
        uint256 maxStake,
        uint256 lockPeriod
    ) external onlyOwner returns (uint256) {
        require(poolCount < MAX_POOLS, "Max pools reached");
        return _createPool(stakingToken, rewardToken, rewardRate, minStake, maxStake, lockPeriod);
    }

    function _createPool(
        address stakingToken,
        address rewardToken,
        uint256 rewardRate,
        uint256 minStake,
        uint256 maxStake,
        uint256 lockPeriod
    ) internal returns (uint256) {
        uint256 poolId = poolCount++;

        stakingPools[poolId] = StakingPool({
            stakingToken: stakingToken,
            rewardToken: rewardToken,
            totalStaked: 0,
            rewardRate: rewardRate,
            lastUpdateTime: block.timestamp,
            rewardPerTokenStored: 0,
            minStakeAmount: minStake,
            maxStakeAmount: maxStake,
            lockPeriod: lockPeriod,
            isActive: true
        });

        emit PoolCreated(poolId, stakingToken, rewardToken);
        return poolId;
    }

    function updatePoolRewardRate(uint256 poolId, uint256 newRewardRate) external onlyOwner validPool(poolId) {
        StakingPool storage pool = stakingPools[poolId];
        _updatePoolRewards(poolId);
        pool.rewardRate = newRewardRate;

        emit PoolUpdated(poolId, newRewardRate);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            // Allow staking contract to receive tokens
            if (to == address(this)) {
                return abi.encode(true);
            }
        }

        if (tupleType == IModularTuple.TupleType.AfterTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            if (to == address(this)) {
                // This could be a staking action - validate
                return abi.encode(validateStakingAction(from, amount));
            }
        }

        return abi.encode(true);
    }

    function stake(uint256 poolId, uint256 amount) external whenNotPaused validPool(poolId) nonReentrant {
        StakingPool storage pool = stakingPools[poolId];
        require(amount >= pool.minStakeAmount, "Amount below minimum");
        require(amount <= pool.maxStakeAmount, "Amount above maximum");

        UserStake storage userStake = userStakes[poolId][msg.sender];

        // Update rewards before changing stake
        _updateUserRewards(poolId, msg.sender);

        // Transfer tokens
        IERC20(pool.stakingToken).transferFrom(msg.sender, address(this), amount);

        // Update user stake
        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        userStake.lockExpiry = block.timestamp + pool.lockPeriod;
        userStake.isLocked = pool.lockPeriod > 0;

        // Update pool
        pool.totalStaked += amount;

        // Track user's pools
        if (userStake.amount == amount) { // First stake in this pool
            userPoolIds[msg.sender].push(poolId);
        }

        emit Staked(poolId, msg.sender, amount);
    }

    function unstake(uint256 poolId, uint256 amount) external whenNotPaused validPool(poolId) nonReentrant {
        UserStake storage userStake = userStakes[poolId][msg.sender];
        require(userStake.amount >= amount, "Insufficient stake");
        require(!userStake.isLocked || block.timestamp >= userStake.lockExpiry, "Stake is locked");

        StakingPool storage pool = stakingPools[poolId];

        // Update rewards before changing stake
        _updateUserRewards(poolId, msg.sender);

        // Update user stake
        userStake.amount -= amount;

        // Update pool
        pool.totalStaked -= amount;

        // Transfer tokens back
        IERC20(pool.stakingToken).transfer(msg.sender, amount);

        // Clean up if fully unstaked
        if (userStake.amount == 0) {
            delete userStakes[poolId][msg.sender];
            _removeUserPool(msg.sender, poolId);
        }

        emit Unstaked(poolId, msg.sender, amount);
    }

    function claimRewards(uint256 poolId) external whenNotPaused validPool(poolId) nonReentrant {
        _updateUserRewards(poolId, msg.sender);

        UserStake storage userStake = userStakes[poolId][msg.sender];
        uint256 rewards = userStake.rewardDebt;

        if (rewards > 0) {
            StakingPool storage pool = stakingPools[poolId];

            // Reset reward debt
            userStake.rewardDebt = 0;

            // Transfer rewards
            IERC20(pool.rewardToken).transfer(msg.sender, rewards);

            emit RewardsClaimed(poolId, msg.sender, rewards);
        }
    }

    function compoundRewards(uint256 poolId) external whenNotPaused validPool(poolId) nonReentrant {
        _updateUserRewards(poolId, msg.sender);

        UserStake storage userStake = userStakes[poolId][msg.sender];
        uint256 rewards = userStake.rewardDebt;

        if (rewards > 0) {
            StakingPool storage pool = stakingPools[poolId];

            // Reset reward debt
            userStake.rewardDebt = 0;

            // Add rewards to stake (if reward token == staking token)
            if (pool.rewardToken == pool.stakingToken) {
                userStake.amount += rewards;
                pool.totalStaked += rewards;

                emit Staked(poolId, msg.sender, rewards);
            } else {
                // Transfer rewards normally
                IERC20(pool.rewardToken).transfer(msg.sender, rewards);
                emit RewardsClaimed(poolId, msg.sender, rewards);
            }
        }
    }

    function _updatePoolRewards(uint256 poolId) internal {
        StakingPool storage pool = stakingPools[poolId];
        if (pool.totalStaked == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
        if (timeElapsed > 0) {
            uint256 rewardPerToken = (timeElapsed * pool.rewardRate * PRECISION) / pool.totalStaked;
            pool.rewardPerTokenStored += rewardPerToken;
            pool.lastUpdateTime = block.timestamp;
        }
    }

    function _updateUserRewards(uint256 poolId, address user) internal {
        _updatePoolRewards(poolId);

        UserStake storage userStake = userStakes[poolId][user];
        if (userStake.amount > 0) {
            uint256 pending = (userStake.amount * stakingPools[poolId].rewardPerTokenStored) / PRECISION;
            userStake.rewardDebt = pending - userStake.rewardDebt;
        } else {
            userStake.rewardDebt = 0;
        }
    }

    function validateStakingAction(address user, uint256 amount) internal view returns (bool) {
        // Basic validation for staking actions
        if (amount == 0) return false;
        if (user == address(0)) return false;

        // Check if amount is within reasonable bounds
        if (amount > 1000000 ether) return false; // Max 1M tokens

        return true;
    }

    function _removeUserPool(address user, uint256 poolId) internal {
        uint256[] storage pools = userPoolIds[user];
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == poolId) {
                pools[i] = pools[pools.length - 1];
                pools.pop();
                break;
            }
        }
    }

    function getPoolInfo(uint256 poolId) external view returns (StakingPool memory) {
        return stakingPools[poolId];
    }

    function getUserStake(uint256 poolId, address user) external view returns (UserStake memory) {
        return userStakes[poolId][user];
    }

    function getPendingRewards(uint256 poolId, address user) external view returns (uint256) {
        UserStake memory userStake = userStakes[poolId][user];
        StakingPool memory pool = stakingPools[poolId];

        if (userStake.amount == 0) return 0;

        uint256 timeElapsed = block.timestamp - pool.lastUpdateTime;
        uint256 rewardPerToken = (timeElapsed * pool.rewardRate * PRECISION) / pool.totalStaked;
        uint256 currentRewardPerToken = pool.rewardPerTokenStored + rewardPerToken;

        uint256 pending = (userStake.amount * currentRewardPerToken) / PRECISION;
        return pending - userStake.rewardDebt;
    }

    function getUserPools(address user) external view returns (uint256[] memory) {
        return userPoolIds[user];
    }

    function emergencyUnstake(uint256 poolId, address user) external onlyOwner {
        UserStake storage userStake = userStakes[poolId][user];
        StakingPool storage pool = stakingPools[poolId];

        if (userStake.amount > 0) {
            uint256 amount = userStake.amount;

            // Update pool
            pool.totalStaked -= amount;

            // Transfer tokens back
            IERC20(pool.stakingToken).transfer(user, amount);

            // Clean up
            delete userStakes[poolId][user];
            _removeUserPool(user, poolId);

            emit Unstaked(poolId, user, amount);
        }
    }

    function getContractName() external pure returns (string memory) {
        return "StakingModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("STAKING");
    }

    function validate(bytes calldata data) external view returns (bool) {
        if (data.length < 64) return false;
        (uint256 poolId, uint256 amount) = abi.decode(data, (uint256, uint256));
        return poolId < poolCount && amount > 0;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 150000; // Conservative estimate for staking operations
    }

    function isActive() external view returns (bool) {
        return !paused && leaderContract != address(0);
    }

    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    ) {
        return (
            this.getContractName(),
            this.getContractVersion(),
            this.getContractType(),
            this.isActive(),
            leaderContract
        );
    }
}
