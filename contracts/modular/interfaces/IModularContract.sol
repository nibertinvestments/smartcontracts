// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/**
 * @title IModularContract
 * @notice Base interface for all modular contracts in the Aetherweb3 ecosystem
 * @dev All modular contracts must implement this interface for compatibility with the leader contract
 */
interface IModularContract {
    /**
     * @notice Get the name of this modular contract
     * @return The contract name
     */
    function getContractName() external view returns (string memory);

    /**
     * @notice Get the version of this modular contract
     * @return The contract version
     */
    function getContractVersion() external view returns (string memory);

    /**
     * @notice Get the type/category of this modular contract
     * @return The contract type identifier
     */
    function getContractType() external view returns (bytes32);

    /**
     * @notice Execute the main functionality of this modular contract
     * @param data Encoded data for contract execution
     * @return success Whether execution was successful
     * @return result Encoded result data
     */
    function execute(bytes calldata data) external returns (bool success, bytes memory result);

    /**
     * @notice Validate if the contract can execute with given parameters
     * @param data Encoded validation data
     * @return valid Whether the parameters are valid for execution
     */
    function validate(bytes calldata data) external view returns (bool valid);

    /**
     * @notice Get the gas cost estimate for execution
     * @param data Encoded data for gas estimation
     * @return gasEstimate Estimated gas cost
     */
    function estimateGas(bytes calldata data) external view returns (uint256 gasEstimate);

    /**
     * @notice Check if this contract is currently active/enabled
     * @return active Whether the contract is active
     */
    function isActive() external view returns (bool active);

    /**
     * @notice Get the leader contract address that manages this modular contract
     * @return leader The leader contract address
     */
    function getLeaderContract() external view returns (address leader);

    /**
     * @notice Emergency pause/unpause functionality
     * @param paused Whether to pause or unpause the contract
     */
    function setPaused(bool paused) external;

    /**
     * @notice Get contract metadata
     * @return name Contract name
     * @return version Contract version
     * @return contractType Contract type
     * @return active Whether contract is active
     * @return leader Leader contract address
     */
    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    );
}
