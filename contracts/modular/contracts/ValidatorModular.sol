// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IModularContract.sol";

/**
 * @title ValidatorModular
 * @notice Modular contract for validating transaction parameters and conditions
 * @dev A gas-efficient validation contract that checks various conditions before execution
 */
contract ValidatorModular is IModularContract, Ownable {
    // Contract metadata
    string public constant override getContractName = "ValidatorModular";
    string public constant override getContractVersion = "1.0.0";
    bytes32 public constant override getContractType = keccak256("VALIDATOR");

    // State variables
    address public leaderContract;
    bool public active;

    // Validation rules
    uint256 public minAmount;
    uint256 public maxAmount;
    address public requiredSender;
    bool public checkTimestamp;
    uint256 public minTimestamp;
    uint256 public maxTimestamp;

    // Events
    event ValidationRuleUpdated(string rule, uint256 value);
    event ValidationRuleUpdatedAddress(string rule, address value);

    constructor(address _leaderContract) {
        require(_leaderContract != address(0), "ValidatorModular: Invalid leader contract");

        leaderContract = _leaderContract;
        active = true;

        // Default validation rules
        minAmount = 0;
        maxAmount = type(uint256).max;
        checkTimestamp = false;
    }

    /**
     * @notice Execute validation checks
     * @param data Encoded validation data
     * @return success Whether validation passed
     * @return result Encoded validation result
     */
    function execute(bytes calldata data)
        external
        view
        override
        returns (bool success, bytes memory result)
    {
        require(msg.sender == leaderContract, "ValidatorModular: Only leader can execute");
        require(active, "ValidatorModular: Contract not active");

        bool isValid = _performValidation(data);
        bytes memory validationResult = abi.encode(isValid, block.timestamp, msg.sender);

        return (isValid, validationResult);
    }

    /**
     * @notice Validate parameters (same as execute for consistency)
     * @param data Encoded validation data
     * @return valid Whether parameters are valid
     */
    function validate(bytes calldata data) external view override returns (bool valid) {
        return _performValidation(data);
    }

    /**
     * @notice Estimate gas cost for validation
     * @param data Encoded data for estimation
     * @return gasEstimate Estimated gas cost
     */
    function estimateGas(bytes calldata data) external pure override returns (uint256 gasEstimate) {
        // Base gas for validation checks
        uint256 baseGas = 5000;

        // Additional gas based on data size
        baseGas += data.length * 3; // Rough estimate for data processing

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
     * @notice Set minimum amount for validation
     * @param _minAmount Minimum amount required
     */
    function setMinAmount(uint256 _minAmount) external onlyOwner {
        minAmount = _minAmount;
        emit ValidationRuleUpdated("minAmount", _minAmount);
    }

    /**
     * @notice Set maximum amount for validation
     * @param _maxAmount Maximum amount allowed
     */
    function setMaxAmount(uint256 _maxAmount) external onlyOwner {
        maxAmount = _maxAmount;
        emit ValidationRuleUpdated("maxAmount", _maxAmount);
    }

    /**
     * @notice Set required sender address
     * @param _requiredSender Required sender address (address(0) to disable)
     */
    function setRequiredSender(address _requiredSender) external onlyOwner {
        requiredSender = _requiredSender;
        emit ValidationRuleUpdatedAddress("requiredSender", _requiredSender);
    }

    /**
     * @notice Enable/disable timestamp validation
     * @param _checkTimestamp Whether to check timestamps
     * @param _minTimestamp Minimum timestamp (if checking)
     * @param _maxTimestamp Maximum timestamp (if checking)
     */
    function setTimestampValidation(
        bool _checkTimestamp,
        uint256 _minTimestamp,
        uint256 _maxTimestamp
    ) external onlyOwner {
        checkTimestamp = _checkTimestamp;
        minTimestamp = _minTimestamp;
        maxTimestamp = _maxTimestamp;
        emit ValidationRuleUpdated("checkTimestamp", _checkTimestamp ? 1 : 0);
    }

    /**
     * @notice Internal validation logic
     * @param data Encoded validation data
     * @return Whether all validation checks pass
     */
    function _performValidation(bytes memory data) internal view returns (bool) {
        if (!active) return false;

        // Decode validation data (amount, sender, timestamp)
        (uint256 amount, address sender, uint256 timestamp) = abi.decode(data, (uint256, address, uint256));

        // Amount validation
        if (amount < minAmount || amount > maxAmount) {
            return false;
        }

        // Sender validation
        if (requiredSender != address(0) && sender != requiredSender) {
            return false;
        }

        // Timestamp validation
        if (checkTimestamp) {
            if (timestamp < minTimestamp || timestamp > maxTimestamp) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Get current validation rules
     * @return minAmount_ Minimum amount
     * @return maxAmount_ Maximum amount
     * @return requiredSender_ Required sender
     * @return checkTimestamp_ Whether timestamp checking is enabled
     * @return minTimestamp_ Minimum timestamp
     * @return maxTimestamp_ Maximum timestamp
     */
    function getValidationRules() external view returns (
        uint256 minAmount_,
        uint256 maxAmount_,
        address requiredSender_,
        bool checkTimestamp_,
        uint256 minTimestamp_,
        uint256 maxTimestamp_
    ) {
        return (minAmount, maxAmount, requiredSender, checkTimestamp, minTimestamp, maxTimestamp);
    }
}
