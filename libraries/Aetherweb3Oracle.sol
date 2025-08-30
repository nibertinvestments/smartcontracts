// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";

/**
 * @title Aetherweb3Oracle
 * @dev Oracle utility library for price feeds and data aggregation
 * @notice Provides price calculations, data validation, and oracle management
 */
library Aetherweb3Oracle {
    using Aetherweb3Math for uint256;

    // Price data structure
    struct PriceData {
        uint256 price;        // Price in wad (18 decimals)
        uint256 timestamp;    // Timestamp of price update
        uint256 confidence;   // Confidence interval in wad
        address source;       // Price source address
    }

    // Oracle source information
    struct OracleSource {
        address oracleAddress;    // Oracle contract address
        uint256 weight;          // Weight in price calculation
        uint256 lastUpdateTime;  // Last update timestamp
        bool isActive;          // Whether source is active
        uint256 deviationThreshold; // Max deviation allowed
    }

    // Aggregated price information
    struct AggregatedPrice {
        uint256 price;           // Weighted average price
        uint256 totalWeight;     // Total weight of sources
        uint256 lastUpdateTime;  // Last aggregation time
        uint256 standardDeviation; // Price standard deviation
        uint256 confidence;      // Overall confidence level
    }

    /**
     * @dev Calculates weighted average price from multiple sources
     * @param prices Array of price data
     * @param weights Array of weights for each price
     * @return aggregatedPrice Weighted average price
     */
    function calculateWeightedAverage(
        PriceData[] memory prices,
        uint256[] memory weights
    ) internal pure returns (uint256 aggregatedPrice) {
        require(prices.length == weights.length, "Aetherweb3Oracle: array length mismatch");
        require(prices.length > 0, "Aetherweb3Oracle: no prices provided");

        uint256 totalWeight = 0;
        uint256 weightedSum = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            require(weights[i] > 0, "Aetherweb3Oracle: invalid weight");
            require(prices[i].price > 0, "Aetherweb3Oracle: invalid price");

            weightedSum = weightedSum + prices[i].price.wmul(weights[i]);
            totalWeight = totalWeight + weights[i];
        }

        require(totalWeight > 0, "Aetherweb3Oracle: zero total weight");
        aggregatedPrice = weightedSum.wdiv(totalWeight);
    }

    /**
     * @dev Calculates median price from array of prices
     * @param prices Array of price data
     * @return medianPrice Median price value
     */
    function calculateMedian(PriceData[] memory prices) internal pure returns (uint256 medianPrice) {
        require(prices.length > 0, "Aetherweb3Oracle: no prices provided");

        uint256[] memory priceValues = new uint256[](prices.length);
        for (uint256 i = 0; i < prices.length; i++) {
            priceValues[i] = prices[i].price;
        }

        // Simple bubble sort for median calculation
        for (uint256 i = 0; i < priceValues.length - 1; i++) {
            for (uint256 j = 0; j < priceValues.length - i - 1; j++) {
                if (priceValues[j] > priceValues[j + 1]) {
                    (priceValues[j], priceValues[j + 1]) = (priceValues[j + 1], priceValues[j]);
                }
            }
        }

        uint256 mid = priceValues.length / 2;
        if (priceValues.length % 2 == 0) {
            medianPrice = (priceValues[mid - 1] + priceValues[mid]) / 2;
        } else {
            medianPrice = priceValues[mid];
        }
    }

    /**
     * @dev Calculates standard deviation of prices
     * @param prices Array of price data
     * @param mean Average price
     * @return standardDeviation Standard deviation of prices
     */
    function calculateStandardDeviation(
        PriceData[] memory prices,
        uint256 mean
    ) internal pure returns (uint256 standardDeviation) {
        if (prices.length <= 1) return 0;

        uint256 sumSquaredDifferences = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            uint256 diff = prices[i].price > mean ?
                prices[i].price - mean :
                mean - prices[i].price;
            sumSquaredDifferences = sumSquaredDifferences + diff.wmul(diff);
        }

        uint256 variance = sumSquaredDifferences / (prices.length - 1);
        standardDeviation = Aetherweb3Math.sqrt(variance);
    }

    /**
     * @dev Validates price data freshness
     * @param priceData Price data to validate
     * @param maxAge Maximum age in seconds
     * @param currentTime Current timestamp
     * @return isFresh True if price is fresh
     */
    function isPriceFresh(
        PriceData memory priceData,
        uint256 maxAge,
        uint256 currentTime
    ) internal pure returns (bool isFresh) {
        return (currentTime - priceData.timestamp) <= maxAge;
    }

    /**
     * @dev Validates price deviation from reference price
     * @param price Price to validate
     * @param referencePrice Reference price
     * @param maxDeviation Maximum allowed deviation in wad
     * @return isValid True if price is within deviation limits
     */
    function validatePriceDeviation(
        uint256 price,
        uint256 referencePrice,
        uint256 maxDeviation
    ) internal pure returns (bool isValid) {
        if (referencePrice == 0) return false;

        uint256 deviation = price > referencePrice ?
            ((price - referencePrice) * Aetherweb3Math.WAD) / referencePrice :
            ((referencePrice - price) * Aetherweb3Math.WAD) / price;

        return deviation <= maxDeviation;
    }

    /**
     * @dev Calculates confidence interval for aggregated price
     * @param standardDeviation Standard deviation of prices
     * @param sampleSize Number of price sources
     * @param confidenceLevel Confidence level in wad (e.g., 0.95 * WAD)
     * @return confidenceInterval Confidence interval
     */
    function calculateConfidenceInterval(
        uint256 standardDeviation,
        uint256 sampleSize,
        uint256 confidenceLevel
    ) internal pure returns (uint256 confidenceInterval) {
        if (sampleSize <= 1) return 0;

        // Simplified t-distribution approximation
        uint256 tValue;
        if (sampleSize >= 30) {
            tValue = Aetherweb3Math.WAD * 196 / 100; // ~1.96 for 95% confidence
        } else if (sampleSize >= 10) {
            tValue = Aetherweb3Math.WAD * 228 / 100; // ~2.28 for small samples
        } else {
            tValue = Aetherweb3Math.WAD * 300 / 100; // Conservative estimate
        }

        uint256 adjustedTValue = confidenceLevel.wmul(tValue) / Aetherweb3Math.WAD;
        confidenceInterval = standardDeviation.wmul(adjustedTValue) / Aetherweb3Math.sqrt(sampleSize);
    }

    /**
     * @dev Aggregates prices from multiple sources
     * @param prices Array of price data
     * @param sources Array of oracle sources
     * @param maxDeviation Maximum allowed deviation
     * @param maxAge Maximum price age
     * @param currentTime Current timestamp
     * @return aggregatedPrice Aggregated price information
     */
    function aggregatePrices(
        PriceData[] memory prices,
        OracleSource[] memory sources,
        uint256 maxDeviation,
        uint256 maxAge,
        uint256 currentTime
    ) internal pure returns (AggregatedPrice memory aggregatedPrice) {
        require(prices.length == sources.length, "Aetherweb3Oracle: array length mismatch");

        uint256[] memory validWeights = new uint256[](prices.length);
        PriceData[] memory validPrices = new PriceData[](prices.length);
        uint256 validCount = 0;

        // Filter valid prices
        for (uint256 i = 0; i < prices.length; i++) {
            if (!sources[i].isActive) continue;
            if (!isPriceFresh(prices[i], maxAge, currentTime)) continue;

            validPrices[validCount] = prices[i];
            validWeights[validCount] = sources[i].weight;
            validCount++;
        }

        require(validCount > 0, "Aetherweb3Oracle: no valid prices");

        // Resize arrays
        assembly {
            mstore(validPrices, validCount)
            mstore(validWeights, validCount)
        }

        // Calculate aggregated price
        uint256 weightedAverage = calculateWeightedAverage(validPrices, validWeights);
        uint256 stdDev = calculateStandardDeviation(validPrices, weightedAverage);
        uint256 confidence = calculateConfidenceInterval(stdDev, validCount, Aetherweb3Math.WAD * 95 / 100);

        aggregatedPrice = AggregatedPrice({
            price: weightedAverage,
            totalWeight: validCount,
            lastUpdateTime: currentTime,
            standardDeviation: stdDev,
            confidence: confidence
        });
    }

    /**
     * @dev Converts price to different decimal precision
     * @param price Price in wad (18 decimals)
     * @param fromDecimals Source decimals
     * @param toDecimals Target decimals
     * @return convertedPrice Converted price
     */
    function convertPriceDecimals(
        uint256 price,
        uint256 fromDecimals,
        uint256 toDecimals
    ) internal pure returns (uint256 convertedPrice) {
        if (fromDecimals == toDecimals) return price;

        if (fromDecimals > toDecimals) {
            uint256 decimalDiff = fromDecimals - toDecimals;
            convertedPrice = price / (10 ** decimalDiff);
        } else {
            uint256 decimalDiff = toDecimals - fromDecimals;
            convertedPrice = price * (10 ** decimalDiff);
        }
    }

    /**
     * @dev Calculates price volatility
     * @param prices Array of historical prices
     * @param timePeriods Array of time periods for each price
     * @return volatility Price volatility in wad
     */
    function calculateVolatility(
        uint256[] memory prices,
        uint256[] memory timePeriods
    ) internal pure returns (uint256 volatility) {
        require(prices.length == timePeriods.length, "Aetherweb3Oracle: array length mismatch");
        require(prices.length >= 2, "Aetherweb3Oracle: insufficient data");

        uint256 sumReturns = 0;
        uint256 sumSquaredReturns = 0;

        for (uint256 i = 1; i < prices.length; i++) {
            uint256 priceReturn = prices[i].wdiv(prices[i - 1]);
            uint256 logReturn = Aetherweb3Math.WAD; // Simplified, should use ln(1 + r)

            sumReturns = sumReturns + logReturn;
            sumSquaredReturns = sumSquaredReturns + logReturn.wmul(logReturn);
        }

        uint256 meanReturn = sumReturns / (prices.length - 1);
        uint256 variance = (sumSquaredReturns / (prices.length - 1)) - meanReturn.wmul(meanReturn);
        volatility = Aetherweb3Math.sqrt(variance);
    }

    /**
     * @dev Calculates price correlation between two assets
     * @param pricesA Prices of asset A
     * @param pricesB Prices of asset B
     * @return correlation Correlation coefficient in wad
     */
    function calculateCorrelation(
        uint256[] memory pricesA,
        uint256[] memory pricesB
    ) internal pure returns (uint256 correlation) {
        require(pricesA.length == pricesB.length, "Aetherweb3Oracle: array length mismatch");
        require(pricesA.length >= 2, "Aetherweb3Oracle: insufficient data");

        uint256 meanA = 0;
        uint256 meanB = 0;

        // Calculate means
        for (uint256 i = 0; i < pricesA.length; i++) {
            meanA = meanA + pricesA[i];
            meanB = meanB + pricesB[i];
        }
        meanA = meanA / pricesA.length;
        meanB = meanB / pricesB.length;

        // Calculate covariance and variances
        uint256 covariance = 0;
        uint256 varianceA = 0;
        uint256 varianceB = 0;

        for (uint256 i = 0; i < pricesA.length; i++) {
            uint256 diffA = pricesA[i] > meanA ? pricesA[i] - meanA : meanA - pricesA[i];
            uint256 diffB = pricesB[i] > meanB ? pricesB[i] - meanB : meanB - pricesB[i];

            covariance = covariance + diffA.wmul(diffB);
            varianceA = varianceA + diffA.wmul(diffA);
            varianceB = varianceB + diffB.wmul(diffB);
        }

        uint256 stdDevA = Aetherweb3Math.sqrt(varianceA / pricesA.length);
        uint256 stdDevB = Aetherweb3Math.sqrt(varianceB / pricesB.length);

        if (stdDevA == 0 || stdDevB == 0) return 0;

        correlation = covariance / (pricesA.length * stdDevA * stdDevB);
    }

    /**
     * @dev Validates oracle source data
     * @param source Oracle source to validate
     * @param currentTime Current timestamp
     * @param maxUpdateAge Maximum allowed update age
     * @return isValid True if source is valid
     */
    function validateOracleSource(
        OracleSource memory source,
        uint256 currentTime,
        uint256 maxUpdateAge
    ) internal pure returns (bool isValid) {
        if (!source.isActive) return false;
        if (source.oracleAddress == address(0)) return false;
        if (source.weight == 0) return false;
        if ((currentTime - source.lastUpdateTime) > maxUpdateAge) return false;
        return true;
    }
}
