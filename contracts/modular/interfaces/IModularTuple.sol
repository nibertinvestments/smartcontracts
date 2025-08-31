// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IModularTuple
 * @notice Interface for the modular tuple system that manages contract execution states
 * @dev Defines 16 execution hooks that can be used throughout the modular contract lifecycle
 */
interface IModularTuple {
    // Tuple execution states (16 total)
    enum TupleState {
        BEFORE_INIT,        // 0: Before contract initialization
        AFTER_INIT,         // 1: After contract initialization
        BEFORE_EXECUTE,     // 2: Before main execution
        AFTER_EXECUTE,      // 3: After main execution
        BEFORE_VALIDATE,    // 4: Before validation checks
        AFTER_VALIDATE,     // 5: After validation checks
        BEFORE_TRANSFER,    // 6: Before token transfers
        AFTER_TRANSFER,     // 7: After token transfers
        BEFORE_MINT,        // 8: Before token minting
        AFTER_MINT,         // 9: After token minting
        BEFORE_BURN,        // 10: Before token burning
        AFTER_BURN,         // 11: After token burning
        BEFORE_SWAP,        // 12: Before token swaps
        AFTER_SWAP,         // 13: After token swaps
        BEFORE_CLAIM,       // 14: Before reward claims
        AFTER_CLAIM         // 15: After reward claims
    }

    /**
     * @notice Execute a tuple hook for a specific state
     * @param state The tuple state to execute
     * @param data Additional data for the tuple execution
     * @return success Whether the tuple execution was successful
     * @return result Any return data from the tuple execution
     */
    function executeTuple(TupleState state, bytes calldata data)
        external
        returns (bool success, bytes memory result);

    /**
     * @notice Check if a tuple state is enabled
     * @param state The tuple state to check
     * @return enabled Whether the tuple state is enabled
     */
    function isTupleEnabled(TupleState state) external view returns (bool enabled);

    /**
     * @notice Get the contract address associated with a tuple state
     * @param state The tuple state
     * @return contractAddress The contract address for the tuple
     */
    function getTupleContract(TupleState state) external view returns (address contractAddress);

    /**
     * @notice Enable or disable a tuple state
     * @param state The tuple state to modify
     * @param enabled Whether to enable or disable the tuple
     */
    function setTupleState(TupleState state, bool enabled) external;

    /**
     * @notice Set the contract address for a tuple state
     * @param state The tuple state
     * @param contractAddress The contract address to associate with the tuple
     */
    function setTupleContract(TupleState state, address contractAddress) external;

    /**
     * @notice Get all tuple states and their configurations
     * @return states Array of all tuple states
     * @return enabled Array of enabled status for each state
     * @return contracts Array of contract addresses for each state
     */
    function getAllTuples() external view returns (
        TupleState[] memory states,
        bool[] memory enabled,
        address[] memory contracts
    );
}
