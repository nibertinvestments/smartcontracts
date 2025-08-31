// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MathLib.sol";
import "./PriceLib.sol";

/**
 * @title TWAPLib
 * @dev Gas-optimized Time-Weighted Average Price calculations
 * @notice Handles TWAP observations, updates, and price manipulation detection
 */
library TWAPLib {
    using FixedPointMath for uint256;

    struct TWAPObservation {
        uint32 timestamp;
        uint256 price;
        uint256 cumulativePrice;
    }

    struct TWAPState {
        uint32 lastUpdateTime;
        uint256 lastPrice;
        uint256 cumulativePrice;
        uint32 observationCount;
        uint256 timeWeightedAveragePrice;
        uint32 observationPeriod;
        uint32 maxObservationAge;
    }

    struct TWAPConfig {
        uint32 observationPeriod;    // Time between observations
        uint32 maxObservationAge;    // Maximum age for valid observations
        uint256 maxPriceDeviation;   // Maximum price deviation allowed
        uint32 minObservations;      // Minimum observations for valid TWAP
    }

    /**
     * @dev Initializes TWAP state
     */
    function initializeTWAP(
        TWAPState storage state,
        TWAPConfig memory config,
        uint256 initialPrice,
        uint32 currentTime
    ) internal {
        state.lastUpdateTime = currentTime;
        state.lastPrice = initialPrice;
        state.cumulativePrice = initialPrice;
        state.observationCount = 1;
        state.timeWeightedAveragePrice = initialPrice;
        state.observationPeriod = config.observationPeriod;
        state.maxObservationAge = config.maxObservationAge;
    }

    /**
     * @dev Updates TWAP with new price observation
     */
    function updateTWAP(
        TWAPState storage state,
        uint256 currentPrice,
        uint32 currentTime
    ) internal {
        unchecked {
            uint32 timeElapsed = currentTime - state.lastUpdateTime;

            if (timeElapsed == 0) return; // Same timestamp, skip

            // Update cumulative price
            state.cumulativePrice += state.lastPrice * timeElapsed;

            // Update TWAP
            uint32 totalTime = currentTime - (state.lastUpdateTime - timeElapsed + timeElapsed);
            if (totalTime > 0) {
                state.timeWeightedAveragePrice = state.cumulativePrice / totalTime;
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
    function getTWAP(TWAPState storage state, uint32 currentTime) internal view returns (uint256) {
        unchecked {
            if (state.observationCount == 0) return 0;

            uint32 timeElapsed = currentTime - state.lastUpdateTime;
            if (timeElapsed == 0) return state.timeWeightedAveragePrice;

            uint256 currentCumulative = state.cumulativePrice + (state.lastPrice * timeElapsed);
            uint32 totalTime = currentTime - (state.lastUpdateTime - timeElapsed + timeElapsed);

            return totalTime > 0 ? currentCumulative / totalTime : state.timeWeightedAveragePrice;
        }
    }

    /**
     * @dev Gets TWAP price for specific time window
     */
    function getTWAPForWindow(
        TWAPState storage state,
        uint32 startTime,
        uint32 endTime,
        uint32 currentTime
    ) internal view returns (uint256) {
        unchecked {
            if (startTime >= endTime || state.observationCount == 0) return 0;

            uint32 effectiveEndTime = endTime > currentTime ? currentTime : endTime;
            uint32 windowDuration = effectiveEndTime - startTime;

            if (windowDuration == 0) return state.timeWeightedAveragePrice;

            // Calculate cumulative price for the window
            uint256 windowCumulative = 0;
            uint32 lastTime = startTime;

            // This is a simplified calculation - in practice, you'd need historical observations
            if (state.lastUpdateTime >= startTime && state.lastUpdateTime <= effectiveEndTime) {
                uint32 observationTime = state.lastUpdateTime > startTime ? state.lastUpdateTime : startTime;
                uint32 duration = effectiveEndTime - observationTime;
                windowCumulative += state.lastPrice * duration;
            }

            return windowDuration > 0 ? windowCumulative / windowDuration : 0;
        }
    }

    /**
     * @dev Validates price against TWAP
     */
    function validatePriceAgainstTWAP(
        TWAPState storage state,
        uint256 currentPrice,
        uint32 currentTime,
        uint256 maxDeviation
    ) internal view returns (bool) {
        unchecked {
            uint256 twapPrice = getTWAP(state, currentTime);
            if (twapPrice == 0) return true;

            uint256 deviation = currentPrice > twapPrice
                ? ((currentPrice - twapPrice) * 10000) / twapPrice
                : ((twapPrice - currentPrice) * 10000) / currentPrice;

            return deviation <= maxDeviation;
        }
    }

    /**
     * @dev Checks if TWAP is stale
     */
    function isTWAPStale(
        TWAPState storage state,
        uint32 currentTime
    ) internal view returns (bool) {
        unchecked {
            return (currentTime - state.lastUpdateTime) > state.maxObservationAge;
        }
    }

    /**
     * @dev Gets TWAP confidence interval
     */
    function getTWAPConfidence(
        TWAPState storage state,
        uint32 currentTime,
        uint256[] memory recentPrices
    ) internal view returns (uint256 lowerBound, uint256 upperBound) {
        unchecked {
            uint256 twapPrice = getTWAP(state, currentTime);
            if (twapPrice == 0 || recentPrices.length == 0) {
                return (0, 0);
            }

            uint256 volatility = PriceLib.calculateVolatility(recentPrices);
            uint256 confidenceInterval = (volatility * 2) / 100; // 2 standard deviations

            lowerBound = twapPrice > confidenceInterval ? twapPrice - confidenceInterval : 0;
            upperBound = twapPrice + confidenceInterval;
        }
    }

    /**
     * @dev Calculates TWAP-based price impact
     */
    function calculateTWAPPriceImpact(
        TWAPState storage state,
        uint256 amountIn,
        uint256 amountOut,
        uint32 currentTime
    ) internal view returns (uint256) {
        unchecked {
            uint256 twapPrice = getTWAP(state, currentTime);
            if (twapPrice == 0 || amountIn == 0) return 0;

            uint256 executionPrice = amountOut.mulDiv(1e18, amountIn);
            if (executionPrice >= twapPrice) return 0;

            return ((twapPrice - executionPrice) * 1e18) / twapPrice;
        }
    }

    /**
     * @dev Gets TWAP statistics
     */
    function getTWAPStats(
        TWAPState storage state,
        uint32 currentTime
    ) internal view returns (
        uint256 twapPrice,
        uint32 age,
        uint32 observationCount,
        bool isStale
    ) {
        unchecked {
            twapPrice = getTWAP(state, currentTime);
            age = currentTime - state.lastUpdateTime;
            observationCount = state.observationCount;
            isStale = isTWAPStale(state, currentTime);
        }
    }

    /**
     * @dev Resets TWAP state
     */
    function resetTWAP(
        TWAPState storage state,
        uint256 resetPrice,
        uint32 currentTime
    ) internal {
        state.lastUpdateTime = currentTime;
        state.lastPrice = resetPrice;
        state.cumulativePrice = resetPrice;
        state.observationCount = 1;
        state.timeWeightedAveragePrice = resetPrice;
    }

    /**
     * @dev Merges two TWAP states
     */
    function mergeTWAPs(
        TWAPState storage state1,
        TWAPState storage state2,
        uint32 currentTime
    ) internal view returns (uint256 mergedTWAP) {
        unchecked {
            uint256 twap1 = getTWAP(state1, currentTime);
            uint256 twap2 = getTWAP(state2, currentTime);

            if (twap1 == 0) return twap2;
            if (twap2 == 0) return twap1;

            // Weighted average based on observation counts
            uint256 totalObservations = state1.observationCount + state2.observationCount;
            if (totalObservations == 0) return 0;

            return (twap1 * state1.observationCount + twap2 * state2.observationCount) / totalObservations;
        }
    }

    /**
     * @dev Calculates TWAP efficiency score
     */
    function calculateTWAPEfficiency(
        TWAPState storage state,
        uint32 currentTime,
        uint32 expectedPeriod
    ) internal view returns (uint256) {
        unchecked {
            if (state.observationCount == 0) return 0;

            uint32 actualPeriod = currentTime - state.lastUpdateTime;
            if (actualPeriod >= expectedPeriod) return 10000; // 100%

            return (actualPeriod * 10000) / expectedPeriod;
        }
    }

    /**
     * @dev Validates TWAP configuration
     */
    function validateTWAPConfig(TWAPConfig memory config) internal pure returns (bool) {
        return config.observationPeriod > 0 &&
               config.maxObservationAge > config.observationPeriod &&
               config.maxPriceDeviation <= 10000 && // Max 100%
               config.minObservations > 0;
    }

    /**
     * @dev Gets TWAP health score
     */
    function getTWAPHealthScore(
        TWAPState storage state,
        uint32 currentTime,
        TWAPConfig memory config
    ) internal view returns (uint256) {
        unchecked {
            if (state.observationCount < config.minObservations) return 0;

            uint256 freshnessScore = 10000 - ((currentTime - state.lastUpdateTime) * 10000) / config.maxObservationAge;
            uint256 observationScore = state.observationCount >= config.minObservations ? 10000 : 0;

            return (freshnessScore + observationScore) / 2;
        }
    }
}
