// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";

/**
 * @title Aetherweb3AMM
 * @dev Automated Market Maker utility library for liquidity pool calculations
 * @notice Provides AMM calculations, slippage protection, and liquidity management
 */
library Aetherweb3AMM {
    using Aetherweb3Math for uint256;

    uint256 internal constant MINIMUM_LIQUIDITY = 1000;

    // Pool information
    struct PoolInfo {
        uint256 reserve0;           // Reserve of token0
        uint256 reserve1;           // Reserve of token1
        uint256 totalSupply;        // Total LP tokens
        uint256 fee;               // Trading fee in basis points
        uint256 kLast;             // Last k value for fee calculation
    }

    // Swap parameters
    struct SwapParams {
        uint256 amountIn;          // Input amount
        uint256 amountOutMin;      // Minimum output amount
        address[] path;            // Swap path
        address to;               // Recipient address
        uint256 deadline;         // Transaction deadline
    }

    // Liquidity parameters
    struct LiquidityParams {
        uint256 amount0Desired;   // Desired amount of token0
        uint256 amount1Desired;   // Desired amount of token1
        uint256 amount0Min;       // Minimum amount of token0
        uint256 amount1Min;       // Minimum amount of token1
        address to;               // LP token recipient
        uint256 deadline;         // Transaction deadline
    }

    /**
     * @dev Calculates output amount for exact input swap
     * @param amountIn Input amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @param fee Trading fee in basis points
     * @return amountOut Output amount
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Aetherweb3AMM: insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Aetherweb3AMM: insufficient liquidity");

        uint256 amountInWithFee = amountIn * (10000 - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    /**
     * @dev Calculates input amount for exact output swap
     * @param amountOut Output amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @param fee Trading fee in basis points
     * @return amountIn Required input amount
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "Aetherweb3AMM: insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "Aetherweb3AMM: insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - fee);

        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @dev Calculates optimal amounts for liquidity provision
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @param amount0Min Minimum amount of token0
     * @param amount1Min Minimum amount of token1
     * @param reserve0 Current reserve of token0
     * @param reserve1 Current reserve of token1
     * @return amount0 Optimal amount of token0
     * @return amount1 Optimal amount of token1
     */
    function quote(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = quote(amount0Desired, reserve0, reserve1);
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Aetherweb3AMM: insufficient amount1");
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = quote(amount1Desired, reserve1, reserve0);
                require(amount0Optimal <= amount0Desired, "Aetherweb3AMM: insufficient amount0");
                require(amount0Optimal >= amount0Min, "Aetherweb3AMM: insufficient amount0");
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    /**
     * @dev Calculates quote amount
     * @param amountIn Input amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountOut Quoted output amount
     */
    function quote(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Aetherweb3AMM: insufficient amount");
        require(reserveIn > 0 && reserveOut > 0, "Aetherweb3AMM: insufficient liquidity");

        amountOut = (amountIn * reserveOut) / reserveIn;
    }

    /**
     * @dev Calculates liquidity tokens to mint
     * @param amount0 Amount of token0
     * @param amount1 Amount of token1
     * @param reserve0 Current reserve of token0
     * @param reserve1 Current reserve of token1
     * @param totalSupply Current total supply of LP tokens
     * @return liquidity Amount of liquidity tokens to mint
     */
    function mintLiquidity(
        uint256 amount0,
        uint256 amount1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal pure returns (uint256 liquidity) {
        if (totalSupply == 0) {
            liquidity = Aetherweb3Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Aetherweb3AMM: insufficient liquidity minted");
        } else {
            liquidity = Aetherweb3Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }
    }

    /**
     * @dev Calculates tokens to return for liquidity burn
     * @param liquidity Amount of liquidity tokens to burn
     * @param reserve0 Current reserve of token0
     * @param reserve1 Current reserve of token1
     * @param totalSupply Current total supply of LP tokens
     * @return amount0 Amount of token0 to return
     * @return amount1 Amount of token1 to return
     */
    function burnLiquidity(
        uint256 liquidity,
        uint256 reserve0,
        uint256 reserve1,
        uint256 totalSupply
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;
    }

    /**
     * @dev Calculates price impact of a trade
     * @param amountIn Input amount
     * @param amountOut Output amount
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return priceImpact Price impact percentage in wad
     */
    function calculatePriceImpact(
        uint256 amountIn,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 priceImpact) {
        uint256 expectedOut = quote(amountIn, reserveIn, reserveOut);
        if (expectedOut <= amountOut) return 0;

        uint256 impact = ((expectedOut - amountOut) * Aetherweb3Math.WAD) / expectedOut;
        priceImpact = impact;
    }

    /**
     * @dev Calculates slippage tolerance
     * @param amountOut Expected output amount
     * @param slippageTolerance Slippage tolerance in basis points
     * @return amountOutMin Minimum acceptable output amount
     */
    function calculateSlippageTolerance(
        uint256 amountOut,
        uint256 slippageTolerance
    ) internal pure returns (uint256 amountOutMin) {
        require(slippageTolerance <= 10000, "Aetherweb3AMM: invalid slippage tolerance");

        uint256 slippageAmount = Aetherweb3Math.percent(amountOut, slippageTolerance);
        amountOutMin = amountOut - slippageAmount;
    }

    /**
     * @dev Validates swap parameters
     * @param params Swap parameters
     * @param currentTime Current timestamp
     * @return valid True if parameters are valid
     */
    function validateSwapParams(
        SwapParams memory params,
        uint256 currentTime
    ) internal pure returns (bool valid) {
        if (params.amountIn == 0) return false;
        if (params.path.length < 2) return false;
        if (params.to == address(0)) return false;
        if (params.deadline < currentTime) return false;

        for (uint256 i = 0; i < params.path.length; i++) {
            if (params.path[i] == address(0)) return false;
        }

        return true;
    }

    /**
     * @dev Validates liquidity parameters
     * @param params Liquidity parameters
     * @param currentTime Current timestamp
     * @return valid True if parameters are valid
     */
    function validateLiquidityParams(
        LiquidityParams memory params,
        uint256 currentTime
    ) internal pure returns (bool valid) {
        if (params.amount0Desired == 0 && params.amount1Desired == 0) return false;
        if (params.to == address(0)) return false;
        if (params.deadline < currentTime) return false;
        return true;
    }

    /**
     * @dev Calculates pool fee accumulation
     * @param fee Fee amount collected
     * @param kLast Last k value
     * @param totalSupply Current total supply
     * @return feeAmount Fee amount for LP providers
     */
    function calculatePoolFee(
        uint256 fee,
        uint256 kLast,
        uint256 totalSupply
    ) internal pure returns (uint256 feeAmount) {
        if (kLast != 0) {
            uint256 rootK = Aetherweb3Math.sqrt(kLast);
            uint256 rootKLast = Aetherweb3Math.sqrt(kLast);
            if (rootK > rootKLast) {
                uint256 numerator = totalSupply * (rootK - rootKLast);
                uint256 denominator = (rootK * 5) + rootKLast; // 1/6th of growth
                feeAmount = numerator / denominator;
            }
        }
    }

    /**
     * @dev Calculates impermanent loss
     * @param priceRatioInitial Initial price ratio
     * @param priceRatioCurrent Current price ratio
     * @return impermanentLoss Impermanent loss percentage in wad
     */
    function calculateImpermanentLoss(
        uint256 priceRatioInitial,
        uint256 priceRatioCurrent
    ) internal pure returns (uint256 impermanentLoss) {
        if (priceRatioInitial == 0 || priceRatioCurrent == 0) return 0;

        uint256 ratio = priceRatioCurrent.wdiv(priceRatioInitial);
        uint256 sqrtRatio = Aetherweb3Math.sqrt(ratio);

        // IL = 2*sqrt(ratio)/(1+ratio) - 1
        uint256 numerator = 2 * sqrtRatio;
        uint256 denominator = Aetherweb3Math.WAD + ratio;
        uint256 value = numerator.wdiv(denominator);

        if (value < Aetherweb3Math.WAD) {
            impermanentLoss = Aetherweb3Math.WAD - value;
        } else {
            impermanentLoss = 0;
        }
    }

    /**
     * @dev Calculates optimal portfolio allocation
     * @param volatility0 Volatility of token0
     * @param volatility1 Volatility of token1
     * @param correlation Correlation between tokens
     * @return weight0 Optimal weight for token0 in wad
     * @return weight1 Optimal weight for token1 in wad
     */
    function calculateOptimalWeights(
        uint256 volatility0,
        uint256 volatility1,
        uint256 correlation
    ) internal pure returns (uint256 weight0, uint256 weight1) {
        if (volatility0 == 0 && volatility1 == 0) {
            return (Aetherweb3Math.WAD / 2, Aetherweb3Math.WAD / 2);
        }

        // Simplified Markowitz optimization
        uint256 vol0Squared = volatility0.wmul(volatility0);
        uint256 vol1Squared = volatility1.wmul(volatility1);
        uint256 covariance = correlation.wmul(volatility0).wmul(volatility1);

        uint256 denominator = vol0Squared + vol1Squared - (2 * covariance);
        if (denominator == 0) {
            return (Aetherweb3Math.WAD / 2, Aetherweb3Math.WAD / 2);
        }

        weight0 = (vol1Squared - covariance).wdiv(denominator);
        weight1 = Aetherweb3Math.WAD - weight0;
    }
}
