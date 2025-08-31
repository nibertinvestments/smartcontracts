// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

interface IChainlinkAggregator {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

interface IUniswapV3Pool {
    function observe(uint32[] calldata secondsAgos) external view returns (
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    );
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}

contract OracleModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct PriceFeed {
        address aggregator;      // Chainlink aggregator address
        address uniswapPool;     // Uniswap V3 pool for TWAP
        uint256 heartbeat;       // Maximum time between updates
        uint256 deviationThreshold; // Maximum price deviation allowed
        bool isActive;
        uint8 decimals;
    }

    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;      // Confidence score (0-100)
        bool isValid;
    }

    mapping(address => PriceFeed) public priceFeeds;
    mapping(address => PriceData) public latestPrices;
    mapping(address => uint256[]) public priceHistory;

    address[] public supportedAssets;
    uint256 public constant MAX_HISTORY_SIZE = 100;
    uint256 public constant GRACE_PERIOD = 3600; // 1 hour

    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event PriceFeedAdded(address indexed asset, address aggregator);
    event PriceAnomalyDetected(address indexed asset, uint256 expectedPrice, uint256 actualPrice);
    event OracleFallbackTriggered(address indexed asset, string reason);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        // Initialize with common assets
        _addPriceFeed(
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH/USD Chainlink
            address(0), // No Uniswap pool initially
            3600,      // 1 hour heartbeat
            500       // 5% deviation threshold
        );

        _addPriceFeed(
            0xA0b86a33E6441e88C5F2712C3E9b74F5b8F1e6E7, // USDC
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6b, // USDC/USD Chainlink
            address(0),
            86400,    // 24 hour heartbeat
            100       // 1% deviation threshold
        );
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function addPriceFeed(
        address asset,
        address aggregator,
        address uniswapPool,
        uint256 heartbeat,
        uint256 deviationThreshold
    ) external onlyOwner {
        _addPriceFeed(asset, aggregator, uniswapPool, heartbeat, deviationThreshold);
    }

    function _addPriceFeed(
        address asset,
        address aggregator,
        address uniswapPool,
        uint256 heartbeat,
        uint256 deviationThreshold
    ) internal {
        require(asset != address(0), "Invalid asset address");

        uint8 decimals = 18; // Default
        if (aggregator != address(0)) {
            decimals = IChainlinkAggregator(aggregator).decimals();
        }

        priceFeeds[asset] = PriceFeed({
            aggregator: aggregator,
            uniswapPool: uniswapPool,
            heartbeat: heartbeat,
            deviationThreshold: deviationThreshold,
            isActive: true,
            decimals: decimals
        });

        supportedAssets.push(asset);
        emit PriceFeedAdded(asset, aggregator);
    }

    function updatePriceFeed(
        address asset,
        address aggregator,
        address uniswapPool,
        uint256 heartbeat,
        uint256 deviationThreshold
    ) external onlyOwner {
        require(priceFeeds[asset].isActive, "Price feed not active");

        priceFeeds[asset].aggregator = aggregator;
        priceFeeds[asset].uniswapPool = uniswapPool;
        priceFeeds[asset].heartbeat = heartbeat;
        priceFeeds[asset].deviationThreshold = deviationThreshold;

        if (aggregator != address(0)) {
            priceFeeds[asset].decimals = IChainlinkAggregator(aggregator).decimals();
        }
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeSwap) {
            (address user, uint256 amountIn, uint256 amountOutMin) = abi.decode(data, (address, uint256, uint256, uint256));
            // Validate swap prices
            return abi.encode(validateSwapPrice(user, amountIn, amountOutMin));
        }

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from, address to, uint256 amount) = abi.decode(data, (address, address, uint256));
            // Could validate transfer amounts based on asset prices
            return abi.encode(true);
        }

        if (tupleType == IModularTuple.TupleType.BeforeValidation) {
            // Update prices before validation
            updateAllPrices();
            return abi.encode(true);
        }

        return abi.encode(true);
    }

    function getPrice(address asset) external view returns (PriceData memory) {
        return latestPrices[asset];
    }

    function getPriceWithFallback(address asset) external returns (PriceData memory) {
        PriceData memory priceData = latestPrices[asset];

        // Check if price is stale
        if (block.timestamp - priceData.timestamp > priceFeeds[asset].heartbeat) {
            // Try to update price
            updatePrice(asset);
            priceData = latestPrices[asset];
        }

        return priceData;
    }

    function updatePrice(address asset) public whenNotPaused {
        PriceFeed memory feed = priceFeeds[asset];
        require(feed.isActive, "Price feed not active");

        uint256 price;
        uint256 confidence = 100;
        bool isValid = true;

        // Try Chainlink first
        if (feed.aggregator != address(0)) {
            try IChainlinkAggregator(feed.aggregator).latestRoundData() returns (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) {
                if (answer > 0 && updatedAt > 0) {
                    price = uint256(answer);
                    // Check staleness
                    if (block.timestamp - updatedAt > feed.heartbeat) {
                        confidence -= 20;
                    }
                } else {
                    isValid = false;
                }
            } catch {
                isValid = false;
            }
        }

        // Fallback to Uniswap TWAP if Chainlink fails
        if (!isValid && feed.uniswapPool != address(0)) {
            try this.getUniswapTWAP(feed.uniswapPool) returns (uint256 twapPrice) {
                price = twapPrice;
                confidence -= 30; // Lower confidence for TWAP
                isValid = true;
                emit OracleFallbackTriggered(asset, "Chainlink failed, using TWAP");
            } catch {
                isValid = false;
            }
        }

        if (isValid) {
            // Check for price anomalies
            PriceData memory lastPrice = latestPrices[asset];
            if (lastPrice.isValid && lastPrice.price > 0) {
                uint256 deviation = calculateDeviation(price, lastPrice.price);
                if (deviation > feed.deviationThreshold) {
                    emit PriceAnomalyDetected(asset, lastPrice.price, price);
                    confidence -= 20;
                }
            }

            // Update price data
            latestPrices[asset] = PriceData({
                price: price,
                timestamp: block.timestamp,
                confidence: confidence,
                isValid: true
            });

            // Add to history
            addToHistory(asset, price);

            emit PriceUpdated(asset, price, block.timestamp);
        }
    }

    function updateAllPrices() public whenNotPaused {
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            updatePrice(supportedAssets[i]);
        }
    }

    function getUniswapTWAP(address pool) external view returns (uint256) {
        // Simplified TWAP calculation
        // In production, this would implement proper TWAP logic
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = 0;      // Now
        secondsAgos[1] = 1800;   // 30 minutes ago

        IUniswapV3Pool uniswapPool = IUniswapV3Pool(pool);
        (int56[] memory tickCumulatives,) = uniswapPool.observe(secondsAgos);

        // Simplified calculation - in production use proper tick math
        int56 tickCumulativeDelta = tickCumulatives[0] - tickCumulatives[1];
        int24 averageTick = int24(tickCumulativeDelta / 1800);

        // Convert tick to price (simplified)
        uint256 price = 1e18; // Base price
        if (averageTick > 0) {
            price = price * (1e18 + uint256(int256(averageTick) * 1e14)) / 1e18;
        }

        return price;
    }

    function validateSwapPrice(
        address user,
        uint256 amountIn,
        uint256 amountOutMin
    ) internal view returns (bool) {
        // Basic price validation logic
        // In production, this would compare against oracle prices
        if (amountIn == 0 || amountOutMin == 0) return false;

        // Check for reasonable slippage
        // This is simplified - production would use actual price data
        uint256 expectedSlippage = (amountOutMin * 100) / amountIn;
        if (expectedSlippage < 95) { // More than 5% slippage
            return false;
        }

        return true;
    }

    function calculateDeviation(uint256 newPrice, uint256 oldPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;
        uint256 diff = newPrice > oldPrice ? newPrice - oldPrice : oldPrice - newPrice;
        return (diff * 10000) / oldPrice; // Return basis points
    }

    function addToHistory(address asset, uint256 price) internal {
        uint256[] storage history = priceHistory[asset];
        history.push(price);

        // Keep history size manageable
        if (history.length > MAX_HISTORY_SIZE) {
            // Remove oldest entries (simplified)
            for (uint256 i = 0; i < history.length - MAX_HISTORY_SIZE; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }
    }

    function getPriceHistory(address asset) external view returns (uint256[] memory) {
        return priceHistory[asset];
    }

    function getAveragePrice(address asset, uint256 periods) external view returns (uint256) {
        uint256[] memory history = priceHistory[asset];
        if (history.length == 0) return 0;

        uint256 count = periods < history.length ? periods : history.length;
        uint256 sum = 0;

        for (uint256 i = history.length - count; i < history.length; i++) {
            sum += history[i];
        }

        return sum / count;
    }

    function getContractName() external pure returns (string memory) {
        return "OracleModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("ORACLE");
    }

    function validate(bytes calldata data) external view returns (bool) {
        if (data.length < 20) return false;
        (address asset) = abi.decode(data, (address));
        return priceFeeds[asset].isActive;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 50000; // Conservative estimate for oracle operations
    }

    function isActive() external view returns (bool) {
        return !paused && leaderContract != address(0);
    }

    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    ) {
        return (
            this.getContractName(),
            this.getContractVersion(),
            this.getContractType(),
            this.isActive(),
            leaderContract
        );
    }
}
