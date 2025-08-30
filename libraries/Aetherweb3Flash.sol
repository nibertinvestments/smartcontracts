// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3AMM.sol";

/**
 * @title Aetherweb3Flash
 * @dev Flash loan utility library for arbitrage and liquidation operations
 * @notice Provides flash loan calculations, arbitrage detection, and liquidation logic
 */
library Aetherweb3Flash {
    using Aetherweb3Math for uint256;
    using Aetherweb3AMM for uint256;

    // Flash loan parameters
    struct FlashLoanParams {
        address asset;           // Asset to borrow
        uint256 amount;          // Amount to borrow
        address[] path;          // Arbitrage path
        uint256 expectedProfit;  // Expected profit
        uint256 deadline;        // Transaction deadline
    }

    // Arbitrage opportunity
    struct ArbitrageOpportunity {
        address[] path;          // Token swap path
        uint256 amountIn;        // Input amount
        uint256 expectedOut;     // Expected output
        uint256 profit;          // Expected profit
        uint256 gasCost;         // Estimated gas cost
        bool isProfitable;       // Whether opportunity is profitable
    }

    // Liquidation parameters
    struct LiquidationParams {
        address borrower;        // Borrower address
        address collateralAsset; // Collateral asset
        address debtAsset;       // Debt asset
        uint256 debtAmount;      // Debt amount to repay
        uint256 collateralAmount; // Collateral amount to seize
        uint256 liquidationBonus; // Liquidation bonus
    }

    /**
     * @dev Calculates flash loan fee
     * @param amount Loan amount
     * @param feeRate Fee rate in basis points
     * @return fee Flash loan fee
     */
    function calculateFlashLoanFee(
        uint256 amount,
        uint256 feeRate
    ) internal pure returns (uint256 fee) {
        fee = Aetherweb3Math.percent(amount, feeRate);
    }

    /**
     * @dev Calculates minimum profit for flash loan to be profitable
     * @param loanAmount Loan amount
     * @param feeRate Fee rate in basis points
     * @param gasCost Estimated gas cost
     * @return minProfit Minimum profit required
     */
    function calculateMinimumProfit(
        uint256 loanAmount,
        uint256 feeRate,
        uint256 gasCost
    ) internal pure returns (uint256 minProfit) {
        uint256 fee = calculateFlashLoanFee(loanAmount, feeRate);
        minProfit = fee + gasCost;
    }

    /**
     * @dev Validates flash loan parameters
     * @param params Flash loan parameters
     * @param currentTime Current timestamp
     * @return isValid True if parameters are valid
     */
    function validateFlashLoanParams(
        FlashLoanParams memory params,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (params.asset == address(0)) return false;
        if (params.amount == 0) return false;
        if (params.path.length < 2) return false;
        if (params.deadline < currentTime) return false;

        for (uint256 i = 0; i < params.path.length; i++) {
            if (params.path[i] == address(0)) return false;
        }

        return true;
    }

    /**
     * @dev Detects arbitrage opportunities across multiple pools
     * @param pools Array of pool information
     * @param amountIn Input amount for arbitrage
     * @param gasPrice Current gas price
     * @return opportunities Array of arbitrage opportunities
     */
    function detectArbitrageOpportunities(
        Aetherweb3AMM.PoolInfo[] memory pools,
        uint256 amountIn,
        uint256 gasPrice
    ) internal pure returns (ArbitrageOpportunity[] memory opportunities) {
        // Simplified arbitrage detection
        // In practice, this would be more complex with multi-hop paths

        opportunities = new ArbitrageOpportunity[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            // Calculate potential arbitrage
            uint256 expectedOut = amountIn.getAmountOut(
                pools[i].reserve0,
                pools[i].reserve1,
                pools[i].fee
            );

            uint256 profit = expectedOut > amountIn ? expectedOut - amountIn : 0;
            uint256 gasCost = estimateGasCost(200000, gasPrice); // Estimated gas for arbitrage

            opportunities[i] = ArbitrageOpportunity({
                path: new address[](2), // Simplified path
                amountIn: amountIn,
                expectedOut: expectedOut,
                profit: profit,
                gasCost: gasCost,
                isProfitable: profit > gasCost
            });
        }
    }

    /**
     * @dev Estimates gas cost for flash loan operation
     * @param gasLimit Estimated gas limit
     * @param gasPrice Current gas price
     * @return cost Estimated cost in wei
     */
    function estimateGasCost(
        uint256 gasLimit,
        uint256 gasPrice
    ) internal pure returns (uint256 cost) {
        return gasLimit * gasPrice;
    }

    /**
     * @dev Calculates optimal flash loan amount for arbitrage
     * @param reserve0 Pool reserve 0
     * @param reserve1 Pool reserve 1
     * @param fee Pool fee
     * @return optimalAmount Optimal loan amount
     */
    function calculateOptimalLoanAmount(
        uint256 reserve0,
        uint256 reserve1,
        uint256 fee
    ) internal pure returns (uint256 optimalAmount) {
        // Simplified calculation - in practice, you'd solve for maximum profit
        uint256 k = reserve0 * reserve1;
        uint256 feeFactor = 10000 - fee;

        // Optimal amount is approximately sqrt(k * feeFactor / 10000)
        optimalAmount = Aetherweb3Math.sqrt(
            k * feeFactor / 10000
        );
    }

    /**
     * @dev Calculates liquidation parameters
     * @param collateralValue Value of collateral
     * @param debtValue Value of debt
     * @param liquidationThreshold Liquidation threshold
     * @param liquidationBonus Liquidation bonus
     * @return canLiquidate True if position can be liquidated
     * @return maxDebtAmount Maximum debt that can be repaid
     */
    function calculateLiquidationParams(
        uint256 collateralValue,
        uint256 debtValue,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) internal pure returns (bool canLiquidate, uint256 maxDebtAmount) {
        uint256 thresholdValue = collateralValue.wmul(liquidationThreshold);

        if (debtValue > thresholdValue) {
            canLiquidate = true;
            // Can liquidate up to the point where health factor = 1
            maxDebtAmount = thresholdValue;
        } else {
            canLiquidate = false;
            maxDebtAmount = 0;
        }
    }

    /**
     * @dev Calculates collateral to seize in liquidation
     * @param debtAmount Amount of debt being repaid
     * @param collateralPrice Price of collateral
     * @param debtPrice Price of debt
     * @param liquidationBonus Liquidation bonus
     * @return collateralToSeize Amount of collateral to seize
     */
    function calculateCollateralToSeize(
        uint256 debtAmount,
        uint256 collateralPrice,
        uint256 debtPrice,
        uint256 liquidationBonus
    ) internal pure returns (uint256 collateralToSeize) {
        uint256 debtValueInCollateral = debtAmount.wmul(debtPrice).wdiv(collateralPrice);
        uint256 bonus = Aetherweb3Math.percent(debtValueInCollateral, liquidationBonus);
        collateralToSeize = debtValueInCollateral + bonus;
    }

    /**
     * @dev Validates liquidation parameters
     * @param params Liquidation parameters
     * @return isValid True if parameters are valid
     */
    function validateLiquidationParams(
        LiquidationParams memory params
    ) internal pure returns (bool isValid) {
        if (params.borrower == address(0)) return false;
        if (params.collateralAsset == address(0)) return false;
        if (params.debtAsset == address(0)) return false;
        if (params.debtAmount == 0) return false;
        if (params.collateralAmount == 0) return false;
        return true;
    }

    /**
     * @dev Calculates flash loan profit after fees
     * @param loanAmount Loan amount
     * @param profitBeforeFees Profit before flash loan fees
     * @param feeRate Flash loan fee rate
     * @param gasCost Gas cost
     * @return netProfit Net profit after all costs
     */
    function calculateNetProfit(
        uint256 loanAmount,
        uint256 profitBeforeFees,
        uint256 feeRate,
        uint256 gasCost
    ) internal pure returns (uint256 netProfit) {
        uint256 flashLoanFee = calculateFlashLoanFee(loanAmount, feeRate);
        uint256 totalCosts = flashLoanFee + gasCost;

        if (profitBeforeFees > totalCosts) {
            netProfit = profitBeforeFees - totalCosts;
        } else {
            netProfit = 0;
        }
    }

    /**
     * @dev Checks if arbitrage opportunity is still valid
     * @param opportunity Arbitrage opportunity
     * @param currentReserves Current pool reserves
     * @param slippageTolerance Maximum slippage tolerance
     * @return isValid True if opportunity is still valid
     */
    function validateArbitrageOpportunity(
        ArbitrageOpportunity memory opportunity,
        uint256[] memory currentReserves,
        uint256 slippageTolerance
    ) internal pure returns (bool isValid) {
        if (!opportunity.isProfitable) return false;

        // Check if expected output is still within slippage tolerance
        uint256 minAcceptableOut = opportunity.expectedOut.percent(
            Aetherweb3Math.WAD - slippageTolerance
        );

        // Simplified validation - in practice, you'd recalculate the path
        return opportunity.expectedOut >= minAcceptableOut;
    }

    /**
     * @dev Calculates maximum flash loan amount for a given asset
     * @param availableLiquidity Available liquidity in pool
     * @param utilizationRate Maximum utilization rate
     * @return maxLoanAmount Maximum loan amount
     */
    function calculateMaxFlashLoanAmount(
        uint256 availableLiquidity,
        uint256 utilizationRate
    ) internal pure returns (uint256 maxLoanAmount) {
        maxLoanAmount = availableLiquidity.wmul(utilizationRate);
    }

    /**
     * @dev Estimates arbitrage execution time
     * @param pathLength Length of arbitrage path
     * @param averageBlockTime Average block time
     * @return executionTime Estimated execution time
     */
    function estimateExecutionTime(
        uint256 pathLength,
        uint256 averageBlockTime
    ) internal pure returns (uint256 executionTime) {
        // Estimate based on path complexity
        uint256 baseTime = 15; // Base execution time in seconds
        uint256 pathMultiplier = pathLength * 5; // Additional time per hop
        executionTime = baseTime + pathMultiplier;
    }

    /**
     * @dev Calculates flash loan health factor
     * @param collateralValue Value of collateral
     * @param debtValue Value of debt
     * @param liquidationThreshold Liquidation threshold
     * @return healthFactor Health factor (higher is better)
     */
    function calculateHealthFactor(
        uint256 collateralValue,
        uint256 debtValue,
        uint256 liquidationThreshold
    ) internal pure returns (uint256 healthFactor) {
        if (debtValue == 0) return type(uint256).max;

        uint256 adjustedCollateral = collateralValue.wmul(liquidationThreshold);
        healthFactor = adjustedCollateral.wdiv(debtValue);
    }

    /**
     * @dev Checks if position is undercollateralized
     * @param healthFactor Current health factor
     * @param minimumHealthFactor Minimum required health factor
     * @return isUndercollateralized True if position needs liquidation
     */
    function isUndercollateralized(
        uint256 healthFactor,
        uint256 minimumHealthFactor
    ) internal pure returns (bool isUndercollateralized) {
        return healthFactor < minimumHealthFactor;
    }

    /**
     * @dev Calculates optimal liquidation amount
     * @param debtAmount Total debt amount
     * @param maxLiquidationAmount Maximum amount that can be liquidated
     * @param liquidationIncentive Liquidation incentive
     * @return optimalAmount Optimal amount to liquidate
     */
    function calculateOptimalLiquidationAmount(
        uint256 debtAmount,
        uint256 maxLiquidationAmount,
        uint256 liquidationIncentive
    ) internal pure returns (uint256 optimalAmount) {
        // Liquidate up to max amount or 50% of debt, whichever is smaller
        uint256 maxByPercentage = debtAmount / 2;
        optimalAmount = Aetherweb3Math.min(maxLiquidationAmount, maxByPercentage);
    }
}
