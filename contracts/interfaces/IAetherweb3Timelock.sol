// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAetherweb3Timelock
 * @dev Interface for the Aetherweb3Timelock contract
 */
interface IAetherweb3Timelock {
    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 eta;
        bool executed;
        bool canceled;
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta
    ) external payable returns (bytes memory);

    function getTransaction(bytes32 txHash) external view returns (
        address target,
        uint256 value,
        bytes memory data,
        uint256 eta,
        bool executed,
        bool canceled
    );

    function isTransactionReady(bytes32 txHash) external view returns (bool);

    function setDelay(uint256 newDelay) external;
    function authorizeExecutor(address executor) external;
    function revokeExecutor(address executor) external;

    function delay() external view returns (uint256);
    function queuedTransactions(bytes32 txHash) external view returns (
        address target,
        uint256 value,
        uint256 eta,
        bool executed,
        bool canceled
    );
    function authorizedExecutors(address executor) external view returns (bool);
}
