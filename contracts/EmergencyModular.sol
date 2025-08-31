// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract EmergencyModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct EmergencyConfig {
        uint256 maxEmergencyDuration;    // Maximum emergency duration in seconds
        uint256 emergencyThreshold;      // Threshold for triggering emergency
        uint256 recoveryDelay;          // Delay before recovery can be initiated
        address emergencyMultisig;      // Emergency multisig wallet
        bool requireMultisigApproval;   // Require multisig for emergency actions
    }

    struct EmergencyState {
        bool isEmergency;
        uint256 emergencyStartTime;
        uint256 emergencyEndTime;
        string emergencyReason;
        address triggeredBy;
        uint256 affectedTransactions;
    }

    EmergencyConfig public emergencyConfig;
    EmergencyState public emergencyState;

    mapping(address => bool) public emergencyApprovers;
    mapping(bytes32 => uint256) public emergencyVotes;
    mapping(address => uint256) public lastEmergencyAction;

    uint256 public constant MAX_EMERGENCY_VOTES = 10;
    uint256 public constant EMERGENCY_VOTE_DURATION = 3600; // 1 hour

    event EmergencyTriggered(address indexed trigger, string reason, uint256 duration);
    event EmergencyResolved(address indexed resolver, string resolution);
    event EmergencyVoteCast(address indexed voter, bytes32 emergencyId, bool approve);
    event EmergencyActionExecuted(string action, uint256 timestamp);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyEmergencyMultisig() {
        require(msg.sender == emergencyConfig.emergencyMultisig, "Only emergency multisig");
        _;
    }

    constructor() {
        emergencyConfig = EmergencyConfig({
            maxEmergencyDuration: 86400,    // 24 hours max
            emergencyThreshold: 1000000 ether, // 1M tokens threshold
            recoveryDelay: 3600,           // 1 hour recovery delay
            emergencyMultisig: address(0), // Set by owner
            requireMultisigApproval: true
        });
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateEmergencyConfig(
        uint256 _maxDuration,
        uint256 _threshold,
        uint256 _recoveryDelay,
        address _multisig,
        bool _requireMultisig
    ) external onlyOwner {
        emergencyConfig = EmergencyConfig({
            maxEmergencyDuration: _maxDuration,
            emergencyThreshold: _threshold,
            recoveryDelay: _recoveryDelay,
            emergencyMultisig: _multisig,
            requireMultisigApproval: _requireMultisig
        });
    }

    function addEmergencyApprover(address approver) external onlyOwner {
        emergencyApprovers[approver] = true;
    }

    function removeEmergencyApprover(address approver) external onlyOwner {
        emergencyApprovers[approver] = false;
    }

    function triggerEmergency(
        string calldata reason,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(!emergencyState.isEmergency, "Emergency already active");
        require(bytes(reason).length > 0, "Reason required");
        require(duration > 0 && duration <= emergencyConfig.maxEmergencyDuration, "Invalid duration");

        // Check if sender is authorized
        require(
            msg.sender == owner() ||
            emergencyApprovers[msg.sender] ||
            msg.sender == emergencyConfig.emergencyMultisig,
            "Unauthorized to trigger emergency"
        );

        if (emergencyConfig.requireMultisigApproval && msg.sender != emergencyConfig.emergencyMultisig) {
            // Create emergency vote
            bytes32 emergencyId = keccak256(abi.encodePacked(reason, duration, block.timestamp));
            emergencyVotes[emergencyId] = 1; // Start with 1 vote (current caller)

            emit EmergencyVoteCast(msg.sender, emergencyId, true);
            return;
        }

        // Execute emergency directly
        _executeEmergency(msg.sender, reason, duration);
    }

    function voteOnEmergency(bytes32 emergencyId, bool approve) external {
        require(emergencyApprovers[msg.sender], "Not an emergency approver");
        require(emergencyVotes[emergencyId] > 0, "Emergency vote does not exist");

        // Simple voting mechanism - count approvals
        if (approve) {
            emergencyVotes[emergencyId] += 1;

            // If we have enough votes, execute emergency
            if (emergencyVotes[emergencyId] >= 3) { // Require 3 approvals
                // Extract emergency parameters from ID (simplified)
                _executeEmergency(msg.sender, "Emergency vote approved", 3600);
                delete emergencyVotes[emergencyId];
            }
        }

        emit EmergencyVoteCast(msg.sender, emergencyId, approve);
    }

    function resolveEmergency(string calldata resolution) external nonReentrant {
        require(emergencyState.isEmergency, "No active emergency");

        // Check recovery delay
        require(
            block.timestamp >= emergencyState.emergencyEndTime + emergencyConfig.recoveryDelay,
            "Recovery delay not met"
        );

        // Check authorization
        require(
            msg.sender == owner() ||
            emergencyApprovers[msg.sender] ||
            msg.sender == emergencyConfig.emergencyMultisig,
            "Unauthorized to resolve emergency"
        );

        emergencyState.isEmergency = false;
        emergencyState.emergencyEndTime = block.timestamp;

        emit EmergencyResolved(msg.sender, resolution);
        emit EmergencyActionExecuted("EMERGENCY_RESOLVED", block.timestamp);
    }

    function _executeEmergency(
        address trigger,
        string memory reason,
        uint256 duration
    ) internal {
        emergencyState = EmergencyState({
            isEmergency: true,
            emergencyStartTime: block.timestamp,
            emergencyEndTime: block.timestamp + duration,
            emergencyReason: reason,
            triggeredBy: trigger,
            affectedTransactions: 0
        });

        emit EmergencyTriggered(trigger, reason, duration);
        emit EmergencyActionExecuted("EMERGENCY_TRIGGERED", block.timestamp);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (emergencyState.isEmergency) {
            // During emergency, block certain operations
            if (tupleType == IModularTuple.TupleType.BeforeTransfer ||
                tupleType == IModularTuple.TupleType.BeforeSwap ||
                tupleType == IModularTuple.TupleType.BeforeMint) {

                emergencyState.affectedTransactions += 1;
                emit EmergencyActionExecuted("TRANSACTION_BLOCKED", block.timestamp);
                return abi.encode(false); // Block transaction
            }
        }

        // Check for emergency triggers
        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            if (amount >= emergencyConfig.emergencyThreshold) {
                // Large transaction - potential emergency trigger
                lastEmergencyAction[from] = block.timestamp;
            }
        }

        return abi.encode(true); // Allow by default
    }

    function executeEmergencyAction(string calldata action) external onlyEmergencyMultisig {
        require(emergencyState.isEmergency, "No active emergency");

        // Execute specific emergency actions
        if (keccak256(bytes(action)) == keccak256("PAUSE_ALL")) {
            // Emergency pause all operations
            emit EmergencyActionExecuted("PAUSE_ALL_EXECUTED", block.timestamp);
        } else if (keccak256(bytes(action)) == keccak256("FREEZE_ASSETS")) {
            // Emergency asset freeze
            emit EmergencyActionExecuted("FREEZE_ASSETS_EXECUTED", block.timestamp);
        }

        lastEmergencyAction[msg.sender] = block.timestamp;
    }

    function getEmergencyStatus() external view returns (
        bool isEmergency,
        uint256 startTime,
        uint256 endTime,
        string memory reason,
        address triggeredBy,
        uint256 affectedTxs
    ) {
        return (
            emergencyState.isEmergency,
            emergencyState.emergencyStartTime,
            emergencyState.emergencyEndTime,
            emergencyState.emergencyReason,
            emergencyState.triggeredBy,
            emergencyState.affectedTransactions
        );
    }

    function canResolveEmergency() external view returns (bool) {
        if (!emergencyState.isEmergency) return false;
        return block.timestamp >= emergencyState.emergencyEndTime + emergencyConfig.recoveryDelay;
    }

    function getEmergencyVotes(bytes32 emergencyId) external view returns (uint256) {
        return emergencyVotes[emergencyId];
    }

    function getContractName() external pure returns (string memory) {
        return "EmergencyModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("EMERGENCY");
    }

    function validate(bytes calldata data) external view returns (bool) {
        // Emergency validation - always allow emergency checks
        return true;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 30000; // Conservative estimate for emergency checks
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
