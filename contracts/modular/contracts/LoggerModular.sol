// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IModularContract.sol";

/**
 * @title LoggerModular
 * @notice Modular contract for logging events and transaction data
 * @dev A gas-efficient logging contract that records important events in the modular system
 */
contract LoggerModular is IModularContract, Ownable {
    // Contract metadata
    string public constant override getContractName = "LoggerModular";
    string public constant override getContractVersion = "1.0.0";
    bytes32 public constant override getContractType = keccak256("LOGGER");

    // State variables
    address public leaderContract;
    bool public active;

    // Logging data structures
    struct LogEntry {
        uint256 timestamp;
        address caller;
        bytes32 eventType;
        bytes data;
        uint256 blockNumber;
    }

    LogEntry[] public logEntries;
    mapping(bytes32 => uint256) public eventCounts;
    mapping(address => uint256) public callerEventCounts;

    uint256 public constant MAX_LOG_ENTRIES = 10000; // Prevent unbounded growth
    uint256 public maxLogRetention = 30 days;

    // Events
    event LogRecorded(
        uint256 indexed logIndex,
        address indexed caller,
        bytes32 indexed eventType,
        uint256 timestamp,
        uint256 blockNumber
    );

    event LogCleaned(uint256 entriesRemoved, uint256 oldestTimestamp);

    constructor(address _leaderContract) {
        require(_leaderContract != address(0), "LoggerModular: Invalid leader contract");

        leaderContract = _leaderContract;
        active = true;
    }

    /**
     * @notice Execute logging operation
     * @param data Encoded log data (eventType, logData)
     * @return success Whether logging was successful
     * @return result Encoded result data
     */
    function execute(bytes calldata data)
        external
        override
        returns (bool success, bytes memory result)
    {
        require(msg.sender == leaderContract, "LoggerModular: Only leader can execute");
        require(active, "LoggerModular: Contract not active");

        (bytes32 eventType, bytes memory logData) = abi.decode(data, (bytes32, bytes));

        uint256 logIndex = logEntries.length;

        // Prevent log array from growing too large
        if (logIndex >= MAX_LOG_ENTRIES) {
            _cleanupOldLogs();
            logIndex = logEntries.length;
        }

        LogEntry memory newEntry = LogEntry({
            timestamp: block.timestamp,
            caller: tx.origin, // Use tx.origin to get the original caller
            eventType: eventType,
            data: logData,
            blockNumber: block.number
        });

        logEntries.push(newEntry);
        eventCounts[eventType]++;
        callerEventCounts[tx.origin]++;

        emit LogRecorded(logIndex, tx.origin, eventType, block.timestamp, block.number);

        return (true, abi.encode(logIndex, block.timestamp));
    }

    /**
     * @notice Validate log data
     * @param data Encoded validation data
     * @return valid Whether data is valid for logging
     */
    function validate(bytes calldata data) external pure override returns (bool valid) {
        if (data.length == 0) return false;

        // Try to decode the data
        try this._validateLogData(data) returns (bool isValid) {
            return isValid;
        } catch {
            return false;
        }
    }

    /**
     * @notice Estimate gas cost for logging
     * @param data Encoded data for estimation
     * @return gasEstimate Estimated gas cost
     */
    function estimateGas(bytes calldata data) external view override returns (uint256 gasEstimate) {
        // Base gas for logging
        uint256 baseGas = 100000; // Base cost for storage and event emission

        // Additional gas based on data size
        baseGas += data.length * 20; // Storage cost estimation

        // Additional gas if cleanup is needed
        if (logEntries.length >= MAX_LOG_ENTRIES) {
            baseGas += 50000; // Cleanup operation cost
        }

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
     * @notice Get log entry by index
     * @param index Log entry index
     * @return entry The log entry
     */
    function getLogEntry(uint256 index) external view returns (LogEntry memory entry) {
        require(index < logEntries.length, "LoggerModular: Log index out of bounds");
        return logEntries[index];
    }

    /**
     * @notice Get total number of log entries
     * @return Total number of log entries
     */
    function getLogCount() external view returns (uint256) {
        return logEntries.length;
    }

    /**
     * @notice Get logs within a time range
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @return entries Array of log entries in the time range
     */
    function getLogsInTimeRange(uint256 startTime, uint256 endTime)
        external
        view
        returns (LogEntry[] memory entries)
    {
        require(startTime <= endTime, "LoggerModular: Invalid time range");

        // Count matching entries
        uint256 matchCount = 0;
        for (uint256 i = 0; i < logEntries.length; i++) {
            if (logEntries[i].timestamp >= startTime && logEntries[i].timestamp <= endTime) {
                matchCount++;
            }
        }

        // Create result array
        entries = new LogEntry[](matchCount);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < logEntries.length; i++) {
            if (logEntries[i].timestamp >= startTime && logEntries[i].timestamp <= endTime) {
                entries[resultIndex] = logEntries[i];
                resultIndex++;
            }
        }

        return entries;
    }

    /**
     * @notice Get event count for a specific event type
     * @param eventType The event type to query
     * @return Count of events of this type
     */
    function getEventCount(bytes32 eventType) external view returns (uint256) {
        return eventCounts[eventType];
    }

    /**
     * @notice Get event count for a specific caller
     * @param caller The caller address to query
     * @return Count of events by this caller
     */
    function getCallerEventCount(address caller) external view returns (uint256) {
        return callerEventCounts[caller];
    }

    /**
     * @notice Set maximum log retention time
     * @param retentionTime Maximum time to keep logs (in seconds)
     */
    function setMaxLogRetention(uint256 retentionTime) external onlyOwner {
        require(retentionTime > 0, "LoggerModular: Invalid retention time");
        maxLogRetention = retentionTime;
    }

    /**
     * @notice Manually trigger log cleanup
     */
    function cleanupOldLogs() external onlyOwner {
        _cleanupOldLogs();
    }

    /**
     * @notice Internal validation function
     * @param data Data to validate
     * @return Whether data is valid
     */
    function _validateLogData(bytes calldata data) external pure returns (bool) {
        (bytes32 eventType,) = abi.decode(data, (bytes32, bytes));
        return eventType != bytes32(0);
    }

    /**
     * @notice Internal cleanup function
     */
    function _cleanupOldLogs() internal {
        uint256 cutoffTime = block.timestamp - maxLogRetention;
        uint256 removedCount = 0;
        uint256 oldestTimestamp = type(uint256).max;

        // Find entries to remove
        for (uint256 i = logEntries.length; i > 0; i--) {
            uint256 index = i - 1;
            if (logEntries[index].timestamp < cutoffTime) {
                // Update counts
                eventCounts[logEntries[index].eventType]--;
                callerEventCounts[logEntries[index].caller]--;

                removedCount++;
            } else {
                oldestTimestamp = logEntries[index].timestamp;
                break;
            }
        }

        // Remove old entries
        if (removedCount > 0) {
            for (uint256 i = 0; i < removedCount; i++) {
                logEntries.pop();
            }

            emit LogCleaned(removedCount, oldestTimestamp);
        }
    }
}
