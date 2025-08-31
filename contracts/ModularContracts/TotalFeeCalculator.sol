// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";
import "../libraries/FeeLib.sol";
import "../libraries/MathLib.sol";

/**
 * @title TotalFeeCalculator
 * @dev Comprehensive fee calculation contract for DeFi operations
 * @notice Calculates total fees including gas, flash loan, trading, and network fees
 */
contract TotalFeeCalculator is IModularContract {
    using FixedPointMath for uint256;

    // Contract identification
    string public constant override name = "TotalFeeCalculator";
    uint256 public constant override version = 1;

    // Fee calculation results
    struct FeeCalculation {
        uint256 tradingFee;
        uint256 flashFee;
        uint256 gasFee;
        uint256 networkFee;
        uint256 protocolFee;
        uint256 totalFee;
        uint256 effectiveRate;
        bool isValid;
    }

    // Gas estimation parameters
    struct GasParams {
        uint256 baseGasLimit;
        uint256 gasPrice;
        uint256 gasBuffer; // in basis points
        uint256 networkCongestion; // 0-10000
    }

    // Storage
    mapping(bytes32 => FeeLib.FeeConfig) private _feeConfigs;
    mapping(bytes32 => GasParams) private _gasParams;

    // Events
    event FeeCalculated(bytes32 indexed operationId, uint256 totalFee, uint256 effectiveRate);
    event FeeConfigUpdated(bytes32 indexed operationId, FeeLib.FeeConfig config);
    event GasParamsUpdated(bytes32 indexed operationId, GasParams params);

    /**
     * @dev Initialize fee configuration for operation type
     */
    function initializeFeeConfig(
        bytes32 operationId,
        FeeLib.FeeConfig memory config
    ) external override onlyLeader {
        require(FeeLib.validateFeeConfig(config), "TotalFeeCalculator: invalid fee config");
        _feeConfigs[operationId] = config;
        emit FeeConfigUpdated(operationId, config);
    }

    /**
     * @dev Initialize gas parameters for operation type
     */
    function initializeGasParams(
        bytes32 operationId,
        GasParams memory params
    ) external override onlyLeader {
        require(params.gasBuffer <= 10000, "TotalFeeCalculator: invalid gas buffer");
        require(params.networkCongestion <= 10000, "TotalFeeCalculator: invalid congestion");
        _gasParams[operationId] = params;
        emit GasParamsUpdated(operationId, params);
    }

    /**
     * @dev Calculate total fee for a trading operation
     */
    function calculateTotalTradingFee(
        bytes32 operationId,
        uint256 amount,
        uint256 volatility,
        uint256 liquidityRatio,
        uint256 gasLimit,
        uint256 gasPrice
    ) external view returns (FeeCalculation memory) {
        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        require(config.baseFee > 0, "TotalFeeCalculator: fee config not initialized");

        FeeLib.FeeBreakdown memory breakdown = FeeLib.calculateTotalFeeBreakdown(
            amount,
            config,
            volatility,
            liquidityRatio,
            gasLimit,
            gasPrice
        );

        FeeCalculation memory result;
        result.tradingFee = breakdown.tradingFee;
        result.flashFee = breakdown.flashFee;
        result.gasFee = breakdown.gasFee;
        result.protocolFee = breakdown.protocolFee;
        result.totalFee = breakdown.totalFee;
        result.effectiveRate = FeeLib.calculateEffectiveFeeRate(amount, breakdown);
        result.isValid = true;

        return result;
    }

    /**
     * @dev Calculate fee for arbitrage operation
     */
    function calculateArbitrageFee(
        bytes32 operationId,
        uint256 profit,
        uint256 minProfitThreshold
    ) external view returns (uint256) {
        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        return FeeLib.calculateArbitrageFee(profit, config.baseFee, minProfitThreshold);
    }

    /**
     * @dev Calculate tiered fee based on trade size
     */
    function calculateTieredFee(
        bytes32 operationId,
        uint256 amount,
        uint256[] memory tierThresholds,
        uint256[] memory tierFees
    ) external view returns (uint256) {
        return FeeLib.calculateTieredFee(amount, tierThresholds, tierFees);
    }

    /**
     * @dev Calculate volume-based discount
     */
    function calculateVolumeDiscount(
        bytes32 operationId,
        uint256 volume,
        uint256[] memory volumeThresholds,
        uint256[] memory discountRates
    ) external view returns (uint256) {
        return FeeLib.calculateVolumeDiscount(volume, volumeThresholds, discountRates);
    }

    /**
     * @dev Apply discount to fee
     */
    function applyDiscount(
        uint256 fee,
        uint256 discountBps
    ) external pure returns (uint256) {
        return FeeLib.applyDiscount(fee, discountBps);
    }

    /**
     * @dev Calculate network fee for cross-chain operations
     */
    function calculateNetworkFee(
        bytes32 operationId,
        uint256 amount,
        uint256 bridgeFee
    ) external view returns (uint256) {
        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        return FeeLib.calculateNetworkFee(amount, config.baseFee, bridgeFee);
    }

    /**
     * @dev Calculate liquidation fee
     */
    function calculateLiquidationFee(
        bytes32 operationId,
        uint256 debtAmount,
        uint256 collateralAmount,
        uint256 liquidationBonus
    ) external view returns (uint256) {
        return FeeLib.calculateLiquidationFee(debtAmount, collateralAmount, liquidationBonus);
    }

    /**
     * @dev Estimate gas fee with network conditions
     */
    function estimateGasFee(
        bytes32 operationId,
        uint256 gasLimit,
        uint256 gasPrice
    ) external view returns (uint256) {
        GasParams memory params = _gasParams[operationId];
        if (params.baseGasLimit == 0) return FeeLib.estimateGasFee(gasLimit, gasPrice, 200); // Default 2% buffer

        // Adjust gas limit based on network congestion
        uint256 adjustedGasLimit = gasLimit + (gasLimit * params.networkCongestion / 10000);
        return FeeLib.estimateGasFee(adjustedGasLimit, gasPrice, params.gasBuffer);
    }

    /**
     * @dev Calculate fee distribution
     */
    function calculateFeeDistribution(
        bytes32 operationId,
        uint256 totalFee,
        uint256 protocolShare,
        uint256 treasuryShare,
        uint256 liquidityShare
    ) external pure returns (uint256 protocolFee, uint256 treasuryFee, uint256 liquidityFee) {
        return FeeLib.calculateFeeDistribution(totalFee, protocolShare, treasuryShare, liquidityShare);
    }

    /**
     * @dev Get fee configuration
     */
    function getFeeConfig(bytes32 operationId) external view returns (FeeLib.FeeConfig memory) {
        return _feeConfigs[operationId];
    }

    /**
     * @dev Get gas parameters
     */
    function getGasParams(bytes32 operationId) external view returns (GasParams memory) {
        return _gasParams[operationId];
    }

    /**
     * @dev Update fee configuration
     */
    function updateFeeConfig(
        bytes32 operationId,
        FeeLib.FeeConfig memory newConfig
    ) external override onlyLeader {
        require(FeeLib.validateFeeConfig(newConfig), "TotalFeeCalculator: invalid config");
        _feeConfigs[operationId] = newConfig;
        emit FeeConfigUpdated(operationId, newConfig);
    }

    /**
     * @dev Update gas parameters
     */
    function updateGasParams(
        bytes32 operationId,
        GasParams memory newParams
    ) external override onlyLeader {
        require(newParams.gasBuffer <= 10000, "TotalFeeCalculator: invalid gas buffer");
        require(newParams.networkCongestion <= 10000, "TotalFeeCalculator: invalid congestion");
        _gasParams[operationId] = newParams;
        emit GasParamsUpdated(operationId, newParams);
    }

    /**
     * @dev Calculate projected profit after fees
     */
    function calculateProjectedProfit(
        bytes32 operationId,
        uint256 grossProfit,
        uint256 gasCost,
        uint256 flashFee
    ) external view returns (uint256 netProfit, uint256 profitMargin) {
        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        uint256 totalFees = gasCost + flashFee + FeeLib.calculateArbitrageFee(grossProfit, config.baseFee, 0);

        netProfit = grossProfit > totalFees ? grossProfit - totalFees : 0;
        profitMargin = grossProfit > 0 ? (netProfit * 10000) / grossProfit : 0;
    }

    /**
     * @dev Validate fee calculation
     */
    function validateFeeCalculation(
        FeeCalculation memory calculation,
        uint256 maxEffectiveRate
    ) external pure returns (bool) {
        return calculation.isValid &&
               calculation.effectiveRate <= maxEffectiveRate &&
               calculation.totalFee > 0;
    }

    /**
     * @dev Modular contract execution hooks
     */
    function beforeAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // Calculate and validate fees before action execution
        (bytes32 operationId, uint256 amount, uint256 expectedFee) = abi.decode(data, (bytes32, uint256, uint256));

        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        uint256 calculatedFee = FeeLib.calculateTradingFee(amount, config.baseFee, config.minFee, config.maxFee);

        require(calculatedFee <= expectedFee, "TotalFeeCalculator: fee exceeds expected");
        return true;
    }

    function afterAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // Log fee calculation after action
        (bytes32 operationId, uint256 totalFee, uint256 effectiveRate) = abi.decode(data, (bytes32, uint256, uint256));
        emit FeeCalculated(operationId, totalFee, effectiveRate);
        return true;
    }

    function validateAction(bytes32 actionId, bytes memory data) external view override returns (bool) {
        (bytes32 operationId, uint256 amount) = abi.decode(data, (bytes32, uint256));
        FeeLib.FeeConfig memory config = _feeConfigs[operationId];
        return config.baseFee > 0 && amount > 0;
    }

    // Required interface functions
    function beforeInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeValidation(bytes memory data) external view override returns (bool) { return true; }
    function afterValidation(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }

    // Access control
    modifier onlyLeader() {
        require(msg.sender == IModularLeader(address(this)).getLeader(), "TotalFeeCalculator: only leader");
        _;
    }
}
