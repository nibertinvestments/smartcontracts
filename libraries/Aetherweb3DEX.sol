// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3DEX
 * @dev Decentralized exchange utility library
 * @notice Provides DEX calculations, order book management, and trading utilities
 */
library Aetherweb3DEX {
    using Aetherweb3Math for uint256;

    // Order information
    struct Order {
        uint256 orderId;         // Unique order ID
        address trader;          // Order creator
        address baseToken;       // Base token address
        address quoteToken;      // Quote token address
        uint256 amount;          // Order amount
        uint256 price;           // Order price
        uint256 filledAmount;    // Filled amount
        uint256 remainingAmount; // Remaining amount
        OrderType orderType;     // Order type
        OrderSide orderSide;     // Order side
        OrderStatus status;      // Order status
        uint256 timestamp;       // Order timestamp
        uint256 expirationTime;  // Expiration timestamp
        bytes32 orderHash;       // Order hash
    }

    // Order type enumeration
    enum OrderType {
        MARKET,
        LIMIT,
        STOP,
        STOP_LIMIT
    }

    // Order side enumeration
    enum OrderSide {
        BUY,
        SELL
    }

    // Order status enumeration
    enum OrderStatus {
        PENDING,
        PARTIAL,
        FILLED,
        CANCELLED,
        EXPIRED
    }

    // Order book entry
    struct OrderBookEntry {
        uint256 price;           // Price level
        uint256 totalAmount;     // Total amount at price level
        uint256 orderCount;      // Number of orders at price level
        address[] traders;       // Traders at this price level
        uint256[] amounts;       // Amounts for each trader
    }

    // Trading pair information
    struct TradingPair {
        address baseToken;       // Base token
        address quoteToken;      // Quote token
        uint256 minOrderSize;    // Minimum order size
        uint256 maxOrderSize;    // Maximum order size
        uint256 tickSize;        // Price tick size
        uint256 lotSize;         // Order lot size
        uint256 makerFee;        // Maker fee
        uint256 takerFee;        // Taker fee
        bool active;             // Trading pair active
        uint256 lastPrice;       // Last traded price
        uint256 volume24h;       // 24h volume
        uint256 high24h;         // 24h high
        uint256 low24h;         // 24h low
    }

    // Trade execution information
    struct Trade {
        uint256 tradeId;        // Unique trade ID
        uint256 orderId;        // Associated order ID
        address maker;          // Maker address
        address taker;          // Taker address
        uint256 amount;         // Trade amount
        uint256 price;          // Trade price
        uint256 fee;            // Trade fee
        uint256 timestamp;      // Trade timestamp
        TradeType tradeType;    // Trade type
    }

    // Trade type enumeration
    enum TradeType {
        MARKET_TRADE,
        LIMIT_TRADE,
        LIQUIDATION
    }

    // Market data
    struct MarketData {
        uint256 bestBid;        // Best bid price
        uint256 bestAsk;        // Best ask price
        uint256 spread;         // Bid-ask spread
        uint256 midPrice;       // Mid price
        uint256 volume;         // Trading volume
        uint256 liquidity;      // Market liquidity
        uint256 volatility;     // Price volatility
    }

    // Liquidity pool information
    struct LiquidityPool {
        address tokenA;         // Token A address
        address tokenB;         // Token B address
        uint256 reserveA;       // Token A reserve
        uint256 reserveB;       // Token B reserve
        uint256 totalLiquidity; // Total liquidity tokens
        uint256 fee;            // Pool fee
        uint256 price;          // Current price (tokenA/tokenB)
        bool active;            // Pool active status
    }

    /**
     * @dev Calculates order book depth
     * @param bids Array of bid orders
     * @param asks Array of ask orders
     * @param depthLevels Number of depth levels to calculate
     * @return bidDepth Bid side depth
     * @return askDepth Ask side depth
     */
    function calculateOrderBookDepth(
        Order[] memory bids,
        Order[] memory asks,
        uint256 depthLevels
    ) internal pure returns (
        uint256[] memory bidDepth,
        uint256[] memory askDepth
    ) {
        bidDepth = new uint256[](depthLevels);
        askDepth = new uint256[](depthLevels);

        // Sort bids descending (highest price first)
        sortOrdersByPrice(bids, false);
        // Sort asks ascending (lowest price first)
        sortOrdersByPrice(asks, true);

        for (uint256 i = 0; i < depthLevels; i++) {
            if (i < bids.length) {
                bidDepth[i] = bids[i].remainingAmount;
            }
            if (i < asks.length) {
                askDepth[i] = asks[i].remainingAmount;
            }
        }
    }

    /**
     * @dev Sorts orders by price
     * @param orders Array of orders to sort
     * @param ascending True for ascending sort, false for descending
     */
    function sortOrdersByPrice(
        Order[] memory orders,
        bool ascending
    ) internal pure {
        for (uint256 i = 0; i < orders.length - 1; i++) {
            for (uint256 j = 0; j < orders.length - i - 1; j++) {
                bool shouldSwap;
                if (ascending) {
                    shouldSwap = orders[j].price > orders[j + 1].price;
                } else {
                    shouldSwap = orders[j].price < orders[j + 1].price;
                }

                if (shouldSwap) {
                    Order memory temp = orders[j];
                    orders[j] = orders[j + 1];
                    orders[j + 1] = temp;
                }
            }
        }
    }

    /**
     * @dev Calculates trading pair spread
     * @param bestBid Best bid price
     * @param bestAsk Best ask price
     * @return spread Bid-ask spread
     * @return spreadPercentage Spread as percentage
     */
    function calculateSpread(
        uint256 bestBid,
        uint256 bestAsk
    ) internal pure returns (uint256 spread, uint256 spreadPercentage) {
        if (bestBid == 0 || bestAsk == 0) return (0, 0);

        spread = bestAsk - bestBid;
        spreadPercentage = spread.wdiv(bestBid);
    }

    /**
     * @dev Calculates slippage for market order
     * @param orderAmount Order amount
     * @param orderBook Array of order book entries
     * @param isBuy True for buy order, false for sell order
     * @return slippage Expected slippage
     * @return executionPrice Expected execution price
     */
    function calculateSlippage(
        uint256 orderAmount,
        OrderBookEntry[] memory orderBook,
        bool isBuy
    ) internal pure returns (uint256 slippage, uint256 executionPrice) {
        uint256 remainingAmount = orderAmount;
        uint256 totalCost = 0;
        uint256 totalExecuted = 0;

        for (uint256 i = 0; i < orderBook.length && remainingAmount > 0; i++) {
            uint256 availableAmount = orderBook[i].totalAmount;
            uint256 executeAmount = Aetherweb3Math.min(remainingAmount, availableAmount);

            totalCost += executeAmount.wmul(orderBook[i].price);
            totalExecuted += executeAmount;
            remainingAmount -= executeAmount;
        }

        if (totalExecuted == 0) return (0, 0);

        executionPrice = totalCost.wdiv(totalExecuted);
        uint256 referencePrice = isBuy ? orderBook[0].price : orderBook[0].price;

        if (isBuy) {
            slippage = executionPrice > referencePrice ?
                executionPrice - referencePrice :
                0;
        } else {
            slippage = executionPrice < referencePrice ?
                referencePrice - executionPrice :
                0;
        }
    }

    /**
     * @dev Calculates AMM price impact
     * @param amountIn Input amount
     * @param reserveIn Input token reserve
     * @param reserveOut Output token reserve
     * @param fee Fee percentage
     * @return priceImpact Price impact percentage
     * @return amountOut Output amount
     */
    function calculatePriceImpact(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 priceImpact, uint256 amountOut) {
        uint256 amountInWithFee = amountIn.wmul(Aetherweb3Math.WAD - fee);
        uint256 numerator = amountInWithFee.wmul(reserveOut);
        uint256 denominator = reserveIn.wmul(Aetherweb3Math.WAD) + amountInWithFee;
        amountOut = numerator / denominator;

        uint256 spotPrice = reserveOut.wdiv(reserveIn);
        uint256 effectivePrice = amountOut.wdiv(amountIn);

        priceImpact = spotPrice > effectivePrice ?
            spotPrice - effectivePrice :
            effectivePrice - spotPrice;
    }

    /**
     * @dev Validates trading order
     * @param order Trading order
     * @param pair Trading pair configuration
     * @param currentTime Current timestamp
     * @return isValid True if order is valid
     */
    function validateTradingOrder(
        Order memory order,
        TradingPair memory pair,
        uint256 currentTime
    ) internal pure returns (bool isValid) {
        if (order.trader == address(0)) return false;
        if (order.baseToken != pair.baseToken) return false;
        if (order.quoteToken != pair.quoteToken) return false;
        if (order.amount < pair.minOrderSize) return false;
        if (order.amount > pair.maxOrderSize) return false;
        if (order.price % pair.tickSize != 0) return false;
        if (order.amount % pair.lotSize != 0) return false;
        if (order.expirationTime > 0 && currentTime > order.expirationTime) return false;
        return true;
    }

    /**
     * @dev Calculates trading fees
     * @param amount Trade amount
     * @param price Trade price
     * @param feeRate Fee rate
     * @param isMaker True if maker order, false if taker
     * @return fee Trading fee amount
     */
    function calculateTradingFee(
        uint256 amount,
        uint256 price,
        uint256 feeRate,
        bool isMaker
    ) internal pure returns (uint256 fee) {
        uint256 notionalValue = amount.wmul(price);
        fee = notionalValue.wmul(feeRate);

        // Maker fee discount (typically lower than taker)
        if (isMaker) {
            fee = fee.wmul(80 * Aetherweb3Math.WAD / 100); // 20% discount for makers
        }
    }

    /**
     * @dev Matches orders in order book
     * @param buyOrder Buy order
     * @param sellOrder Sell order
     * @return canMatch True if orders can be matched
     * @return matchAmount Amount that can be matched
     * @return matchPrice Price at which to match
     */
    function matchOrders(
        Order memory buyOrder,
        Order memory sellOrder
    ) internal pure returns (
        bool canMatch,
        uint256 matchAmount,
        uint256 matchPrice
    ) {
        // For limit orders, check price compatibility
        if (buyOrder.orderType == OrderType.LIMIT && sellOrder.orderType == OrderType.LIMIT) {
            if (buyOrder.price < sellOrder.price) {
                return (false, 0, 0);
            }
        }

        // Calculate match amount
        matchAmount = Aetherweb3Math.min(buyOrder.remainingAmount, sellOrder.remainingAmount);
        if (matchAmount == 0) return (false, 0, 0);

        // Calculate match price
        if (buyOrder.orderType == OrderType.MARKET) {
            matchPrice = sellOrder.price;
        } else if (sellOrder.orderType == OrderType.MARKET) {
            matchPrice = buyOrder.price;
        } else {
            // For limit orders, use midpoint or other pricing mechanism
            matchPrice = (buyOrder.price + sellOrder.price) / 2;
        }

        canMatch = true;
    }

    /**
     * @dev Calculates VWAP (Volume Weighted Average Price)
     * @param prices Array of trade prices
     * @param volumes Array of trade volumes
     * @return vwap Volume weighted average price
     */
    function calculateVWAP(
        uint256[] memory prices,
        uint256[] memory volumes
    ) internal pure returns (uint256 vwap) {
        require(prices.length == volumes.length, "Arrays length mismatch");

        uint256 totalVolume = 0;
        uint256 totalValue = 0;

        for (uint256 i = 0; i < prices.length; i++) {
            totalVolume += volumes[i];
            totalValue += prices[i].wmul(volumes[i]);
        }

        if (totalVolume == 0) return 0;
        vwap = totalValue / totalVolume;
    }

    /**
     * @dev Calculates market volatility
     * @param prices Array of historical prices
     * @return volatility Price volatility
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

        // Volatility as standard deviation
        volatility = Aetherweb3Math.sqrt(variance);
    }

    /**
     * @dev Calculates liquidity pool impermanent loss
     * @param initialPrice Initial price ratio
     * @param currentPrice Current price ratio
     * @return impermanentLoss IL percentage
     */
    function calculateImpermanentLoss(
        uint256 initialPrice,
        uint256 currentPrice
    ) internal pure returns (uint256 impermanentLoss) {
        if (initialPrice == 0 || currentPrice == 0) return 0;

        uint256 ratio = currentPrice.wdiv(initialPrice);
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
     * @dev Calculates optimal trade size
     * @param availableLiquidity Available liquidity
     * @param maxSlippage Maximum acceptable slippage
     * @param volatility Market volatility
     * @return optimalSize Optimal trade size
     */
    function calculateOptimalTradeSize(
        uint256 availableLiquidity,
        uint256 maxSlippage,
        uint256 volatility
    ) internal pure returns (uint256 optimalSize) {
        // Simplified calculation based on liquidity and risk tolerance
        uint256 liquidityFactor = availableLiquidity / 100; // 1% of available liquidity
        uint256 slippageFactor = Aetherweb3Math.WAD / (Aetherweb3Math.WAD + maxSlippage);
        uint256 volatilityFactor = Aetherweb3Math.WAD / (Aetherweb3Math.WAD + volatility / 10);

        optimalSize = liquidityFactor.wmul(slippageFactor).wmul(volatilityFactor);
    }

    /**
     * @dev Validates trading pair configuration
     * @param pair Trading pair
     * @return isValid True if configuration is valid
     */
    function validateTradingPair(
        TradingPair memory pair
    ) internal pure returns (bool isValid) {
        if (pair.baseToken == address(0)) return false;
        if (pair.quoteToken == address(0)) return false;
        if (pair.baseToken == pair.quoteToken) return false;
        if (pair.minOrderSize >= pair.maxOrderSize) return false;
        if (pair.tickSize == 0) return false;
        if (pair.lotSize == 0) return false;
        return true;
    }

    /**
     * @dev Calculates order book imbalance
     * @param bidVolume Total bid volume
     * @param askVolume Total ask volume
     * @return imbalance Order book imbalance (-100 to 100)
     */
    function calculateOrderBookImbalance(
        uint256 bidVolume,
        uint256 askVolume
    ) internal pure returns (int256 imbalance) {
        uint256 totalVolume = bidVolume + askVolume;
        if (totalVolume == 0) return 0;

        uint256 bidRatio = bidVolume.wdiv(totalVolume);
        uint256 askRatio = askVolume.wdiv(totalVolume);

        // Convert to signed imbalance
        if (bidRatio > askRatio) {
            imbalance = int256(bidRatio - askRatio);
        } else {
            imbalance = -int256(askRatio - bidRatio);
        }
    }

    /**
     * @dev Calculates market efficiency ratio
     * @param actualPrices Array of actual prices
     * @param fairPrices Array of fair (theoretical) prices
     * @return efficiency Market efficiency ratio
     */
    function calculateMarketEfficiency(
        uint256[] memory actualPrices,
        uint256[] memory fairPrices
    ) internal pure returns (uint256 efficiency) {
        require(
            actualPrices.length == fairPrices.length,
            "Arrays length mismatch"
        );

        uint256 totalDeviation = 0;

        for (uint256 i = 0; i < actualPrices.length; i++) {
            uint256 deviation = actualPrices[i] > fairPrices[i] ?
                actualPrices[i] - fairPrices[i] :
                fairPrices[i] - actualPrices[i];

            totalDeviation += deviation;
        }

        uint256 averageDeviation = totalDeviation / actualPrices.length;
        uint256 averagePrice = calculateAveragePrice(actualPrices);

        if (averagePrice == 0) return 0;

        // Efficiency = 1 - (average deviation / average price)
        uint256 deviationRatio = averageDeviation.wdiv(averagePrice);
        efficiency = deviationRatio < Aetherweb3Math.WAD ?
            Aetherweb3Math.WAD - deviationRatio :
            0;
    }

    /**
     * @dev Calculates average price
     * @param prices Array of prices
     * @return average Average price
     */
    function calculateAveragePrice(
        uint256[] memory prices
    ) internal pure returns (uint256 average) {
        if (prices.length == 0) return 0;

        uint256 sum = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            sum += prices[i];
        }

        average = sum / prices.length;
    }

    /**
     * @dev Calculates arbitrage opportunity
     * @param price1 Price from source 1
     * @param price2 Price from source 2
     * @param fee1 Fee for source 1
     * @param fee2 Fee for source 2
     * @return arbitrageProfit Potential arbitrage profit
     */
    function calculateArbitrageOpportunity(
        uint256 price1,
        uint256 price2,
        uint256 fee1,
        uint256 fee2
    ) internal pure returns (uint256 arbitrageProfit) {
        if (price1 == 0 || price2 == 0) return 0;

        uint256 effectivePrice1 = price1.wmul(Aetherweb3Math.WAD + fee1);
        uint256 effectivePrice2 = price2.wmul(Aetherweb3Math.WAD + fee2);

        if (effectivePrice1 < effectivePrice2) {
            uint256 priceDiff = effectivePrice2 - effectivePrice1;
            arbitrageProfit = priceDiff.wdiv(effectivePrice1);
        } else {
            uint256 priceDiff = effectivePrice1 - effectivePrice2;
            arbitrageProfit = priceDiff.wdiv(effectivePrice2);
        }
    }
}
