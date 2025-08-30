// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Aetherweb3StakingVault.sol";
import "../interfaces/IAetherweb3VaultFactory.sol";

/**
 * @title Aetherweb3VaultFactory
 * @dev Factory contract for deploying Aetherweb3StakingVault instances
 */
contract Aetherweb3VaultFactory is IAetherweb3VaultFactory, Ownable, ReentrancyGuard {
    // Vault creation parameters
    struct VaultParams {
        address stakingToken;
        address rewardToken;
        address dao;
        uint256 rewardRate;
        uint256 emergencyPenalty;
        string name;
        string symbol;
    }

    // Deployed vaults registry
    address[] public allVaults;
    mapping(address => bool) public isVault;
    mapping(address => VaultParams) public vaultParams;
    mapping(address => address) public vaultCreators;

    // Factory settings
    uint256 public creationFee = 0; // Fee for creating vaults (in wei)
    address public feeRecipient;
    bool public paused;

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

    // Modifiers
    modifier whenNotPaused() {
        require(!paused, "Aetherweb3VaultFactory: factory is paused");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Aetherweb3VaultFactory: invalid address");
        _;
    }

    /**
     * @dev Constructor
     * @param _feeRecipient Address to receive creation fees
     */
    constructor(address _feeRecipient) validAddress(_feeRecipient) {
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Create a new staking vault
     * @param params Vault creation parameters
     * @return vault Address of the created vault
     */
    function createVault(VaultParams calldata params)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (address vault)
    {
        // Validate parameters
        require(params.stakingToken != address(0), "Aetherweb3VaultFactory: invalid staking token");
        require(params.rewardToken != address(0), "Aetherweb3VaultFactory: invalid reward token");
        require(params.dao != address(0), "Aetherweb3VaultFactory: invalid DAO address");
        require(params.rewardRate > 0, "Aetherweb3VaultFactory: reward rate must be > 0");
        require(params.emergencyPenalty <= 5000, "Aetherweb3VaultFactory: penalty too high");
        require(bytes(params.name).length > 0, "Aetherweb3VaultFactory: name required");
        require(bytes(params.symbol).length > 0, "Aetherweb3VaultFactory: symbol required");

        // Check creation fee
        if (creationFee > 0) {
            require(msg.value >= creationFee, "Aetherweb3VaultFactory: insufficient fee");
        }

        // Deploy vault
        Aetherweb3StakingVault newVault = new Aetherweb3StakingVault(
            params.stakingToken,
            params.rewardToken,
            params.dao
        );

        vault = address(newVault);

        // Initialize vault
        newVault.setRewardRate(params.rewardRate);
        newVault.setEmergencyPenalty(params.emergencyPenalty);

        // Register vault
        allVaults.push(vault);
        isVault[vault] = true;
        vaultParams[vault] = params;
        vaultCreators[vault] = msg.sender;

        // Transfer fee if applicable
        if (msg.value > 0) {
            payable(feeRecipient).transfer(msg.value);
        }

        emit VaultCreated(
            vault,
            msg.sender,
            params.stakingToken,
            params.rewardToken,
            params.rewardRate
        );

        return vault;
    }

    /**
     * @dev Create multiple vaults in batch
     * @param paramsArray Array of vault parameters
     * @return vaults Array of created vault addresses
     */
    function createVaults(VaultParams[] calldata paramsArray)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (address[] memory vaults)
    {
        uint256 totalFee = creationFee * paramsArray.length;
        require(msg.value >= totalFee, "Aetherweb3VaultFactory: insufficient fee for batch creation");

        vaults = new address[](paramsArray.length);

        for (uint256 i = 0; i < paramsArray.length; i++) {
            vaults[i] = createVault(paramsArray[i]);
        }

        // Refund excess fee
        if (msg.value > totalFee) {
            payable(msg.sender).transfer(msg.value - totalFee);
        }
    }

    /**
     * @dev Predict vault address before deployment
     * @param params Vault parameters
     * @param deployer Address that will deploy the vault
     * @return predictedAddress Predicted vault address
     */
    function predictVaultAddress(VaultParams calldata params, address deployer)
        external
        view
        returns (address predictedAddress)
    {
        // Calculate salt based on parameters
        bytes32 salt = keccak256(abi.encodePacked(
            params.stakingToken,
            params.rewardToken,
            params.dao,
            params.name,
            params.symbol,
            deployer,
            block.timestamp
        ));

        // Calculate contract address
        bytes memory bytecode = type(Aetherweb3StakingVault).creationCode;
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        predictedAddress = address(uint160(uint256(hash)));
    }

    /**
     * @dev Get vault information
     * @param vault Vault address
     * @return params Vault parameters
     * @return creator Vault creator
     */
    function getVaultInfo(address vault)
        external
        view
        returns (VaultParams memory params, address creator)
    {
        require(isVault[vault], "Aetherweb3VaultFactory: not a factory vault");
        return (vaultParams[vault], vaultCreators[vault]);
    }

    /**
     * @dev Get all deployed vaults
     * @return Array of vault addresses
     */
    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }

    /**
     * @dev Get vaults created by an address
     * @param creator Address of the creator
     * @return vaults Array of vault addresses created by the address
     */
    function getVaultsByCreator(address creator)
        external
        view
        returns (address[] memory vaults)
    {
        uint256 count = 0;

        // Count vaults created by creator
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (vaultCreators[allVaults[i]] == creator) {
                count++;
            }
        }

        // Populate array
        vaults = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (vaultCreators[allVaults[i]] == creator) {
                vaults[index] = allVaults[i];
                index++;
            }
        }
    }

    /**
     * @dev Get vaults by staking token
     * @param stakingToken Address of the staking token
     * @return vaults Array of vault addresses for the staking token
     */
    function getVaultsByStakingToken(address stakingToken)
        external
        view
        returns (address[] memory vaults)
    {
        uint256 count = 0;

        // Count vaults with staking token
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (vaultParams[allVaults[i]].stakingToken == stakingToken) {
                count++;
            }
        }

        // Populate array
        vaults = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allVaults.length; i++) {
            if (vaultParams[allVaults[i]].stakingToken == stakingToken) {
                vaults[index] = allVaults[i];
                index++;
            }
        }
    }

    /**
     * @dev Get total number of vaults
     * @return Total number of deployed vaults
     */
    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    // Admin functions

    /**
     * @dev Update creation fee
     * @param newFee New creation fee in wei
     */
    function setCreationFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = creationFee;
        creationFee = newFee;
        emit CreationFeeUpdated(oldFee, newFee);
    }

    /**
     * @dev Update fee recipient
     * @param newRecipient New fee recipient address
     */
    function setFeeRecipient(address newRecipient) external onlyOwner validAddress(newRecipient) {
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @dev Pause factory
     */
    function pause() external onlyOwner {
        paused = true;
        emit FactoryPaused(msg.sender);
    }

    /**
     * @dev Unpause factory
     */
    function unpause() external onlyOwner {
        paused = false;
        emit FactoryUnpaused(msg.sender);
    }

    /**
     * @dev Emergency withdraw stuck ETH
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Aetherweb3VaultFactory: no balance to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Check if factory is paused
     * @return True if paused
     */
    function isPaused() external view returns (bool) {
        return paused;
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
