// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3Bridge
 * @dev Cross-chain bridging utility library
 * @notice Provides bridging calculations, fee estimations, and cross-chain operations
 */
library Aetherweb3Bridge {
    using Aetherweb3Math for uint256;

    // Bridge transaction information
    struct BridgeTransaction {
        address sender;           // Original sender
        address receiver;         // Destination receiver
        address token;            // Token to bridge
        uint256 amount;           // Amount to bridge
        uint256 sourceChainId;    // Source chain ID
        uint256 destChainId;      // Destination chain ID
        uint256 nonce;            // Transaction nonce
        uint256 timestamp;        // Transaction timestamp
        bytes32 txHash;           // Transaction hash
        BridgeStatus status;      // Transaction status
        uint256 bridgeFee;        // Bridge fee paid
        uint256 gasFee;           // Gas fee estimate
    }

    // Bridge status enumeration
    enum BridgeStatus {
        PENDING,
        PROCESSING,
        COMPLETED,
        FAILED,
        REFUNDED
    }

    // Bridge configuration
    struct BridgeConfig {
        uint256 minBridgeAmount;  // Minimum bridge amount
        uint256 maxBridgeAmount;  // Maximum bridge amount
        uint256 bridgeFee;        // Base bridge fee
        uint256 gasLimit;         // Gas limit for destination
        uint256 confirmationBlocks; // Required confirmations
        bool isActive;           // Bridge active status
        mapping(uint256 => bool) supportedChains; // Supported chains
    }

    // Bridge liquidity information
    struct BridgeLiquidity {
        address token;            // Token address
        uint256 sourceLiquidity;  // Liquidity on source chain
        uint256 destLiquidity;    // Liquidity on destination chain
        uint256 lockedAmount;     // Amount locked in bridge
        uint256 minLiquidityThreshold; // Minimum liquidity threshold
        uint256 maxLiquidityThreshold; // Maximum liquidity threshold
    }

    // Cross-chain message
    struct CrossChainMessage {
        uint256 messageId;        // Unique message ID
        uint256 sourceChainId;    // Source chain ID
        uint256 destChainId;      // Destination chain ID
        address sender;           // Message sender
        address receiver;         // Message receiver
        bytes data;              // Message data
        uint256 gasLimit;         // Gas limit for execution
        uint256 value;            // Value to send
        MessageStatus status;     // Message status
    }

    // Message status enumeration
    enum MessageStatus {
        PENDING,
        SENT,
        RECEIVED,
        EXECUTED,
        FAILED
    }

    /**
     * @dev Calculates bridge fee for cross-chain transfer
     * @param amount Amount to bridge
     * @param sourceChainId Source chain ID
     * @param destChainId Destination chain ID
     * @param baseFee Base bridge fee
     * @param feePercentage Fee percentage (in wad)
     * @return totalFee Total bridge fee
     */
    function calculateBridgeFee(
        uint256 amount,
        uint256 sourceChainId,
        uint256 destChainId,
        uint256 baseFee,
        uint256 feePercentage
    ) internal pure returns (uint256 totalFee) {
        uint256 percentageFee = amount.wmul(feePercentage);
        totalFee = baseFee + percentageFee;
    }

    /**
     * @dev Estimates gas fee for destination chain execution
     * @param gasLimit Gas limit for execution
     * @param gasPrice Gas price on destination chain
     * @param bufferPercentage Buffer percentage for gas estimation
     * @return estimatedFee Estimated gas fee
     */
    function estimateDestinationGasFee(
        uint256 gasLimit,
        uint256 gasPrice,
        uint256 bufferPercentage
    ) internal pure returns (uint256 estimatedFee) {
        uint256 bufferMultiplier = Aetherweb3Math.WAD + bufferPercentage;
        estimatedFee = gasLimit * gasPrice;
        estimatedFee = estimatedFee.wmul(bufferMultiplier);
    }

    /**
     * @dev Calculates total bridge cost
     * @param bridgeFee Bridge fee
     * @param gasFee Gas fee
     * @param slippageTolerance Slippage tolerance
     * @return totalCost Total cost including fees and slippage
     */
    function calculateTotalBridgeCost(
        uint256 bridgeFee,
        uint256 gasFee,
        uint256 slippageTolerance
    ) internal pure returns (uint256 totalCost) {
        uint256 slippageAmount = (bridgeFee + gasFee).wmul(slippageTolerance);
        totalCost = bridgeFee + gasFee + slippageAmount;
    }

    /**
     * @dev Validates bridge transaction parameters
     * @param tx Bridge transaction
     * @param config Bridge configuration
     * @return isValid True if transaction is valid
     */
    function validateBridgeTransaction(
        BridgeTransaction memory tx,
        BridgeConfig memory config
    ) internal pure returns (bool isValid) {
        if (tx.sender == address(0)) return false;
        if (tx.receiver == address(0)) return false;
        if (tx.token == address(0)) return false;
        if (tx.amount < config.minBridgeAmount) return false;
        if (tx.amount > config.maxBridgeAmount) return false;
        if (!config.supportedChains[tx.sourceChainId]) return false;
        if (!config.supportedChains[tx.destChainId]) return false;
        if (tx.sourceChainId == tx.destChainId) return false;
        if (!config.isActive) return false;
        return true;
    }

    /**
     * @dev Calculates bridge exchange rate
     * @param sourceAmount Amount on source chain
     * @param sourcePrice Price on source chain
     * @param destPrice Price on destination chain
     * @param feePercentage Fee percentage
     * @return destAmount Amount received on destination chain
     */
    function calculateBridgeExchangeRate(
        uint256 sourceAmount,
        uint256 sourcePrice,
        uint256 destPrice,
        uint256 feePercentage
    ) internal pure returns (uint256 destAmount) {
        if (sourcePrice == 0 || destPrice == 0) return 0;

        uint256 value = sourceAmount.wmul(sourcePrice);
        uint256 fee = value.wmul(feePercentage);
        uint256 netValue = value - fee;
        destAmount = netValue.wdiv(destPrice);
    }

    /**
     * @dev Checks bridge liquidity sufficiency
     * @param liquidity Bridge liquidity information
     * @param requestedAmount Requested bridge amount
     * @return isSufficient True if liquidity is sufficient
     */
    function checkBridgeLiquidity(
        BridgeLiquidity memory liquidity,
        uint256 requestedAmount
    ) internal pure returns (bool isSufficient) {
        uint256 availableLiquidity = liquidity.destLiquidity - liquidity.lockedAmount;
        return availableLiquidity >= requestedAmount &&
               availableLiquidity >= liquidity.minLiquidityThreshold;
    }

    /**
     * @dev Calculates bridge completion time estimate
     * @param sourceConfirmations Required source confirmations
     * @param destConfirmations Required destination confirmations
     * @param avgBlockTime Average block time
     * @param processingTime Additional processing time
     * @return estimatedTime Estimated completion time in seconds
     */
    function estimateBridgeCompletionTime(
        uint256 sourceConfirmations,
        uint256 destConfirmations,
        uint256 avgBlockTime,
        uint256 processingTime
    ) internal pure returns (uint256 estimatedTime) {
        uint256 sourceTime = sourceConfirmations * avgBlockTime;
        uint256 destTime = destConfirmations * avgBlockTime;
        estimatedTime = sourceTime + destTime + processingTime;
    }

    /**
     * @dev Calculates bridge success probability
     * @param historicalSuccessRate Historical success rate
     * @param currentLiquidity Current liquidity ratio
     * @param networkCongestion Network congestion level
     * @return probability Success probability (0-100)
     */
    function calculateBridgeSuccessProbability(
        uint256 historicalSuccessRate,
        uint256 currentLiquidity,
        uint256 networkCongestion
    ) internal pure returns (uint256 probability) {
        // Simplified calculation
        uint256 liquidityFactor = currentLiquidity >= Aetherweb3Math.WAD ? 100 : 50;
        uint256 congestionPenalty = networkCongestion / 10; // 0-10 penalty

        probability = historicalSuccessRate * liquidityFactor / 100;
        if (probability > congestionPenalty) {
            probability = probability - congestionPenalty;
        } else {
            probability = 0;
        }
    }

    /**
     * @dev Generates bridge transaction hash
     * @param tx Bridge transaction
     * @return txHash Transaction hash
     */
    function generateBridgeTxHash(
        BridgeTransaction memory tx
    ) internal pure returns (bytes32 txHash) {
        txHash = keccak256(abi.encodePacked(
            tx.sender,
            tx.receiver,
            tx.token,
            tx.amount,
            tx.sourceChainId,
            tx.destChainId,
            tx.nonce,
            tx.timestamp
        ));
    }

    /**
     * @dev Validates cross-chain message
     * @param message Cross-chain message
     * @return isValid True if message is valid
     */
    function validateCrossChainMessage(
        CrossChainMessage memory message
    ) internal pure returns (bool isValid) {
        if (message.sender == address(0)) return false;
        if (message.receiver == address(0)) return false;
        if (message.sourceChainId == message.destChainId) return false;
        if (message.data.length == 0 && message.value == 0) return false;
        return true;
    }

    /**
     * @dev Calculates message execution cost
     * @param message Cross-chain message
     * @param gasPrice Gas price on destination
     * @param baseExecutionFee Base execution fee
     * @return executionCost Total execution cost
     */
    function calculateMessageExecutionCost(
        CrossChainMessage memory message,
        uint256 gasPrice,
        uint256 baseExecutionFee
    ) internal pure returns (uint256 executionCost) {
        uint256 gasCost = message.gasLimit * gasPrice;
        executionCost = gasCost + baseExecutionFee + message.value;
    }

    /**
     * @dev Calculates bridge utilization rate
     * @param totalVolume Total bridge volume
     * @param capacity Bridge capacity
     * @param timePeriod Time period
     * @return utilizationRate Utilization rate percentage
     */
    function calculateBridgeUtilization(
        uint256 totalVolume,
        uint256 capacity,
        uint256 timePeriod
    ) internal pure returns (uint256 utilizationRate) {
        if (capacity == 0 || timePeriod == 0) return 0;
        uint256 hourlyCapacity = capacity * 3600 / timePeriod;
        utilizationRate = totalVolume.wdiv(hourlyCapacity);
    }

    /**
     * @dev Estimates bridge slippage
     * @param amount Bridge amount
     * @param liquidityRatio Current liquidity ratio
     * @param volatility Volatility index
     * @return slippage Estimated slippage percentage
     */
    function estimateBridgeSlippage(
        uint256 amount,
        uint256 liquidityRatio,
        uint256 volatility
    ) internal pure returns (uint256 slippage) {
        // Simplified slippage calculation
        uint256 sizeImpact = amount.wdiv(liquidityRatio);
        slippage = sizeImpact + volatility / 100;
    }

    /**
     * @dev Calculates bridge efficiency
     * @param successfulTxs Number of successful transactions
     * @param totalTxs Total transactions
     * @param avgCompletionTime Average completion time
     * @param targetCompletionTime Target completion time
     * @return efficiency Bridge efficiency score
     */
    function calculateBridgeEfficiency(
        uint256 successfulTxs,
        uint256 totalTxs,
        uint256 avgCompletionTime,
        uint256 targetCompletionTime
    ) internal pure returns (uint256 efficiency) {
        if (totalTxs == 0) return 0;

        uint256 successRate = successfulTxs.wdiv(totalTxs);
        uint256 timeEfficiency = targetCompletionTime.wdiv(avgCompletionTime);

        efficiency = (successRate + timeEfficiency) / 2;
    }

    /**
     * @dev Checks if bridge needs liquidity rebalancing
     * @param liquidity Bridge liquidity
     * @param threshold Threshold percentage
     * @return needsRebalance True if rebalancing is needed
     */
    function needsLiquidityRebalancing(
        BridgeLiquidity memory liquidity,
        uint256 threshold
    ) internal pure returns (bool needsRebalance) {
        uint256 utilization = liquidity.lockedAmount.wdiv(liquidity.destLiquidity);
        return utilization > threshold;
    }

    /**
     * @dev Calculates optimal bridge amount
     * @param availableLiquidity Available liquidity
     * @param maxAmount Maximum allowed amount
     * @param feePercentage Fee percentage
     * @param slippageTolerance Slippage tolerance
     * @return optimalAmount Optimal bridge amount
     */
    function calculateOptimalBridgeAmount(
        uint256 availableLiquidity,
        uint256 maxAmount,
        uint256 feePercentage,
        uint256 slippageTolerance
    ) internal pure returns (uint256 optimalAmount) {
        uint256 maxByLiquidity = availableLiquidity * 90 / 100; // 90% of available
        uint256 maxByAmount = maxAmount;
        uint256 maxByFee = availableLiquidity * Aetherweb3Math.WAD / (Aetherweb3Math.WAD + feePercentage);
        uint256 maxBySlippage = availableLiquidity * Aetherweb3Math.WAD / (Aetherweb3Math.WAD + slippageTolerance);

        optimalAmount = Aetherweb3Math.min(
            Aetherweb3Math.min(maxByLiquidity, maxByAmount),
            Aetherweb3Math.min(maxByFee, maxBySlippage)
        );
    }

    /**
     * @dev Validates bridge configuration
     * @param config Bridge configuration
     * @return isValid True if configuration is valid
     */
    function validateBridgeConfig(
        BridgeConfig memory config
    ) internal pure returns (bool isValid) {
        if (config.minBridgeAmount >= config.maxBridgeAmount) return false;
        if (config.bridgeFee == 0) return false;
        if (config.gasLimit == 0) return false;
        if (config.confirmationBlocks == 0) return false;
        return true;
    }
}
