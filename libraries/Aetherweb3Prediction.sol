// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3Prediction
 * @dev Prediction markets and oracle utility library
 * @notice Provides prediction market calculations, oracle data aggregation, and market resolution utilities
 */
library Aetherweb3Prediction {
    using Aetherweb3Math for uint256;

    // Prediction market information
    struct PredictionMarket {
        uint256 marketId;         // Unique market ID
        string question;          // Market question
        bytes32 questionId;       // Question identifier hash
        uint256 endTime;          // Market end time
        uint256 resolutionTime;   // Resolution time
        MarketStatus status;      // Market status
        Outcome[] outcomes;       // Possible outcomes
        uint256 totalLiquidity;   // Total liquidity
        uint256 totalVolume;      // Total trading volume
        address oracle;           // Oracle address
        uint256 fee;              // Market fee
        bool isResolved;         // Resolution status
        uint256 winningOutcome;   // Winning outcome index
    }

    // Market status enumeration
    enum MarketStatus {
        ACTIVE,
        PAUSED,
        RESOLVED,
        CANCELLED,
        SETTLED
    }

    // Market outcome information
    struct Outcome {
        string name;              // Outcome name
        uint256 probability;      // Current probability
        uint256 shares;           // Total shares
        uint256 price;            // Current price per share
        uint256 liquidity;        // Outcome liquidity
    }

    // Prediction position
    struct PredictionPosition {
        uint256 marketId;         // Market ID
        address user;             // Position owner
        uint256 outcomeIndex;     // Chosen outcome
        uint256 shares;           // Number of shares
        uint256 entryPrice;       // Entry price
        uint256 currentValue;     // Current position value
        uint256 potentialPayout;  // Potential payout
        bool claimed;             // Payout claimed status
    }

    // Oracle data feed
    struct OracleFeed {
        address oracleAddress;    // Oracle contract address
        bytes32 feedId;           // Feed identifier
        uint256 decimals;         // Price decimals
        uint256 heartbeat;        // Update frequency
        uint256 lastUpdate;       // Last update timestamp
        uint256 price;            // Current price
        uint256 confidence;       // Price confidence interval
        bool isActive;           // Feed active status
    }

    // Market resolution data
    struct MarketResolution {
        uint256 marketId;         // Market ID
        uint256 winningOutcome;   // Winning outcome
        uint256 resolutionPrice;  // Resolution price
        uint256 totalPayout;      // Total payout amount
        uint256 oracleFee;        // Oracle fee
        bytes32 evidenceHash;     // Evidence hash
        bool appealed;            // Appeal status
    }

    // Prediction market statistics
    struct MarketStats {
        uint256 totalMarkets;     // Total markets created
        uint256 activeMarkets;    // Active markets
        uint256 resolvedMarkets;  // Resolved markets
        uint256 totalVolume;      // Total volume
        uint256 totalLiquidity;   // Total liquidity
        uint256 averageAccuracy;  // Average prediction accuracy
        uint256 participationRate; // User participation rate
    }

    /**
     * @dev Calculates outcome probabilities using LMSR (Logarithmic Market Scoring Rule)
     * @param outcomes Array of market outcomes
     * @param liquidity Liquidity parameter
     * @return probabilities Calculated probabilities for each outcome
     */
    function calculateLMSRProbabilities(
        Outcome[] memory outcomes,
        uint256 liquidity
    ) internal pure returns (uint256[] memory probabilities) {
        probabilities = new uint256[](outcomes.length);
        if (outcomes.length == 0) return probabilities;

        uint256 totalExponent = 0;

        // Calculate exp(shares/liquidity) for each outcome
        for (uint256 i = 0; i < outcomes.length; i++) {
            if (outcomes[i].shares == 0) {
                probabilities[i] = Aetherweb3Math.WAD / outcomes.length; // Equal probability
                continue;
            }

            uint256 exponent = outcomes[i].shares / liquidity;
            // Simplified exp calculation (in practice, use more precise method)
            uint256 expValue = Aetherweb3Math.WAD + exponent; // Approximation
            totalExponent += expValue;
        }

        // Calculate probabilities
        for (uint256 i = 0; i < outcomes.length; i++) {
            if (totalExponent == 0) {
                probabilities[i] = Aetherweb3Math.WAD / outcomes.length;
            } else {
                uint256 exponent = outcomes[i].shares / liquidity;
                uint256 expValue = Aetherweb3Math.WAD + exponent;
                probabilities[i] = expValue * Aetherweb3Math.WAD / totalExponent;
            }
        }
    }

    /**
     * @dev Calculates prediction market prices
     * @param outcomes Array of market outcomes
     * @param liquidity Market liquidity
     * @return prices Calculated prices for each outcome
     */
    function calculateMarketPrices(
        Outcome[] memory outcomes,
        uint256 liquidity
    ) internal pure returns (uint256[] memory prices) {
        uint256[] memory probabilities = calculateLMSRProbabilities(outcomes, liquidity);
        prices = new uint256[](outcomes.length);

        for (uint256 i = 0; i < outcomes.length; i++) {
            prices[i] = probabilities[i];
        }
    }

    /**
     * @dev Calculates cost to buy shares in prediction market
     * @param outcomeIndex Outcome to buy
     * @param shares Number of shares to buy
     * @param outcomes Current outcomes
     * @param liquidity Market liquidity
     * @return cost Cost to buy shares
     */
    function calculateBuyCost(
        uint256 outcomeIndex,
        uint256 shares,
        Outcome[] memory outcomes,
        uint256 liquidity
    ) internal pure returns (uint256 cost) {
        if (outcomeIndex >= outcomes.length) return 0;

        // LMSR cost calculation
        uint256 currentShares = outcomes[outcomeIndex].shares;
        uint256 newShares = currentShares + shares;

        // Simplified LMSR cost (b * ln(exp(q/b) + exp((q+shares)/b)) - b * ln(exp(q/b)))
        // This is a simplified version for demonstration
        uint256 costIncrease = shares * liquidity; // Approximation
        cost = costIncrease;
    }

    /**
     * @dev Calculates payout for prediction position
     * @param position Prediction position
     * @param winningOutcome Winning outcome index
     * @param totalWinningShares Total shares for winning outcome
     * @param marketLiquidity Total market liquidity
     * @return payout Payout amount
     */
    function calculatePositionPayout(
        PredictionPosition memory position,
        uint256 winningOutcome,
        uint256 totalWinningShares,
        uint256 marketLiquidity
    ) internal pure returns (uint256 payout) {
        if (position.outcomeIndex != winningOutcome) return 0;
        if (totalWinningShares == 0) return 0;

        // Proportional payout based on shares owned
        uint256 totalPayoutPool = marketLiquidity * 2; // Simplified
        payout = totalPayoutPool * position.shares / totalWinningShares;
    }

    /**
     * @dev Aggregates oracle price feeds
     * @param feeds Array of oracle feeds
     * @param weights Array of feed weights
     * @return aggregatedPrice Aggregated price
     * @return confidence Aggregated confidence
     */
    function aggregateOraclePrices(
        OracleFeed[] memory feeds,
        uint256[] memory weights
    ) internal pure returns (uint256 aggregatedPrice, uint256 confidence) {
        require(feeds.length == weights.length, "Feeds and weights length mismatch");

        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        uint256 totalConfidence = 0;

        for (uint256 i = 0; i < feeds.length; i++) {
            if (!feeds[i].isActive) continue;

            totalWeight += weights[i];
            weightedSum += feeds[i].price * weights[i];
            totalConfidence += feeds[i].confidence;
        }

        if (totalWeight == 0) return (0, 0);

        aggregatedPrice = weightedSum / totalWeight;
        confidence = totalConfidence / feeds.length;
    }

    /**
     * @dev Validates oracle feed data
     * @param feed Oracle feed
     * @param maxAge Maximum age for price data
     * @param currentTime Current timestamp
     * @return isValid True if feed data is valid
     */
    function validateOracleFeed(
        OracleFeed memory feed,
        uint256 maxAge,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (!feed.isActive) return false;
        if (feed.price == 0) return false;
        if (currentTime - feed.lastUpdate > maxAge) return false;
        if (feed.confidence == 0) return false;
        return true;
    }

    /**
     * @dev Calculates market resolution confidence
     * @param oracleFeeds Array of oracle feeds
     * @param marketData Market data
     * @return confidence Resolution confidence score
     */
    function calculateResolutionConfidence(
        OracleFeed[] memory oracleFeeds,
        bytes memory marketData
    ) internal pure returns (uint256 confidence) {
        uint256 validFeeds = 0;
        uint256 totalConfidence = 0;

        for (uint256 i = 0; i < oracleFeeds.length; i++) {
            if (oracleFeeds[i].isActive) {
                validFeeds++;
                totalConfidence += oracleFeeds[i].confidence;
            }
        }

        if (validFeeds == 0) return 0;

        confidence = totalConfidence / validFeeds;
    }

    /**
     * @dev Calculates prediction market efficiency
     * @param market Prediction market
     * @param actualOutcome Actual outcome
     * @return efficiency Market efficiency score
     */
    function calculateMarketEfficiency(
        PredictionMarket memory market,
        uint256 actualOutcome
    ) internal pure returns (uint256 efficiency) {
        if (!market.isResolved || market.outcomes.length == 0) return 0;

        uint256 predictedProbability = market.outcomes[actualOutcome].probability;
        uint256 actualProbability = actualOutcome == market.winningOutcome ?
            Aetherweb3Math.WAD : 0;

        // Efficiency based on prediction accuracy
        uint256 accuracy = Aetherweb3Math.WAD - (
            predictedProbability > actualProbability ?
            predictedProbability - actualProbability :
            actualProbability - predictedProbability
        );

        efficiency = accuracy;
    }

    /**
     * @dev Calculates market maker profit/loss
     * @param initialLiquidity Initial liquidity provided
     * @param finalLiquidity Final liquidity
     * @param totalVolume Total trading volume
     * @param fee Market fee
     * @return pnl Profit/loss amount
     */
    function calculateMarketMakerPnL(
        uint256 initialLiquidity,
        uint256 finalLiquidity,
        uint256 totalVolume,
        uint256 fee
    ) internal pure returns (int256 pnl) {
        uint256 feesEarned = totalVolume.wmul(fee);
        uint256 liquidityChange = finalLiquidity > initialLiquidity ?
            finalLiquidity - initialLiquidity :
            initialLiquidity - finalLiquidity;

        if (finalLiquidity >= initialLiquidity) {
            pnl = int256(feesEarned + liquidityChange);
        } else {
            pnl = int256(feesEarned) - int256(liquidityChange);
        }
    }

    /**
     * @dev Validates prediction market parameters
     * @param market Prediction market
     * @param currentTime Current timestamp
     * @return isValid True if market is valid
     */
    function validatePredictionMarket(
        PredictionMarket memory market,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (bytes(market.question).length == 0) return false;
        if (market.endTime <= currentTime) return false;
        if (market.outcomes.length < 2) return false;
        if (market.oracle == address(0)) return false;
        if (market.liquidity == 0) return false;
        return true;
    }

    /**
     * @dev Calculates market volatility
     * @param prices Array of historical prices
     * @return volatility Volatility index
     */
    function calculateMarketVolatility(
        uint256[] memory prices
    ) internal pure returns (uint256 volatility) {
        if (prices.length < 2) return 0;

        uint256 sum = 0;
        uint256 mean = 0;

        // Calculate mean
        for (uint256 i = 0; i < prices.length; i++) {
            sum += prices[i];
        }
        mean = sum / prices.length;

        // Calculate variance
        uint256 variance = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            uint256 diff = prices[i] > mean ? prices[i] - mean : mean - prices[i];
            variance += diff * diff;
        }
        variance = variance / prices.length;

        // Volatility as square root of variance (simplified)
        volatility = Aetherweb3Math.sqrt(variance);
    }

    /**
     * @dev Calculates prediction accuracy
     * @param predictions Array of predicted outcomes
     * @param actualOutcomes Array of actual outcomes
     * @return accuracy Prediction accuracy percentage
     */
    function calculatePredictionAccuracy(
        uint256[] memory predictions,
        uint256[] memory actualOutcomes
    ) internal pure returns (uint256 accuracy) {
        require(
            predictions.length == actualOutcomes.length,
            "Predictions and outcomes length mismatch"
        );

        if (predictions.length == 0) return 0;

        uint256 correct = 0;
        for (uint256 i = 0; i < predictions.length; i++) {
            if (predictions[i] == actualOutcomes[i]) {
                correct++;
            }
        }

        accuracy = correct * Aetherweb3Math.WAD / predictions.length;
    }

    /**
     * @dev Calculates oracle reputation score
     * @param successfulResolutions Number of successful resolutions
     * @param totalResolutions Total resolutions
     * @param averageLatency Average resolution latency
     * @param maxLatency Maximum acceptable latency
     * @return reputation Reputation score
     */
    function calculateOracleReputation(
        uint256 successfulResolutions,
        uint256 totalResolutions,
        uint256 averageLatency,
        uint256 maxLatency
    ) internal pure returns (uint256 reputation) {
        if (totalResolutions == 0) return 0;

        uint256 successRate = successfulResolutions * Aetherweb3Math.WAD / totalResolutions;
        uint256 latencyScore = averageLatency <= maxLatency ?
            Aetherweb3Math.WAD - (averageLatency * Aetherweb3Math.WAD / maxLatency) :
            0;

        reputation = (successRate + latencyScore) / 2;
    }

    /**
     * @dev Estimates market resolution time
     * @param market Prediction market
     * @param oracleLatency Oracle response latency
     * @param bufferTime Buffer time for processing
     * @return estimatedTime Estimated resolution time
     */
    function estimateResolutionTime(
        PredictionMarket memory market,
        uint256 oracleLatency,
        uint256 bufferTime
    ) internal pure returns (uint256 estimatedTime) {
        estimatedTime = market.endTime + oracleLatency + bufferTime;
    }

    /**
     * @dev Calculates market participation rate
     * @param uniqueParticipants Number of unique participants
     * @param totalPossibleParticipants Total possible participants
     * @return participationRate Participation rate percentage
     */
    function calculateParticipationRate(
        uint256 uniqueParticipants,
        uint256 totalPossibleParticipants
    ) internal pure returns (uint256 participationRate) {
        if (totalPossibleParticipants == 0) return 0;
        participationRate = uniqueParticipants * Aetherweb3Math.WAD / totalPossibleParticipants;
    }

    /**
     * @dev Validates market resolution
     * @param resolution Market resolution
     * @param market Prediction market
     * @return isValid True if resolution is valid
     */
    function validateMarketResolution(
        MarketResolution memory resolution,
        PredictionMarket memory market
    ) internal pure returns (bool isValid) {
        if (resolution.marketId != market.marketId) return false;
        if (resolution.winningOutcome >= market.outcomes.length) return false;
        if (resolution.resolutionPrice == 0) return false;
        return true;
    }

    /**
     * @dev Calculates market arbitrage opportunity
     * @param outcomes Array of market outcomes
     * @param externalPrices Array of external reference prices
     * @return arbitrageAmount Potential arbitrage amount
     */
    function calculateArbitrageOpportunity(
        Outcome[] memory outcomes,
        uint256[] memory externalPrices
    ) internal pure returns (uint256 arbitrageAmount) {
        require(
            outcomes.length == externalPrices.length,
            "Outcomes and prices length mismatch"
        );

        uint256 totalMarketProb = 0;
        uint256 totalExternalProb = 0;

        for (uint256 i = 0; i < outcomes.length; i++) {
            totalMarketProb += outcomes[i].probability;
            totalExternalProb += externalPrices[i];
        }

        // Arbitrage exists if probabilities don't sum to 1
        uint256 marketDeviation = totalMarketProb > Aetherweb3Math.WAD ?
            totalMarketProb - Aetherweb3Math.WAD :
            Aetherweb3Math.WAD - totalMarketProb;

        uint256 externalDeviation = totalExternalProb > Aetherweb3Math.WAD ?
            totalExternalProb - Aetherweb3Math.WAD :
            Aetherweb3Math.WAD - totalExternalProb;

        arbitrageAmount = (marketDeviation + externalDeviation) / 2;
    }
}
