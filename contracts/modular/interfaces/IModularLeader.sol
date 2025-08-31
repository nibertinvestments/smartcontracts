// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./IModularTuple.sol";
import "./IModularContract.sol";

/**
 * @title IModularLeader
 * @notice Interface for the modular leader contract that orchestrates modular contract execution
 * @dev The leader contract manages 16 modular contract slots with individual enable/disable controls
 */
interface IModularLeader is IModularTuple {
    // Struct for modular contract slot configuration
    struct ModularSlot {
        address contractAddress;    // The modular contract address
        bool enabled;              // Whether this slot is enabled
        string name;               // Human-readable name for the slot
        bytes32 contractType;      // Type identifier for the contract
    }

    /**
     * @notice Initialize the leader contract with modular contract slots
     * @param initialSlots Array of initial modular contract configurations
     */
    function initialize(ModularSlot[] calldata initialSlots) external;

    /**
     * @notice Execute the full modular contract sequence
     * @param executionData Encoded data for the execution sequence
     * @return success Whether the full execution was successful
     * @return results Array of results from each modular contract execution
     */
    function executeSequence(bytes calldata executionData)
        external
        returns (bool success, bytes[] memory results);

    /**
     * @notice Set a modular contract in a specific slot
     * @param slotIndex The slot index (0-15)
     * @param contractAddress The modular contract address
     * @param enabled Whether to enable the contract
     * @param name Human-readable name for the slot
     */
    function setModularContract(
        uint8 slotIndex,
        address contractAddress,
        bool enabled,
        string calldata name
    ) external;

    /**
     * @notice Get a modular contract slot configuration
     * @param slotIndex The slot index (0-15)
     * @return slot The modular slot configuration
     */
    function getModularSlot(uint8 slotIndex) external view returns (ModularSlot memory slot);

    /**
     * @notice Get all modular contract slots
     * @return slots Array of all 16 modular slot configurations
     */
    function getAllModularSlots() external view returns (ModularSlot[] memory slots);

    /**
     * @notice Enable or disable a modular contract slot
     * @param slotIndex The slot index (0-15)
     * @param enabled Whether to enable or disable the slot
     */
    function toggleSlot(uint8 slotIndex, bool enabled) external;

    /**
     * @notice Execute a specific modular contract slot
     * @param slotIndex The slot index to execute
     * @param data Encoded execution data
     * @return success Whether execution was successful
     * @return result Execution result data
     */
    function executeSlot(uint8 slotIndex, bytes calldata data)
        external
        returns (bool success, bytes memory result);

    /**
     * @notice Validate all enabled modular contracts
     * @param validationData Encoded validation data
     * @return valid Whether all enabled contracts are valid
     * @return invalidSlots Array of slot indices that failed validation
     */
    function validateAllSlots(bytes calldata validationData)
        external
        view
        returns (bool valid, uint8[] memory invalidSlots);

    /**
     * @notice Get the total number of enabled slots
     * @return count Number of enabled modular contract slots
     */
    function getEnabledSlotsCount() external view returns (uint8 count);

    /**
     * @notice Emergency stop all modular contract executions
     */
    function emergencyStop() external;

    /**
     * @notice Resume modular contract executions after emergency stop
     */
    function emergencyResume() external;

    /**
     * @notice Check if the leader contract is in emergency stop mode
     * @return stopped Whether emergency stop is active
     */
    function isEmergencyStopped() external view returns (bool stopped);

    /**
     * @notice Get the execution order of enabled slots
     * @return order Array of slot indices in execution order
     */
    function getExecutionOrder() external view returns (uint8[] memory order);

    /**
     * @notice Set custom execution order for slots
     * @param order Array of slot indices defining execution order
     */
    function setExecutionOrder(uint8[] calldata order) external;

    // Events
    event ModularContractSet(uint8 indexed slotIndex, address indexed contractAddress, bool enabled, string name);
    event SlotToggled(uint8 indexed slotIndex, bool enabled);
    event SequenceExecuted(bool indexed success, uint256 gasUsed);
    event EmergencyStop(address indexed caller);
    event EmergencyResume(address indexed caller);
    event ExecutionOrderSet(uint8[] order);
}
