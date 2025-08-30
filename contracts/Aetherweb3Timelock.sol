// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAetherweb3Timelock.sol";

/**
 * @title Aetherweb3Timelock
 * @dev Timelock contract for delayed execution of DAO proposals
 */
contract Aetherweb3Timelock is IAetherweb3Timelock, ReentrancyGuard, Ownable {
    // Time delay for execution
    uint256 public constant GRACE_PERIOD = 14 days; // 14 days grace period
    uint256 public constant MINIMUM_DELAY = 2 days;  // 2 days minimum delay
    uint256 public constant MAXIMUM_DELAY = 30 days; // 30 days maximum delay

    uint256 public delay;

    // Transaction structure
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 eta; // Execution time
        bool executed;
        bool canceled;
    }

    mapping(bytes32 => Transaction) public queuedTransactions;
    mapping(address => bool) public authorizedExecutors;

    // Events
    event TransactionQueued(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 eta
    );

    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        bytes data
    );

    event TransactionCanceled(bytes32 indexed txHash);
    event DelayUpdated(uint256 oldDelay, uint256 newDelay);
    event ExecutorAuthorized(address indexed executor);
    event ExecutorRevoked(address indexed executor);

    // Modifiers
    modifier onlyAuthorized() {
        require(
            msg.sender == owner() || authorizedExecutors[msg.sender],
            "Aetherweb3Timelock: caller not authorized"
        );
        _;
    }

    modifier onlyOwnerOrTimelock() {
        require(
            msg.sender == owner() || address(this) == msg.sender,
            "Aetherweb3Timelock: caller not owner or timelock"
        );
        _;
    }

    /**
     * @dev Constructor
     * @param _delay Initial delay for execution
     */
    constructor(uint256 _delay) {
        require(
            _delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY,
            "Aetherweb3Timelock: delay out of range"
        );

        delay = _delay;
    }

    /**
     * @dev Queue a transaction for execution
     * @param target Target contract address
     * @param value ETH value to send
     * @param data Calldata for the transaction
     * @param eta Execution timestamp
     * @return txHash Transaction hash
     */
    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAuthorized returns (bytes32) {
        require(
            eta >= block.timestamp + delay,
            "Aetherweb3Timelock: eta too early"
        );
        require(
            eta <= block.timestamp + delay + GRACE_PERIOD,
            "Aetherweb3Timelock: eta too late"
        );

        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));

        require(
            queuedTransactions[txHash].eta == 0,
            "Aetherweb3Timelock: transaction already queued"
        );

        queuedTransactions[txHash] = Transaction({
            target: target,
            value: value,
            data: data,
            eta: eta,
            executed: false,
            canceled: false
        });

        emit TransactionQueued(txHash, target, value, data, eta);

        return txHash;
    }

    /**
     * @dev Cancel a queued transaction
     * @param target Target contract address
     * @param value ETH value
     * @param data Calldata
     * @param eta Execution timestamp
     */
    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external onlyAuthorized {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));

        require(
            queuedTransactions[txHash].eta != 0,
            "Aetherweb3Timelock: transaction not queued"
        );

        delete queuedTransactions[txHash];

        emit TransactionCanceled(txHash);
    }

    /**
     * @dev Execute a queued transaction
     * @param target Target contract address
     * @param value ETH value
     * @param data Calldata
     * @param eta Execution timestamp
     * @return returnData Return data from the executed transaction
     */
    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external payable onlyAuthorized nonReentrant returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));

        Transaction storage transaction = queuedTransactions[txHash];
        require(transaction.eta != 0, "Aetherweb3Timelock: transaction not queued");
        require(!transaction.executed, "Aetherweb3Timelock: transaction already executed");
        require(!transaction.canceled, "Aetherweb3Timelock: transaction canceled");
        require(
            block.timestamp >= transaction.eta,
            "Aetherweb3Timelock: transaction not ready"
        );
        require(
            block.timestamp <= transaction.eta + GRACE_PERIOD,
            "Aetherweb3Timelock: transaction expired"
        );

        transaction.executed = true;

        // Execute the transaction
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "Aetherweb3Timelock: transaction execution failed");

        emit TransactionExecuted(txHash, target, value, data);

        return returnData;
    }

    /**
     * @dev Get transaction details
     * @param txHash Transaction hash
     * @return target, value, data, eta, executed, canceled
     */
    function getTransaction(bytes32 txHash) external view returns (
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta,
        bool executed,
        bool canceled
    ) {
        Transaction storage transaction = queuedTransactions[txHash];
        return (
            transaction.target,
            transaction.value,
            transaction.data,
            transaction.eta,
            transaction.executed,
            transaction.canceled
        );
    }

    /**
     * @dev Check if a transaction is ready for execution
     * @param txHash Transaction hash
     * @return True if ready for execution
     */
    function isTransactionReady(bytes32 txHash) external view returns (bool) {
        Transaction storage transaction = queuedTransactions[txHash];

        if (transaction.eta == 0 || transaction.executed || transaction.canceled) {
            return false;
        }

        return block.timestamp >= transaction.eta &&
               block.timestamp <= transaction.eta + GRACE_PERIOD;
    }

    // Admin functions

    /**
     * @dev Update delay period (only owner)
     * @param newDelay New delay period
     */
    function setDelay(uint256 newDelay) external onlyOwner {
        require(
            newDelay >= MINIMUM_DELAY && newDelay <= MAXIMUM_DELAY,
            "Aetherweb3Timelock: delay out of range"
        );

        uint256 oldDelay = delay;
        delay = newDelay;

        emit DelayUpdated(oldDelay, newDelay);
    }

    /**
     * @dev Authorize an executor (only owner)
     * @param executor Address to authorize
     */
    function authorizeExecutor(address executor) external onlyOwner {
        require(executor != address(0), "Aetherweb3Timelock: invalid executor");
        require(!authorizedExecutors[executor], "Aetherweb3Timelock: already authorized");

        authorizedExecutors[executor] = true;

        emit ExecutorAuthorized(executor);
    }

    /**
     * @dev Revoke executor authorization (only owner)
     * @param executor Address to revoke
     */
    function revokeExecutor(address executor) external onlyOwner {
        require(authorizedExecutors[executor], "Aetherweb3Timelock: not authorized");

        authorizedExecutors[executor] = false;

        emit ExecutorRevoked(executor);
    }

    /**
     * @dev Accept ownership transfer (for timelock itself)
     */
    function acceptOwnership() external onlyOwnerOrTimelock {
        // This function allows the timelock to accept ownership
        // Implementation would depend on the specific use case
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}
