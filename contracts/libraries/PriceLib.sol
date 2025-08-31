// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MathLib.sol";

/**
 * @title PriceLib
 * @dev Gas-optimized price calculations and TWAP functionality
 * @notice Handles price feeds, TWAP calculations, and price manipulation detection
 */
library PriceLib {
    using FixedPointMath for uint256;

    struct PriceObservation {
        uint256 timestamp;
        uint256 price;
        uint256 cumulativePrice;
    }

    struct TWAPState {
        uint256 lastUpdateTime;
        uint256 lastPrice;
        uint256 cumulativePrice;
        uint256 observationCount;
        uint256 timeWeightedAveragePrice;
    }

    /**
     * @dev Updates TWAP with new price observation
     */
    function updateTWAP(
        TWAPState storage state,
        uint256 currentPrice,
        uint256 currentTime
    ) internal {
        unchecked {
            if (state.lastUpdateTime == 0) {
                // First observation
                state.lastUpdateTime = currentTime;
                state.lastPrice = currentPrice;
                state.cumulativePrice = currentPrice;
                state.observationCount = 1;
                state.timeWeightedAveragePrice = currentPrice;
                return;
            }

            uint256 timeElapsed = currentTime - state.lastUpdateTime;
            if (timeElapsed == 0) return; // Same block, skip

            // Update cumulative price
            state.cumulativePrice += state.lastPrice * timeElapsed;

            // Update TWAP
            if (state.observationCount > 0) {
                state.timeWeightedAveragePrice = state.cumulativePrice / (currentTime - (state.lastUpdateTime - timeElapsed + timeElapsed));
            }

            // Update state
            state.lastUpdateTime = currentTime;
            state.lastPrice = currentPrice;
            state.observationCount++;
        }
    }

    /**
     * @dev Gets current TWAP price
     */
    function getTWAP(TWAPState storage state, uint256 currentTime) internal view returns (uint256) {
        unchecked {
            if (state.observationCount == 0) return 0;

            uint256 timeElapsed = currentTime - state.lastUpdateTime;
            if (timeElapsed == 0) return state.timeWeightedAveragePrice;

            uint256 currentCumulative = state.cumulativePrice + (state.lastPrice * timeElapsed);
            uint256 totalTime = currentTime - (state.lastUpdateTime - timeElapsed + timeElapsed);

            return totalTime > 0 ? currentCumulative / totalTime : state.timeWeightedAveragePrice;
        }
    }

    /**
     * @dev Calculates price impact for a trade
     */
    function calculatePriceImpact(
        uint256 amountIn,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256) {
        unchecked {
            if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;

            uint256 priceBefore = reserveOut.mulDiv(1e18, reserveIn);
            uint256 priceAfter = (reserveOut - amountOut).mulDiv(1e18, reserveIn + amountIn);

            if (priceAfter >= priceBefore) return 0;

            return ((priceBefore - priceAfter) * 1e18) / priceBefore;
        }
    }

    /**
     * @dev Calculates slippage-adjusted amount out
     */
    function calculateSlippageAdjustedAmount(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 maxSlippage // in basis points (1/10000)
    ) internal pure returns (uint256) {
        unchecked {
            if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;

            uint256 amountOut = amountIn.mulDiv(reserveOut, reserveIn + amountIn);
            uint256 slippageAdjustment = (amountOut * maxSlippage) / 10000;

            return amountOut - slippageAdjustment;
        }
    }

    /**
     * @dev Validates price against TWAP to detect manipulation
     */
    function validatePriceAgainstTWAP(
        uint256 currentPrice,
        uint256 twapPrice,
        uint256 maxDeviation // in basis points
    ) internal pure returns (bool) {
        unchecked {
            if (twapPrice == 0) return true;

            uint256 deviation = currentPrice > twapPrice
                ? ((currentPrice - twapPrice) * 10000) / twapPrice
                : ((twapPrice - currentPrice) * 10000) / currentPrice;

            return deviation <= maxDeviation;
        }
    }

    /**
     * @dev Calculates geometric mean price
     */
    function geometricMean(uint256[] memory prices) internal pure returns (uint256) {
        unchecked {
            if (prices.length == 0) return 0;
            if (prices.length == 1) return prices[0];

            uint256 product = 1e18; // Start with 1e18 for precision
            for (uint256 i = 0; i < prices.length; i++) {
                if (prices[i] == 0) return 0;
                product = product.mulDiv(prices[i], 1e18);
            }

            return BabylonianSqrt.sqrt(product);
        }
    }

    /**
     * @dev Calculates weighted average price
     */
    function weightedAveragePrice(
        uint256[] memory prices,
        uint256[] memory weights
    ) internal pure returns (uint256) {
        unchecked {
            require(prices.length == weights.length, "PriceLib: array length mismatch");

            uint256 totalWeight = 0;
            uint256 weightedSum = 0;

            for (uint256 i = 0; i < prices.length; i++) {
                totalWeight += weights[i];
                weightedSum += prices[i] * weights[i];
            }

            return totalWeight > 0 ? weightedSum / totalWeight : 0;
        }
    }

    /**
     * @dev Calculates price volatility using standard deviation
     */
    function calculateVolatility(uint256[] memory prices) internal pure returns (uint256) {
        unchecked {
            if (prices.length < 2) return 0;

            uint256 sum = 0;
            for (uint256 i = 0; i < prices.length; i++) {
                sum += prices[i];
            }
            uint256 mean = sum / prices.length;

            uint256 variance = 0;
            for (uint256 i = 0; i < prices.length; i++) {
                uint256 diff = prices[i] > mean ? prices[i] - mean : mean - prices[i];
                variance += diff * diff;
            }

            return BabylonianSqrt.sqrt(variance / prices.length);
        }
    }

    /**
     * @dev Converts price from one decimal to another
     */
    function convertPriceDecimals(
        uint256 price,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        unchecked {
            if (fromDecimals == toDecimals) return price;

            if (fromDecimals > toDecimals) {
                return price / (10 ** (fromDecimals - toDecimals));
            } else {
                return price * (10 ** (toDecimals - fromDecimals));
            }
        }
    }

    /**
     * @dev Calculates price correlation between two assets
     */
    function calculatePriceCorrelation(
        uint256[] memory pricesA,
        uint256[] memory pricesB
    ) internal pure returns (int256) {
        unchecked {
            require(pricesA.length == pricesB.length && pricesA.length > 1, "PriceLib: invalid input lengths");

            uint256 n = pricesA.length;

            // Calculate means
            uint256 sumA = 0;
            uint256 sumB = 0;
            for (uint256 i = 0; i < n; i++) {
                sumA += pricesA[i];
                sumB += pricesB[i];
            }
            uint256 meanA = sumA / n;
            uint256 meanB = sumB / n;

            // Calculate covariance and variances
            uint256 covariance = 0;
            uint256 varianceA = 0;
            uint256 varianceB = 0;

            for (uint256 i = 0; i < n; i++) {
                int256 diffA = int256(pricesA[i]) - int256(meanA);
                int256 diffB = int256(pricesB[i]) - int256(meanB);

                covariance += uint256(diffA * diffB);
                varianceA += uint256(diffA * diffA);
                varianceB += uint256(diffB * diffB);
            }

            if (varianceA == 0 || varianceB == 0) return 0;

            uint256 stdDevA = BabylonianSqrt.sqrt(varianceA / n);
            uint256 stdDevB = BabylonianSqrt.sqrt(varianceB / n);

            if (stdDevA == 0 || stdDevB == 0) return 0;

            // Correlation = covariance / (stdDevA * stdDevB)
            return int256((covariance / n) * 1e18) / int256(stdDevA * stdDevB);
        }
    }
}
