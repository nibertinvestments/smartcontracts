// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IModularLeader.sol";
import "./interfaces/IModularContract.sol";

/**
 * @title ModularLeader
 * @notice Leader contract that orchestrates 16 modular contract slots with tuple-based execution
 * @dev Implements the IModularLeader interface with full functionality for managing modular contracts
 */
contract ModularLeader is IModularLeader, Ownable, ReentrancyGuard, Pausable {
    // Constants
    uint8 public constant MAX_SLOTS = 16;

    // State variables
    ModularSlot[MAX_SLOTS] private _modularSlots;
    bool private _emergencyStopped;
    uint8[] private _executionOrder;
    mapping(TupleState => address) private _tupleContracts;
    mapping(TupleState => bool) private _tupleEnabled;

    // Modifiers
    modifier notEmergencyStopped() {
        require(!_emergencyStopped, "ModularLeader: Emergency stop active");
        _;
    }

    modifier validSlotIndex(uint8 slotIndex) {
        require(slotIndex < MAX_SLOTS, "ModularLeader: Invalid slot index");
        _;
    }

    modifier validTupleState(TupleState state) {
        require(uint8(state) < 16, "ModularLeader: Invalid tuple state");
        _;
    }

    constructor() {
        // Initialize execution order (0 to 15)
        for (uint8 i = 0; i < MAX_SLOTS; i++) {
            _executionOrder.push(i);
        }

        // Initialize all tuple states as disabled
        for (uint8 i = 0; i < 16; i++) {
            _tupleEnabled[TupleState(i)] = false;
        }
    }

    /**
     * @notice Initialize the leader contract with modular contract slots
     * @param initialSlots Array of initial modular contract configurations
     */
    function initialize(ModularSlot[] calldata initialSlots) external override onlyOwner {
        require(initialSlots.length <= MAX_SLOTS, "ModularLeader: Too many initial slots");

        for (uint256 i = 0; i < initialSlots.length; i++) {
            require(initialSlots[i].contractAddress != address(0), "ModularLeader: Invalid contract address");

            _modularSlots[i] = ModularSlot({
                contractAddress: initialSlots[i].contractAddress,
                enabled: initialSlots[i].enabled,
                name: initialSlots[i].name,
                contractType: initialSlots[i].contractType
            });

            emit ModularContractSet(
                uint8(i),
                initialSlots[i].contractAddress,
                initialSlots[i].enabled,
                initialSlots[i].name
            );
        }
    }

    /**
     * @notice Execute the full modular contract sequence
     * @param executionData Encoded data for the execution sequence
     * @return success Whether the full execution was successful
     * @return results Array of results from each modular contract execution
     */
    function executeSequence(bytes calldata executionData)
        external
        override
        nonReentrant
        whenNotPaused
        notEmergencyStopped
        returns (bool success, bytes[] memory results)
    {
        uint256 gasStart = gasleft();
        uint8 enabledCount = getEnabledSlotsCount();

        if (enabledCount == 0) {
            return (true, new bytes[](0));
        }

        results = new bytes[](enabledCount);
        uint256 resultIndex = 0;
        success = true;

        // Execute BEFORE_EXECUTE tuple
        if (_tupleEnabled[TupleState.BEFORE_EXECUTE]) {
            (bool tupleSuccess,) = _executeTuple(TupleState.BEFORE_EXECUTE, executionData);
            if (!tupleSuccess) {
                return (false, results);
            }
        }

        // Execute enabled modular contracts in order
        for (uint256 i = 0; i < _executionOrder.length; i++) {
            uint8 slotIndex = _executionOrder[i];

            if (_modularSlots[slotIndex].enabled && _modularSlots[slotIndex].contractAddress != address(0)) {
                (bool slotSuccess, bytes memory result) = executeSlot(slotIndex, executionData);

                results[resultIndex] = result;
                resultIndex++;

                if (!slotSuccess) {
                    success = false;
                    break;
                }
            }
        }

        // Execute AFTER_EXECUTE tuple
        if (_tupleEnabled[TupleState.AFTER_EXECUTE]) {
            (bool tupleSuccess,) = _executeTuple(TupleState.AFTER_EXECUTE, executionData);
            if (!tupleSuccess && success) {
                success = false;
            }
        }

        uint256 gasUsed = gasStart - gasleft();
        emit SequenceExecuted(success, gasUsed);

        return (success, results);
    }

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
    ) external override onlyOwner validSlotIndex(slotIndex) {
        require(contractAddress != address(0), "ModularLeader: Invalid contract address");

        // Get contract type from the modular contract
        bytes32 contractType = bytes32(0);
        if (contractAddress != address(0)) {
            try IModularContract(contractAddress).getContractType() returns (bytes32 type_) {
                contractType = type_;
            } catch {
                // Contract doesn't implement interface, use default
            }
        }

        _modularSlots[slotIndex] = ModularSlot({
            contractAddress: contractAddress,
            enabled: enabled,
            name: name,
            contractType: contractType
        });

        emit ModularContractSet(slotIndex, contractAddress, enabled, name);
    }

    /**
     * @notice Get a modular contract slot configuration
     * @param slotIndex The slot index (0-15)
     * @return slot The modular slot configuration
     */
    function getModularSlot(uint8 slotIndex)
        external
        view
        override
        validSlotIndex(slotIndex)
        returns (ModularSlot memory slot)
    {
        return _modularSlots[slotIndex];
    }

    /**
     * @notice Get all modular contract slots
     * @return slots Array of all 16 modular slot configurations
     */
    function getAllModularSlots() external view override returns (ModularSlot[] memory slots) {
        slots = new ModularSlot[](MAX_SLOTS);
        for (uint8 i = 0; i < MAX_SLOTS; i++) {
            slots[i] = _modularSlots[i];
        }
        return slots;
    }

    /**
     * @notice Enable or disable a modular contract slot
     * @param slotIndex The slot index (0-15)
     * @param enabled Whether to enable or disable the slot
     */
    function toggleSlot(uint8 slotIndex, bool enabled)
        external
        override
        onlyOwner
        validSlotIndex(slotIndex)
    {
        require(_modularSlots[slotIndex].contractAddress != address(0), "ModularLeader: No contract in slot");

        _modularSlots[slotIndex].enabled = enabled;
        emit SlotToggled(slotIndex, enabled);
    }

    /**
     * @notice Execute a specific modular contract slot
     * @param slotIndex The slot index to execute
     * @param data Encoded execution data
     * @return success Whether execution was successful
     * @return result Execution result data
     */
    function executeSlot(uint8 slotIndex, bytes calldata data)
        external
        override
        validSlotIndex(slotIndex)
        returns (bool success, bytes memory result)
    {
        require(_modularSlots[slotIndex].contractAddress != address(0), "ModularLeader: No contract in slot");
        require(_modularSlots[slotIndex].enabled, "ModularLeader: Slot not enabled");

        IModularContract modularContract = IModularContract(_modularSlots[slotIndex].contractAddress);

        // Validate before execution
        if (!modularContract.validate(data)) {
            return (false, "Validation failed");
        }

        // Execute the contract
        try modularContract.execute(data) returns (bool execSuccess, bytes memory execResult) {
            return (execSuccess, execResult);
        } catch Error(string memory reason) {
            return (false, bytes(reason));
        } catch {
            return (false, "Execution failed");
        }
    }

    /**
     * @notice Validate all enabled modular contracts
     * @param validationData Encoded validation data
     * @return valid Whether all enabled contracts are valid
     * @return invalidSlots Array of slot indices that failed validation
     */
    function validateAllSlots(bytes calldata validationData)
        external
        view
        override
        returns (bool valid, uint8[] memory invalidSlots)
    {
        uint8 enabledCount = getEnabledSlotsCount();
        uint8[] memory tempInvalidSlots = new uint8[](enabledCount);
        uint256 invalidCount = 0;
        valid = true;

        for (uint8 i = 0; i < MAX_SLOTS; i++) {
            if (_modularSlots[i].enabled && _modularSlots[i].contractAddress != address(0)) {
                IModularContract modularContract = IModularContract(_modularSlots[i].contractAddress);

                try modularContract.validate(validationData) returns (bool isValid) {
                    if (!isValid) {
                        valid = false;
                        tempInvalidSlots[invalidCount] = i;
                        invalidCount++;
                    }
                } catch {
                    valid = false;
                    tempInvalidSlots[invalidCount] = i;
                    invalidCount++;
                }
            }
        }

        // Copy to properly sized array
        invalidSlots = new uint8[](invalidCount);
        for (uint256 i = 0; i < invalidCount; i++) {
            invalidSlots[i] = tempInvalidSlots[i];
        }

        return (valid, invalidSlots);
    }

    /**
     * @notice Get the total number of enabled slots
     * @return count Number of enabled modular contract slots
     */
    function getEnabledSlotsCount() public view override returns (uint8 count) {
        for (uint8 i = 0; i < MAX_SLOTS; i++) {
            if (_modularSlots[i].enabled && _modularSlots[i].contractAddress != address(0)) {
                count++;
            }
        }
        return count;
    }

    /**
     * @notice Emergency stop all modular contract executions
     */
    function emergencyStop() external override onlyOwner {
        _emergencyStopped = true;
        emit EmergencyStop(msg.sender);
    }

    /**
     * @notice Resume modular contract executions after emergency stop
     */
    function emergencyResume() external override onlyOwner {
        _emergencyStopped = false;
        emit EmergencyResume(msg.sender);
    }

    /**
     * @notice Check if the leader contract is in emergency stop mode
     * @return stopped Whether emergency stop is active
     */
    function isEmergencyStopped() external view override returns (bool stopped) {
        return _emergencyStopped;
    }

    /**
     * @notice Get the execution order of enabled slots
     * @return order Array of slot indices in execution order
     */
    function getExecutionOrder() external view override returns (uint8[] memory order) {
        return _executionOrder;
    }

    /**
     * @notice Set custom execution order for slots
     * @param order Array of slot indices defining execution order
     */
    function setExecutionOrder(uint8[] calldata order) external override onlyOwner {
        require(order.length <= MAX_SLOTS, "ModularLeader: Order too long");

        // Validate all indices are valid
        for (uint256 i = 0; i < order.length; i++) {
            require(order[i] < MAX_SLOTS, "ModularLeader: Invalid slot index in order");
        }

        _executionOrder = order;
        emit ExecutionOrderSet(order);
    }

    // Tuple system implementation
    function executeTuple(TupleState state, bytes calldata data)
        external
        override
        validTupleState(state)
        returns (bool success, bytes memory result)
    {
        return _executeTuple(state, data);
    }

    function isTupleEnabled(TupleState state) external view override validTupleState(state) returns (bool) {
        return _tupleEnabled[state];
    }

    function getTupleContract(TupleState state)
        external
        view
        override
        validTupleState(state)
        returns (address)
    {
        return _tupleContracts[state];
    }

    function setTupleState(TupleState state, bool enabled)
        external
        override
        onlyOwner
        validTupleState(state)
    {
        _tupleEnabled[state] = enabled;
    }

    function setTupleContract(TupleState state, address contractAddress)
        external
        override
        onlyOwner
        validTupleState(state)
    {
        _tupleContracts[state] = contractAddress;
    }

    function getAllTuples() external view override returns (
        TupleState[] memory states,
        bool[] memory enabled,
        address[] memory contracts
    ) {
        states = new TupleState[](16);
        enabled = new bool[](16);
        contracts = new address[](16);

        for (uint8 i = 0; i < 16; i++) {
            TupleState state = TupleState(i);
            states[i] = state;
            enabled[i] = _tupleEnabled[state];
            contracts[i] = _tupleContracts[state];
        }

        return (states, enabled, contracts);
    }

    // Internal functions
    function _executeTuple(TupleState state, bytes memory data)
        internal
        returns (bool success, bytes memory result)
    {
        address tupleContract = _tupleContracts[state];
        if (tupleContract == address(0) || !_tupleEnabled[state]) {
            return (true, ""); // No contract or disabled, consider successful
        }

        try IModularContract(tupleContract).execute(data) returns (bool execSuccess, bytes memory execResult) {
            return (execSuccess, execResult);
        } catch Error(string memory reason) {
            return (false, bytes(reason));
        } catch {
            return (false, "Tuple execution failed");
        }
    }

    // Pause functionality
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
