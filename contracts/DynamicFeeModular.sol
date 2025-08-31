// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract DynamicFeeModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct FeeConfig {
        uint256 baseFee;      // Base fee in basis points (1/10000)
        uint256 volumeMultiplier; // Fee multiplier based on volume
        uint256 timeMultiplier;   // Fee multiplier based on time
        uint256 gasMultiplier;    // Fee multiplier based on gas price
        uint256 maxFee;       // Maximum fee cap
        uint256 minFee;       // Minimum fee floor
    }

    FeeConfig public feeConfig;
    mapping(address => uint256) public userVolume;
    mapping(address => uint256) public lastTransactionTime;

    event FeeCalculated(address indexed user, uint256 amount, uint256 fee, uint256 feeType);
    event FeeConfigUpdated(uint256 baseFee, uint256 maxFee, uint256 minFee);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        feeConfig = FeeConfig({
            baseFee: 30,        // 0.3%
            volumeMultiplier: 10, // 0.1% per volume tier
            timeMultiplier: 5,   // 0.05% per time tier
            gasMultiplier: 2,    // 0.02% per gas tier
            maxFee: 500,        // 5% max
            minFee: 5          // 0.05% min
        });
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateFeeConfig(
        uint256 _baseFee,
        uint256 _volumeMultiplier,
        uint256 _timeMultiplier,
        uint256 _gasMultiplier,
        uint256 _maxFee,
        uint256 _minFee
    ) external onlyOwner {
        feeConfig = FeeConfig({
            baseFee: _baseFee,
            volumeMultiplier: _volumeMultiplier,
            timeMultiplier: _timeMultiplier,
            gasMultiplier: _gasMultiplier,
            maxFee: _maxFee,
            minFee: _minFee
        });
        emit FeeConfigUpdated(_baseFee, _maxFee, _minFee);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            uint256 fee = calculateDynamicFee(from, amount, tx.gasprice);
            userVolume[from] += amount;
            lastTransactionTime[from] = block.timestamp;
            emit FeeCalculated(from, amount, fee, 1);
            return abi.encode(fee);
        }

        if (tupleType == IModularTuple.TupleType.BeforeSwap) {
            (address user, uint256 amountIn, uint256 amountOutMin) = abi.decode(data, (address, uint256, uint256));
            uint256 fee = calculateDynamicFee(user, amountIn, tx.gasprice);
            userVolume[user] += amountIn;
            lastTransactionTime[user] = block.timestamp;
            emit FeeCalculated(user, amountIn, fee, 2);
            return abi.encode(fee);
        }

        return abi.encode(uint256(0));
    }

    function calculateDynamicFee(
        address user,
        uint256 amount,
        uint256 gasPrice
    ) public view returns (uint256) {
        uint256 fee = feeConfig.baseFee;

        // Volume-based multiplier (gas efficient)
        uint256 volume = userVolume[user];
        if (volume > 100000 ether) {
            fee += feeConfig.volumeMultiplier * 5; // High volume tier
        } else if (volume > 10000 ether) {
            fee += feeConfig.volumeMultiplier * 3; // Medium volume tier
        } else if (volume > 1000 ether) {
            fee += feeConfig.volumeMultiplier; // Low volume tier
        }

        // Time-based multiplier (gas efficient)
        uint256 timeSinceLastTx = block.timestamp - lastTransactionTime[user];
        if (timeSinceLastTx < 300) { // Within 5 minutes
            fee += feeConfig.timeMultiplier * 3; // High frequency
        } else if (timeSinceLastTx < 3600) { // Within 1 hour
            fee += feeConfig.timeMultiplier * 2; // Medium frequency
        } else if (timeSinceLastTx < 86400) { // Within 24 hours
            fee += feeConfig.timeMultiplier; // Low frequency
        }

        // Gas price multiplier (gas efficient)
        if (gasPrice > 100 gwei) {
            fee += feeConfig.gasMultiplier * 3; // High gas price
        } else if (gasPrice > 50 gwei) {
            fee += feeConfig.gasMultiplier * 2; // Medium gas price
        } else if (gasPrice > 20 gwei) {
            fee += feeConfig.gasMultiplier; // Low gas price
        }

        // Apply caps (gas efficient)
        if (fee > feeConfig.maxFee) {
            fee = feeConfig.maxFee;
        } else if (fee < feeConfig.minFee) {
            fee = feeConfig.minFee;
        }

        return fee;
    }

    function getContractName() external pure returns (string memory) {
        return "DynamicFeeModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("DYNAMIC_FEE");
    }

    function validate(bytes calldata data) external view returns (bool) {
        // Validate fee calculation parameters
        if (data.length < 32) return false;
        (uint256 amount) = abi.decode(data, (uint256));
        return amount > 0 && amount <= 1000000 ether; // Reasonable bounds
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        // Estimate gas for fee calculation
        return 25000; // Conservative estimate
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
