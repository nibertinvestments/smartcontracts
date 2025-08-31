// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MathLib.sol";

/**
 * @title FeeLib
 * @dev Gas-optimized fee calculation library for DeFi operations
 * @notice Handles various fee types: trading, flash loan, gas, and dynamic fees
 */
library FeeLib {
    using FixedPointMath for uint256;

    struct FeeConfig {
        uint256 baseFee;        // Base fee in basis points (1/10000)
        uint256 dynamicFee;     // Dynamic fee component
        uint256 flashFee;       // Flash loan fee
        uint256 gasFee;         // Gas fee estimation
        uint256 maxFee;         // Maximum total fee
        uint256 minFee;         // Minimum total fee
    }

    struct FeeBreakdown {
        uint256 tradingFee;
        uint256 flashFee;
        uint256 gasFee;
        uint256 protocolFee;
        uint256 totalFee;
    }

    /**
     * @dev Calculates trading fee based on amount and fee configuration
     */
    function calculateTradingFee(
        uint256 amount,
        uint256 feeBps,
        uint256 minFee,
        uint256 maxFee
    ) internal pure returns (uint256) {
        unchecked {
            uint256 fee = amount.mulDiv(feeBps, 10000);
            if (fee < minFee) return minFee;
            if (fee > maxFee) return maxFee;
            return fee;
        }
    }

    /**
     * @dev Calculates dynamic fee based on volatility and liquidity
     */
    function calculateDynamicFee(
        uint256 baseFee,
        uint256 volatility,
        uint256 liquidityRatio,
        uint256 maxDynamicFee
    ) internal pure returns (uint256) {
        unchecked {
            // Higher volatility = higher fee
            uint256 volatilityMultiplier = 1e18 + (volatility * 2); // 2x max multiplier

            // Lower liquidity = higher fee
            uint256 liquidityMultiplier = liquidityRatio < 1e18
                ? 1e18 + ((1e18 - liquidityRatio) * 2)
                : 1e18;

            uint256 dynamicFee = baseFee.mulDiv(volatilityMultiplier, 1e18);
            dynamicFee = dynamicFee.mulDiv(liquidityMultiplier, 1e18);

            return dynamicFee > maxDynamicFee ? maxDynamicFee : dynamicFee;
        }
    }

    /**
     * @dev Calculates flash loan fee
     */
    function calculateFlashFee(
        uint256 amount,
        uint256 feeBps,
        uint256 premiumBps
    ) internal pure returns (uint256) {
        unchecked {
            uint256 baseFlashFee = amount.mulDiv(feeBps, 10000);
            uint256 premiumFee = amount.mulDiv(premiumBps, 10000);
            return baseFlashFee + premiumFee;
        }
    }

    /**
     * @dev Estimates gas fee for transaction
     */
    function estimateGasFee(
        uint256 gasLimit,
        uint256 gasPrice,
        uint256 gasBuffer // in basis points
    ) internal pure returns (uint256) {
        unchecked {
            uint256 baseGasCost = gasLimit * gasPrice;
            uint256 bufferAmount = baseGasCost.mulDiv(gasBuffer, 10000);
            return baseGasCost + bufferAmount;
        }
    }

    /**
     * @dev Calculates total fee breakdown for a trade
     */
    function calculateTotalFeeBreakdown(
        uint256 amount,
        FeeConfig memory config,
        uint256 volatility,
        uint256 liquidityRatio,
        uint256 gasLimit,
        uint256 gasPrice
    ) internal pure returns (FeeBreakdown memory) {
        unchecked {
            FeeBreakdown memory breakdown;

            // Trading fee (base + dynamic)
            uint256 dynamicFee = calculateDynamicFee(
                config.baseFee,
                volatility,
                liquidityRatio,
                config.dynamicFee
            );
            uint256 totalTradingFee = calculateTradingFee(
                amount,
                config.baseFee + dynamicFee,
                config.minFee,
                config.maxFee
            );
            breakdown.tradingFee = totalTradingFee;

            // Flash fee (if applicable)
            breakdown.flashFee = config.flashFee > 0
                ? calculateFlashFee(amount, config.flashFee, 5) // 5 bps premium
                : 0;

            // Gas fee estimation
            breakdown.gasFee = estimateGasFee(gasLimit, gasPrice, 200); // 2% buffer

            // Protocol fee (10% of trading fee)
            breakdown.protocolFee = totalTradingFee / 10;

            // Total fee
            breakdown.totalFee = breakdown.tradingFee +
                               breakdown.flashFee +
                               breakdown.gasFee +
                               breakdown.protocolFee;

            // Apply maximum fee cap
            if (breakdown.totalFee > config.maxFee) {
                breakdown.totalFee = config.maxFee;
            }

            return breakdown;
        }
    }

    /**
     * @dev Calculates fee for arbitrage opportunity
     */
    function calculateArbitrageFee(
        uint256 profit,
        uint256 feeBps,
        uint256 minProfitThreshold
    ) internal pure returns (uint256) {
        unchecked {
            if (profit <= minProfitThreshold) return 0;

            uint256 netProfit = profit - minProfitThreshold;
            return netProfit.mulDiv(feeBps, 10000);
        }
    }

    /**
     * @dev Calculates tiered fee based on trade size
     */
    function calculateTieredFee(
        uint256 amount,
        uint256[] memory tierThresholds,
        uint256[] memory tierFees
    ) internal pure returns (uint256) {
        unchecked {
            require(tierThresholds.length == tierFees.length, "FeeLib: tier array mismatch");

            for (uint256 i = tierThresholds.length; i > 0; i--) {
                if (amount >= tierThresholds[i - 1]) {
                    return amount.mulDiv(tierFees[i - 1], 10000);
                }
            }

            return 0; // No fee for amounts below minimum tier
        }
    }

    /**
     * @dev Calculates volume-based discount
     */
    function calculateVolumeDiscount(
        uint256 volume,
        uint256[] memory volumeThresholds,
        uint256[] memory discountRates
    ) internal pure returns (uint256) {
        unchecked {
            require(volumeThresholds.length == discountRates.length, "FeeLib: discount array mismatch");

            for (uint256 i = volumeThresholds.length; i > 0; i--) {
                if (volume >= volumeThresholds[i - 1]) {
                    return discountRates[i - 1];
                }
            }

            return 0; // No discount
        }
    }

    /**
     * @dev Applies discount to fee
     */
    function applyDiscount(
        uint256 fee,
        uint256 discountBps
    ) internal pure returns (uint256) {
        unchecked {
            if (discountBps >= 10000) return 0; // 100% discount
            return fee.mulDiv(10000 - discountBps, 10000);
        }
    }

    /**
     * @dev Calculates network fee for cross-chain operations
     */
    function calculateNetworkFee(
        uint256 amount,
        uint256 networkFeeBps,
        uint256 bridgeFee
    ) internal pure returns (uint256) {
        unchecked {
            uint256 percentageFee = amount.mulDiv(networkFeeBps, 10000);
            return percentageFee + bridgeFee;
        }
    }

    /**
     * @dev Calculates liquidation fee
     */
    function calculateLiquidationFee(
        uint256 debtAmount,
        uint256 collateralAmount,
        uint256 liquidationBonus
    ) internal pure returns (uint256) {
        unchecked {
            uint256 bonusAmount = debtAmount.mulDiv(liquidationBonus, 10000);
            return debtAmount + bonusAmount;
        }
    }

    /**
     * @dev Validates fee configuration
     */
    function validateFeeConfig(FeeConfig memory config) internal pure returns (bool) {
        return config.minFee <= config.maxFee &&
               config.baseFee <= 10000 && // Max 100%
               config.dynamicFee <= 10000 &&
               config.flashFee <= 10000 &&
               config.gasFee <= 10000;
    }

    /**
     * @dev Calculates effective fee rate after all adjustments
     */
    function calculateEffectiveFeeRate(
        uint256 amount,
        FeeBreakdown memory breakdown
    ) internal pure returns (uint256) {
        unchecked {
            if (amount == 0) return 0;
            return breakdown.totalFee.mulDiv(10000, amount);
        }
    }

    /**
     * @dev Calculates fee distribution among stakeholders
     */
    function calculateFeeDistribution(
        uint256 totalFee,
        uint256 protocolShare, // in basis points
        uint256 treasuryShare, // in basis points
        uint256 liquidityShare  // in basis points
    ) internal pure returns (uint256 protocolFee, uint256 treasuryFee, uint256 liquidityFee) {
        unchecked {
            require(protocolShare + treasuryShare + liquidityShare <= 10000, "FeeLib: shares exceed 100%");

            protocolFee = totalFee.mulDiv(protocolShare, 10000);
            treasuryFee = totalFee.mulDiv(treasuryShare, 10000);
            liquidityFee = totalFee.mulDiv(liquidityShare, 10000);
        }
    }
}
