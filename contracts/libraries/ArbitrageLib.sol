// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MathLib.sol";
import "./PriceLib.sol";
import "./FeeLib.sol";

/**
 * @title ArbitrageLib
 * @dev Gas-optimized arbitrage calculation library
 * @notice Handles cross-DEX arbitrage opportunities, triangular arbitrage, and profit calculations
 */
library ArbitrageLib {
    using FixedPointMath for uint256;

    struct ArbitrageOpportunity {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 expectedProfit;
        uint256 gasCost;
        uint256 netProfit;
        uint256 priceImpact;
        bool isProfitable;
    }

    struct DEXPool {
        address dex;
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 fee; // in basis points
    }

    struct ArbitragePath {
        DEXPool[] pools;
        uint256[] amounts;
        uint256 totalProfit;
        uint256 totalGas;
        uint256 efficiency; // profit per gas
    }

    /**
     * @dev Calculates simple arbitrage between two DEX pools
     */
    function calculateSimpleArbitrage(
        DEXPool memory pool1,
        DEXPool memory pool2,
        uint256 amountIn,
        uint256 gasPrice,
        uint256 gasLimit
    ) internal pure returns (ArbitrageOpportunity memory) {
        unchecked {
            ArbitrageOpportunity memory opportunity;

            // Calculate price on pool1
            uint256 price1 = pool1.reserveB.mulDiv(1e18, pool1.reserveA);

            // Calculate price on pool2
            uint256 price2 = pool2.reserveB.mulDiv(1e18, pool2.reserveA);

            // Determine direction of arbitrage
            bool buyFromPool1 = price1 > price2;
            DEXPool memory buyPool = buyFromPool1 ? pool1 : pool2;
            DEXPool memory sellPool = buyFromPool1 ? pool2 : pool1;

            // Calculate amounts
            uint256 amountOutBuy = calculateAmountOut(amountIn, buyPool.reserveA, buyPool.reserveB, buyPool.fee);
            uint256 amountOutSell = calculateAmountOut(amountOutBuy, sellPool.reserveB, sellPool.reserveA, sellPool.fee);

            // Calculate profit
            opportunity.expectedProfit = amountOutSell > amountIn ? amountOutSell - amountIn : 0;

            // Calculate gas cost
            opportunity.gasCost = gasPrice * gasLimit;

            // Calculate net profit
            opportunity.netProfit = opportunity.expectedProfit > opportunity.gasCost
                ? opportunity.expectedProfit - opportunity.gasCost
                : 0;

            // Calculate price impact
            opportunity.priceImpact = PriceLib.calculatePriceImpact(
                amountIn,
                amountOutBuy,
                buyPool.reserveA,
                buyPool.reserveB
            );

            opportunity.isProfitable = opportunity.netProfit > 0;
            opportunity.amountIn = amountIn;

            return opportunity;
        }
    }

    /**
     * @dev Calculates triangular arbitrage opportunity
     */
    function calculateTriangularArbitrage(
        DEXPool memory pool1, // A/B
        DEXPool memory pool2, // B/C
        DEXPool memory pool3, // C/A
        uint256 amountIn,
        uint256 gasPrice,
        uint256 gasLimit
    ) internal pure returns (ArbitrageOpportunity memory) {
        unchecked {
            ArbitrageOpportunity memory opportunity;

            // Path: A -> B -> C -> A
            uint256 amountB = calculateAmountOut(amountIn, pool1.reserveA, pool1.reserveB, pool1.fee);
            uint256 amountC = calculateAmountOut(amountB, pool2.reserveB, pool2.reserveC, pool2.fee);
            uint256 amountA = calculateAmountOut(amountC, pool3.reserveC, pool3.reserveA, pool3.fee);

            // Calculate profit
            opportunity.expectedProfit = amountA > amountIn ? amountA - amountIn : 0;

            // Calculate gas cost (higher for triangular arbitrage)
            opportunity.gasCost = gasPrice * gasLimit * 3 / 2; // 1.5x gas for complexity

            // Calculate net profit
            opportunity.netProfit = opportunity.expectedProfit > opportunity.gasCost
                ? opportunity.expectedProfit - opportunity.gasCost
                : 0;

            opportunity.isProfitable = opportunity.netProfit > 0;
            opportunity.amountIn = amountIn;

            return opportunity;
        }
    }

    /**
     * @dev Calculates amount out for a trade
     */
    function calculateAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256) {
        unchecked {
            if (amountIn == 0 || reserveIn == 0 || reserveOut == 0) return 0;

            uint256 amountInWithFee = amountIn * (10000 - fee);
            uint256 numerator = amountInWithFee * reserveOut;
            uint256 denominator = (reserveIn * 10000) + amountInWithFee;

            return numerator / denominator;
        }
    }

    /**
     * @dev Finds best arbitrage path across multiple DEXes
     */
    function findBestArbitragePath(
        DEXPool[] memory pools,
        uint256 amountIn,
        uint256 gasPrice,
        uint256 gasLimit
    ) internal pure returns (ArbitragePath memory) {
        unchecked {
            ArbitragePath memory bestPath;
            bestPath.totalProfit = 0;

            // Check all pairs for simple arbitrage
            for (uint256 i = 0; i < pools.length; i++) {
                for (uint256 j = i + 1; j < pools.length; j++) {
                    if (pools[i].tokenA == pools[j].tokenA && pools[i].tokenB == pools[j].tokenB) {
                        ArbitrageOpportunity memory opportunity = calculateSimpleArbitrage(
                            pools[i],
                            pools[j],
                            amountIn,
                            gasPrice,
                            gasLimit
                        );

                        if (opportunity.netProfit > bestPath.totalProfit) {
                            bestPath.pools = new DEXPool[](2);
                            bestPath.pools[0] = pools[i];
                            bestPath.pools[1] = pools[j];
                            bestPath.amounts = new uint256[](3); // in, intermediate, out
                            bestPath.amounts[0] = amountIn;
                            bestPath.totalProfit = opportunity.netProfit;
                            bestPath.totalGas = opportunity.gasCost;
                            bestPath.efficiency = opportunity.netProfit * 1e18 / opportunity.gasCost;
                        }
                    }
                }
            }

            return bestPath;
        }
    }

    /**
     * @dev Calculates arbitrage efficiency score
     */
    function calculateArbitrageEfficiency(
        uint256 profit,
        uint256 gasCost,
        uint256 capital
    ) internal pure returns (uint256) {
        unchecked {
            if (gasCost == 0 || capital == 0) return 0;

            uint256 profitPerGas = profit * 1e18 / gasCost;
            uint256 roi = profit * 1e18 / capital;

            return (profitPerGas + roi) / 2;
        }
    }

    /**
     * @dev Validates arbitrage opportunity
     */
    function validateArbitrageOpportunity(
        ArbitrageOpportunity memory opportunity,
        uint256 minProfit,
        uint256 maxSlippage,
        uint256 maxPriceImpact
    ) internal pure returns (bool) {
        return opportunity.isProfitable &&
               opportunity.netProfit >= minProfit &&
               opportunity.priceImpact <= maxPriceImpact;
    }

    /**
     * @dev Calculates optimal arbitrage amount
     */
    function calculateOptimalArbitrageAmount(
        DEXPool memory pool1,
        DEXPool memory pool2,
        uint256 maxAmount,
        uint256 gasPrice,
        uint256 gasLimit
    ) internal pure returns (uint256) {
        unchecked {
            uint256 bestAmount = 0;
            uint256 bestProfit = 0;

            // Test different amounts
            uint256 step = maxAmount / 10;
            for (uint256 amount = step; amount <= maxAmount; amount += step) {
                ArbitrageOpportunity memory opportunity = calculateSimpleArbitrage(
                    pool1,
                    pool2,
                    amount,
                    gasPrice,
                    gasLimit
                );

                if (opportunity.netProfit > bestProfit) {
                    bestProfit = opportunity.netProfit;
                    bestAmount = amount;
                }
            }

            return bestAmount;
        }
    }

    /**
     * @dev Calculates arbitrage risk score
     */
    function calculateArbitrageRisk(
        ArbitrageOpportunity memory opportunity,
        uint256[] memory historicalVolatility,
        uint256 currentLiquidity
    ) internal pure returns (uint256) {
        unchecked {
            uint256 volatilityRisk = PriceLib.calculateVolatility(historicalVolatility);
            uint256 liquidityRisk = currentLiquidity < 1e18 ? (1e18 - currentLiquidity) / 1e16 : 0; // Scale down
            uint256 sizeRisk = opportunity.amountIn > currentLiquidity / 10 ? 5000 : 0; // 50% risk if >10% of liquidity

            return (volatilityRisk + liquidityRisk + sizeRisk) / 3;
        }
    }

    /**
     * @dev Estimates arbitrage execution time
     */
    function estimateExecutionTime(
        uint256 gasLimit,
        uint256 gasPrice,
        uint256 networkCongestion
    ) internal pure returns (uint256) {
        unchecked {
            // Simplified estimation based on gas and network conditions
            uint256 baseTime = gasLimit / 21000; // Assume 21k gas per second baseline
            uint256 congestionMultiplier = 1e18 + (networkCongestion * 2); // Up to 3x slower

            return baseTime * congestionMultiplier / 1e18;
        }
    }

    /**
     * @dev Calculates arbitrage success probability
     */
    function calculateSuccessProbability(
        ArbitrageOpportunity memory opportunity,
        uint256 historicalSuccessRate,
        uint256 currentRisk
    ) internal pure returns (uint256) {
        unchecked {
            uint256 baseProbability = historicalSuccessRate;
            uint256 riskAdjustment = currentRisk > 5000 ? (currentRisk - 5000) / 50 : 0; // Reduce by risk

            return baseProbability > riskAdjustment ? baseProbability - riskAdjustment : 0;
        }
    }

    /**
     * @dev Calculates flash loan arbitrage profitability
     */
    function calculateFlashArbitrageProfit(
        uint256 loanAmount,
        uint256 flashFee,
        ArbitrageOpportunity memory opportunity
    ) internal pure returns (uint256) {
        unchecked {
            uint256 flashLoanFee = FeeLib.calculateFlashFee(loanAmount, flashFee, 5); // 5 bps premium
            uint256 totalCost = opportunity.gasCost + flashLoanFee;

            return opportunity.expectedProfit > totalCost
                ? opportunity.expectedProfit - totalCost
                : 0;
        }
    }

    /**
     * @dev Gets arbitrage statistics
     */
    function getArbitrageStats(
        ArbitrageOpportunity[] memory opportunities
    ) internal pure returns (
        uint256 totalOpportunities,
        uint256 profitableOpportunities,
        uint256 averageProfit,
        uint256 maxProfit
    ) {
        unchecked {
            totalOpportunities = opportunities.length;
            uint256 profitableCount = 0;
            uint256 totalProfit = 0;
            uint256 maxProfitFound = 0;

            for (uint256 i = 0; i < opportunities.length; i++) {
                if (opportunities[i].isProfitable) {
                    profitableCount++;
                    totalProfit += opportunities[i].netProfit;
                    if (opportunities[i].netProfit > maxProfitFound) {
                        maxProfitFound = opportunities[i].netProfit;
                    }
                }
            }

            averageProfit = profitableCount > 0 ? totalProfit / profitableCount : 0;
            maxProfit = maxProfitFound;
            profitableOpportunities = profitableCount;
        }
    }
}
