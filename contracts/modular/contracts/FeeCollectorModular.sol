// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IModularContract.sol";

/**
 * @title FeeCollectorModular
 * @notice Modular contract for collecting and distributing fees
 * @dev A gas-efficient, single-purpose contract for fee collection in the modular system
 */
contract FeeCollectorModular is IModularContract, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Contract metadata
    string public constant override getContractName = "FeeCollectorModular";
    string public constant override getContractVersion = "1.0.0";
    bytes32 public constant override getContractType = keccak256("FEE_COLLECTOR");

    // State variables
    address public leaderContract;
    bool public active;
    address public feeRecipient;
    uint256 public totalFeesCollected;
    mapping(address => uint256) public tokenFeesCollected;

    // Events
    event FeeCollected(address indexed token, uint256 amount, address indexed from);
    event FeeDistributed(address indexed token, uint256 amount, address indexed to);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    constructor(address _leaderContract, address _feeRecipient) {
        require(_leaderContract != address(0), "FeeCollectorModular: Invalid leader contract");
        require(_feeRecipient != address(0), "FeeCollectorModular: Invalid fee recipient");

        leaderContract = _leaderContract;
        feeRecipient = _feeRecipient;
        active = true;
    }

    /**
     * @notice Execute fee collection
     * @param data Encoded fee collection data (token address, amount)
     * @return success Whether collection was successful
     * @return result Encoded result data
     */
    function execute(bytes calldata data)
        external
        override
        nonReentrant
        returns (bool success, bytes memory result)
    {
        require(msg.sender == leaderContract, "FeeCollectorModular: Only leader can execute");
        require(active, "FeeCollectorModular: Contract not active");

        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        require(token != address(0), "FeeCollectorModular: Invalid token address");
        require(amount > 0, "FeeCollectorModular: Invalid amount");

        if (token == address(0)) {
            // Native token (ETH)
            require(msg.value >= amount, "FeeCollectorModular: Insufficient ETH sent");
            payable(feeRecipient).transfer(amount);
        } else {
            // ERC20 token
            IERC20(token).safeTransferFrom(msg.sender, feeRecipient, amount);
        }

        totalFeesCollected += amount;
        tokenFeesCollected[token] += amount;

        emit FeeCollected(token, amount, msg.sender);

        return (true, abi.encode(amount, feeRecipient));
    }

    /**
     * @notice Validate fee collection parameters
     * @param data Encoded validation data
     * @return valid Whether parameters are valid
     */
    function validate(bytes calldata data) external view override returns (bool valid) {
        if (data.length == 0) return false;

        (address token, uint256 amount) = abi.decode(data, (address, uint256));
        if (token == address(0)) {
            // Native token validation
            return amount > 0 && amount <= address(this).balance;
        } else {
            // ERC20 token validation
            if (amount == 0) return false;
            try IERC20(token).balanceOf(msg.sender) returns (uint256 balance) {
                return balance >= amount;
            } catch {
                return false;
            }
        }
    }

    /**
     * @notice Estimate gas cost for fee collection
     * @param data Encoded data for estimation
     * @return gasEstimate Estimated gas cost
     */
    function estimateGas(bytes calldata data) external pure override returns (uint256 gasEstimate) {
        (address token,) = abi.decode(data, (address, uint256));

        // Base gas cost
        uint256 baseGas = 21000; // Base transaction cost

        if (token == address(0)) {
            // Native token transfer
            baseGas += 2300; // Simple transfer
        } else {
            // ERC20 transfer
            baseGas += 65000; // ERC20 transfer with approval check
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
     * @notice Update fee recipient address
     * @param newRecipient New fee recipient address
     */
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "FeeCollectorModular: Invalid recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(oldRecipient, newRecipient);
    }

    /**
     * @notice Get total fees collected for a specific token
     * @param token Token address (address(0) for native token)
     * @return Amount of fees collected
     */
    function getTokenFeesCollected(address token) external view returns (uint256) {
        return tokenFeesCollected[token];
    }

    /**
     * @notice Withdraw stuck tokens (emergency function)
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    // Receive function for native token fees
    receive() external payable {}
}
