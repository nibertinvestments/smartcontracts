// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract TreasuryModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct TreasuryConfig {
        uint256 dailyWithdrawalLimit;    // Maximum daily withdrawal
        uint256 withdrawalCooldown;      // Cooldown between withdrawals
        uint256 minReserveRatio;         // Minimum reserve ratio (basis points)
        address reserveToken;            // Token to maintain reserves in
        bool requireApproval;            // Require approval for large withdrawals
    }

    struct WithdrawalRequest {
        address requester;
        address token;
        uint256 amount;
        uint256 timestamp;
        uint256 approvalCount;
        bool executed;
        bytes32 requestId;
    }

    TreasuryConfig public treasuryConfig;
    mapping(address => uint256) public tokenBalances;
    mapping(address => uint256) public lastWithdrawalTime;
    mapping(address => uint256) public dailyWithdrawals;
    mapping(bytes32 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => bool) public treasuryApprovers;

    bytes32[] public pendingRequests;
    uint256 public constant APPROVAL_THRESHOLD = 3;
    uint256 public constant RESET_PERIOD = 86400; // 24 hours

    event Deposit(address indexed token, uint256 amount, address indexed depositor);
    event Withdrawal(address indexed token, uint256 amount, address indexed recipient);
    event WithdrawalRequested(bytes32 indexed requestId, address indexed requester, uint256 amount);
    event WithdrawalApproved(bytes32 indexed requestId, address indexed approver);
    event TreasuryRebalanced(address indexed token, uint256 amount, string action);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyTreasuryApprover() {
        require(treasuryApprovers[msg.sender] || msg.sender == owner(), "Not treasury approver");
        _;
    }

    constructor() {
        treasuryConfig = TreasuryConfig({
            dailyWithdrawalLimit: 100000 ether, // 100K tokens per day
            withdrawalCooldown: 3600,           // 1 hour cooldown
            minReserveRatio: 2000,              // 20% minimum reserve
            reserveToken: 0xA0b86a33E6441e88C5F2712C3E9b74F5b8F1e6E7, // USDC
            requireApproval: true
        });
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateTreasuryConfig(
        uint256 _dailyLimit,
        uint256 _cooldown,
        uint256 _minReserve,
        address _reserveToken,
        bool _requireApproval
    ) external onlyOwner {
        treasuryConfig = TreasuryConfig({
            dailyWithdrawalLimit: _dailyLimit,
            withdrawalCooldown: _cooldown,
            minReserveRatio: _minReserve,
            reserveToken: _reserveToken,
            requireApproval: _requireApproval
        });
    }

    function addTreasuryApprover(address approver) external onlyOwner {
        treasuryApprovers[approver] = true;
    }

    function removeTreasuryApprover(address approver) external onlyOwner {
        treasuryApprovers[approver] = false;
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            // Treasury can receive funds
            if (to == address(this)) {
                return abi.encode(true);
            }
            // Check withdrawal limits for outgoing transfers
            if (from == address(this)) {
                return abi.encode(validateWithdrawal(to, address(0), amount));
            }
        }

        if (tupleType == IModularTuple.TupleType.AfterTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            if (to == address(this)) {
                // Record deposit
                tokenBalances[from] += amount;
                emit Deposit(from, amount, to);
            }
        }

        return abi.encode(true);
    }

    function deposit(address token, uint256 amount) external whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be > 0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        tokenBalances[token] += amount;

        emit Deposit(token, amount, msg.sender);
    }

    function requestWithdrawal(
        address token,
        uint256 amount,
        address recipient
    ) external onlyTreasuryApprover whenNotPaused returns (bytes32) {
        require(amount > 0, "Amount must be > 0");
        require(tokenBalances[token] >= amount, "Insufficient balance");
        require(recipient != address(0), "Invalid recipient");

        // Check daily withdrawal limit
        _resetDailyWithdrawalsIfNeeded(token);
        require(dailyWithdrawals[token] + amount <= treasuryConfig.dailyWithdrawalLimit, "Daily limit exceeded");

        // Check cooldown
        require(block.timestamp >= lastWithdrawalTime[token] + treasuryConfig.withdrawalCooldown, "Cooldown active");

        bytes32 requestId = keccak256(abi.encodePacked(token, amount, recipient, block.timestamp, msg.sender));

        withdrawalRequests[requestId] = WithdrawalRequest({
            requester: msg.sender,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            approvalCount: 1, // Requester auto-approves
            executed: false,
            requestId: requestId
        });

        pendingRequests.push(requestId);

        emit WithdrawalRequested(requestId, msg.sender, amount);
        return requestId;
    }

    function approveWithdrawal(bytes32 requestId) external onlyTreasuryApprover whenNotPaused {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(!request.executed, "Request already executed");
        require(request.timestamp > 0, "Request does not exist");

        request.approvalCount += 1;
        emit WithdrawalApproved(requestId, msg.sender);

        // Auto-execute if threshold reached
        if (request.approvalCount >= APPROVAL_THRESHOLD) {
            executeWithdrawal(requestId);
        }
    }

    function executeWithdrawal(bytes32 requestId) public onlyTreasuryApprover whenNotPaused nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(!request.executed, "Request already executed");
        require(request.approvalCount >= APPROVAL_THRESHOLD, "Insufficient approvals");

        // Final validation
        require(validateWithdrawal(request.requester, request.token, request.amount), "Validation failed");

        // Execute withdrawal
        IERC20(request.token).transfer(request.requester, request.amount);

        // Update balances and tracking
        tokenBalances[request.token] -= request.amount;
        dailyWithdrawals[request.token] += request.amount;
        lastWithdrawalTime[request.token] = block.timestamp;
        request.executed = true;

        emit Withdrawal(request.token, request.amount, request.requester);

        // Remove from pending requests
        _removePendingRequest(requestId);
    }

    function emergencyWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyOwner whenNotPaused nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(tokenBalances[token] >= amount, "Insufficient balance");

        IERC20(token).transfer(recipient, amount);
        tokenBalances[token] -= amount;

        emit Withdrawal(token, amount, recipient);
    }

    function validateWithdrawal(
        address recipient,
        address token,
        uint256 amount
    ) internal view returns (bool) {
        // Check reserve requirements
        if (token == treasuryConfig.reserveToken) {
            uint256 totalBalance = tokenBalances[token];
            uint256 reserveRequired = (totalBalance * treasuryConfig.minReserveRatio) / 10000;
            if (totalBalance - amount < reserveRequired) {
                return false;
            }
        }

        // Check daily limits
        if (dailyWithdrawals[token] + amount > treasuryConfig.dailyWithdrawalLimit) {
            return false;
        }

        // Check cooldown
        if (block.timestamp < lastWithdrawalTime[token] + treasuryConfig.withdrawalCooldown) {
            return false;
        }

        return true;
    }

    function rebalanceTreasury(
        address token,
        uint256 amount,
        string calldata action
    ) external onlyOwner whenNotPaused nonReentrant {
        require(tokenBalances[token] >= amount, "Insufficient balance");

        // Implement rebalancing logic based on action
        if (keccak256(bytes(action)) == keccak256("INVEST")) {
            // Invest in yield farming or other strategies
            // Implementation would depend on specific protocols
        } else if (keccak256(bytes(action)) == keccak256("DIVEST")) {
            // Divest from strategies
        }

        emit TreasuryRebalanced(token, amount, action);
    }

    function _resetDailyWithdrawalsIfNeeded(address token) internal {
        if (block.timestamp >= lastWithdrawalTime[token] + RESET_PERIOD) {
            dailyWithdrawals[token] = 0;
        }
    }

    function _removePendingRequest(bytes32 requestId) internal {
        for (uint256 i = 0; i < pendingRequests.length; i++) {
            if (pendingRequests[i] == requestId) {
                pendingRequests[i] = pendingRequests[pendingRequests.length - 1];
                pendingRequests.pop();
                break;
            }
        }
    }

    function getPendingRequests() external view returns (bytes32[] memory) {
        return pendingRequests;
    }

    function getWithdrawalRequest(bytes32 requestId) external view returns (WithdrawalRequest memory) {
        return withdrawalRequests[requestId];
    }

    function getTreasuryBalance(address token) external view returns (uint256) {
        return tokenBalances[token];
    }

    function getDailyWithdrawalInfo(address token) external view returns (uint256 used, uint256 limit) {
        _resetDailyWithdrawalsIfNeeded(token);
        return (dailyWithdrawals[token], treasuryConfig.dailyWithdrawalLimit);
    }

    function getContractName() external pure returns (string memory) {
        return "TreasuryModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("TREASURY");
    }

    function validate(bytes calldata data) external view returns (bool) {
        if (data.length < 32) return false;
        (uint256 amount) = abi.decode(data, (uint256));
        return amount > 0;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 80000; // Conservative estimate for treasury operations
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

    // Emergency function to receive ETH
    receive() external payable {}
}
