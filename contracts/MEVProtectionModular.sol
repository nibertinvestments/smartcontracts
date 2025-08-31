// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract MEVProtectionModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct MEVConfig {
        uint256 maxSlippage;        // Maximum allowed slippage (basis points)
        uint256 minDelay;          // Minimum delay between transactions (seconds)
        uint256 maxFrontRun;       // Maximum front-run protection amount
        uint256 sandwichThreshold; // Threshold for sandwich attack detection
        bool enableFrontRunProtection;
        bool enableSandwichProtection;
        bool enableTimeDelayProtection;
    }

    struct TransactionRecord {
        address user;
        uint256 amount;
        uint256 timestamp;
        uint256 gasPrice;
        bytes32 txHash;
    }

    MEVConfig public mevConfig;
    mapping(address => uint256) public lastTransactionTime;
    mapping(address => uint256) public pendingTransactionCount;
    mapping(bytes32 => TransactionRecord) public transactionRecords;

    event MEVAttackDetected(address indexed user, string attackType, uint256 severity);
    event TransactionProtected(address indexed user, uint256 protectionLevel);
    event MEVConfigUpdated(uint256 maxSlippage, uint256 minDelay);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        mevConfig = MEVConfig({
            maxSlippage: 300,      // 3% max slippage
            minDelay: 12,          // 12 second minimum delay
            maxFrontRun: 100 ether, // Max front-run protection
            sandwichThreshold: 50 ether, // Sandwich detection threshold
            enableFrontRunProtection: true,
            enableSandwichProtection: true,
            enableTimeDelayProtection: true
        });
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateMEVConfig(
        uint256 _maxSlippage,
        uint256 _minDelay,
        uint256 _maxFrontRun,
        uint256 _sandwichThreshold,
        bool _enableFrontRun,
        bool _enableSandwich,
        bool _enableTimeDelay
    ) external onlyOwner {
        mevConfig = MEVConfig({
            maxSlippage: _maxSlippage,
            minDelay: _minDelay,
            maxFrontRun: _maxFrontRun,
            sandwichThreshold: _sandwichThreshold,
            enableFrontRunProtection: _enableFrontRun,
            enableSandwichProtection: _enableSandwich,
            enableTimeDelayProtection: _enableTimeDelay
        });
        emit MEVConfigUpdated(_maxSlippage, _minDelay);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            return abi.encode(executeMEVProtection(from, amount, "transfer"));
        }

        if (tupleType == IModularTuple.TupleType.BeforeSwap) {
            (address user, uint256 amountIn, uint256 amountOutMin) = abi.decode(data, (address, uint256, uint256));
            return abi.encode(executeMEVProtection(user, amountIn, "swap"));
        }

        if (tupleType == IModularTuple.TupleType.BeforeExecution) {
            (address executor, bytes memory executionData) = abi.decode(data, (address, bytes));
            uint256 amount = 0;
            if (executionData.length >= 32) {
                assembly {
                    amount := mload(add(executionData, 32))
                }
            }
            return abi.encode(executeMEVProtection(executor, amount, "execution"));
        }

        return abi.encode(true); // Allow by default for other tuples
    }

    function executeMEVProtection(
        address user,
        uint256 amount,
        string memory operationType
    ) internal returns (bool) {
        bool isProtected = true;
        uint256 protectionLevel = 0;

        // Time delay protection (gas efficient)
        if (mevConfig.enableTimeDelayProtection) {
            uint256 timeSinceLastTx = block.timestamp - lastTransactionTime[user];
            if (timeSinceLastTx < mevConfig.minDelay) {
                emit MEVAttackDetected(user, "TIME_DELAY_VIOLATION", 1);
                isProtected = false;
                protectionLevel += 1;
            }
        }

        // Front-run protection (gas efficient)
        if (mevConfig.enableFrontRunProtection && amount > mevConfig.maxFrontRun) {
            // Check for suspicious gas price patterns
            if (tx.gasprice > block.basefee * 3) {
                emit MEVAttackDetected(user, "FRONT_RUN_SUSPECTED", 2);
                protectionLevel += 2;
            }
        }

        // Sandwich attack detection (gas efficient)
        if (mevConfig.enableSandwichProtection && amount > mevConfig.sandwichThreshold) {
            // Check for pending transactions from same user
            if (pendingTransactionCount[user] > 0) {
                emit MEVAttackDetected(user, "SANDWICH_SUSPECTED", 3);
                protectionLevel += 3;
            }
            pendingTransactionCount[user] += 1;
        }

        // Record transaction for analysis
        bytes32 txHash = keccak256(abi.encodePacked(user, amount, block.timestamp, tx.gasprice));
        transactionRecords[txHash] = TransactionRecord({
            user: user,
            amount: amount,
            timestamp: block.timestamp,
            gasPrice: tx.gasprice,
            txHash: txHash
        });

        lastTransactionTime[user] = block.timestamp;

        if (protectionLevel > 0) {
            emit TransactionProtected(user, protectionLevel);
        }

        return isProtected;
    }

    function clearPendingTransaction(address user) external onlyLeader {
        if (pendingTransactionCount[user] > 0) {
            pendingTransactionCount[user] -= 1;
        }
    }

    function getTransactionRecord(bytes32 txHash) external view returns (TransactionRecord memory) {
        return transactionRecords[txHash];
    }

    function getMEVRiskLevel(address user, uint256 amount) external view returns (uint256) {
        uint256 riskLevel = 0;

        // Time-based risk
        uint256 timeSinceLastTx = block.timestamp - lastTransactionTime[user];
        if (timeSinceLastTx < mevConfig.minDelay) {
            riskLevel += 25;
        }

        // Amount-based risk
        if (amount > mevConfig.maxFrontRun) {
            riskLevel += 25;
        }

        // Gas price risk
        if (tx.gasprice > block.basefee * 2) {
            riskLevel += 25;
        }

        // Pending transaction risk
        if (pendingTransactionCount[user] > 0) {
            riskLevel += 25;
        }

        return riskLevel > 100 ? 100 : riskLevel;
    }

    function getContractName() external pure returns (string memory) {
        return "MEVProtectionModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("MEV_PROTECTION");
    }

    function validate(bytes calldata data) external view returns (bool) {
        // Validate MEV protection parameters
        if (data.length < 32) return false;
        (uint256 amount) = abi.decode(data, (uint256));
        return amount >= 0 && amount <= 1000000 ether;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        // Estimate gas for MEV protection
        return 35000; // Conservative estimate
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
