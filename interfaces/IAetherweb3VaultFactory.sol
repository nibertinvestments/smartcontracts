// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAetherweb3VaultFactory
 * @dev Interface for the Aetherweb3VaultFactory contract
 */
interface IAetherweb3VaultFactory {
    // Structs
    struct VaultParams {
        address stakingToken;
        address rewardToken;
        address dao;
        uint256 rewardRate;
        uint256 emergencyPenalty;
        string name;
        string symbol;
    }

    // Events
    event VaultCreated(
        address indexed vault,
        address indexed creator,
        address stakingToken,
        address rewardToken,
        uint256 rewardRate
    );

    event CreationFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FactoryPaused(address indexed account);
    event FactoryUnpaused(address indexed account);

    // Core functions
    function createVault(VaultParams calldata params) external payable returns (address vault);
    function createVaults(VaultParams[] calldata paramsArray) external payable returns (address[] memory vaults);
    function predictVaultAddress(VaultParams calldata params, address deployer) external view returns (address predictedAddress);

    // Query functions
    function getVaultInfo(address vault) external view returns (VaultParams memory params, address creator);
    function getAllVaults() external view returns (address[] memory);
    function getVaultsByCreator(address creator) external view returns (address[] memory vaults);
    function getVaultsByStakingToken(address stakingToken) external view returns (address[] memory vaults);
    function getVaultCount() external view returns (uint256);

    // State variables
    function allVaults(uint256 index) external view returns (address);
    function isVault(address vault) external view returns (bool);
    function vaultParams(address vault) external view returns (
        address stakingToken,
        address rewardToken,
        address dao,
        uint256 rewardRate,
        uint256 emergencyPenalty,
        string memory name,
        string memory symbol
    );
    function vaultCreators(address vault) external view returns (address);
    function creationFee() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function isPaused() external view returns (bool);

    // Admin functions
    function setCreationFee(uint256 newFee) external;
    function setFeeRecipient(address newRecipient) external;
    function pause() external;
    function unpause() external;
    function emergencyWithdraw() external;
}
