// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";
import "../libraries/TWAPLib.sol";
import "../libraries/PriceLib.sol";
import "../libraries/MathLib.sol";

/**
 * @title TWAPModular
 * @dev Modular contract for Time-Weighted Average Price calculations
 * @notice Provides TWAP functionality with manipulation detection and gas optimization
 */
contract TWAPModular is IModularContract {
    using TWAPLib for TWAPLib.TWAPState;
    using PriceLib for uint256;
    using FixedPointMath for uint256;

    // Contract identification
    string public constant override name = "TWAPModular";
    uint256 public constant override version = 1;

    // TWAP storage
    mapping(bytes32 => TWAPLib.TWAPState) private _twapStates;
    mapping(bytes32 => TWAPLib.TWAPConfig) private _twapConfigs;

    // Events
    event TWAPUpdated(bytes32 indexed pairId, uint256 price, uint256 twapPrice, uint32 timestamp);
    event TWAPInitialized(bytes32 indexed pairId, uint256 initialPrice, uint32 timestamp);
    event TWAPReset(bytes32 indexed pairId, uint256 resetPrice, uint32 timestamp);

    // Modifiers
    modifier validPair(bytes32 pairId) {
        require(_twapConfigs[pairId].observationPeriod > 0, "TWAPModular: pair not initialized");
        _;
    }

    /**
     * @dev Initialize TWAP for a trading pair
     */
    function initializeTWAP(
        bytes32 pairId,
        uint256 initialPrice,
        TWAPLib.TWAPConfig memory config
    ) external override onlyLeader {
        require(_twapConfigs[pairId].observationPeriod == 0, "TWAPModular: pair already initialized");
        require(TWAPLib.validateTWAPConfig(config), "TWAPModular: invalid config");

        _twapConfigs[pairId] = config;
        _twapStates[pairId].initializeTWAP(config, initialPrice, uint32(block.timestamp));

        emit TWAPInitialized(pairId, initialPrice, uint32(block.timestamp));
    }

    /**
     * @dev Update TWAP with new price observation
     */
    function updateTWAP(
        bytes32 pairId,
        uint256 currentPrice
    ) external override onlyLeader validPair(pairId) {
        TWAPLib.TWAPState storage state = _twapStates[pairId];
        uint32 currentTime = uint32(block.timestamp);

        // Validate price against existing TWAP to detect manipulation
        TWAPLib.TWAPConfig memory config = _twapConfigs[pairId];
        require(
            state.validatePriceAgainstTWAP(currentPrice, currentTime, config.maxPriceDeviation),
            "TWAPModular: price deviation too high"
        );

        state.updateTWAP(currentPrice, currentTime);

        uint256 twapPrice = state.getTWAP(currentTime);
        emit TWAPUpdated(pairId, currentPrice, twapPrice, currentTime);
    }

    /**
     * @dev Get current TWAP price
     */
    function getTWAP(bytes32 pairId) external view validPair(pairId) returns (uint256) {
        return _twapStates[pairId].getTWAP(uint32(block.timestamp));
    }

    /**
     * @dev Get TWAP price for specific time window
     */
    function getTWAPForWindow(
        bytes32 pairId,
        uint32 startTime,
        uint32 endTime
    ) external view validPair(pairId) returns (uint256) {
        return _twapStates[pairId].getTWAPForWindow(startTime, endTime, uint32(block.timestamp));
    }

    /**
     * @dev Get TWAP statistics
     */
    function getTWAPStats(bytes32 pairId) external view validPair(pairId) returns (
        uint256 twapPrice,
        uint32 age,
        uint32 observationCount,
        bool isStale,
        uint256 healthScore
    ) {
        TWAPLib.TWAPState storage state = _twapStates[pairId];
        TWAPLib.TWAPConfig memory config = _twapConfigs[pairId];
        uint32 currentTime = uint32(block.timestamp);

        (twapPrice, age, observationCount, isStale) = state.getTWAPStats(currentTime);
        healthScore = state.getTWAPHealthScore(currentTime, config);
    }

    /**
     * @dev Get TWAP confidence interval
     */
    function getTWAPConfidence(
        bytes32 pairId,
        uint256[] memory recentPrices
    ) external view validPair(pairId) returns (uint256 lowerBound, uint256 upperBound) {
        return _twapStates[pairId].getTWAPConfidence(uint32(block.timestamp), recentPrices);
    }

    /**
     * @dev Calculate TWAP-based price impact
     */
    function calculateTWAPPriceImpact(
        bytes32 pairId,
        uint256 amountIn,
        uint256 amountOut
    ) external view validPair(pairId) returns (uint256) {
        return _twapStates[pairId].calculateTWAPPriceImpact(amountIn, amountOut, uint32(block.timestamp));
    }

    /**
     * @dev Reset TWAP state
     */
    function resetTWAP(
        bytes32 pairId,
        uint256 resetPrice
    ) external override onlyLeader validPair(pairId) {
        _twapStates[pairId].resetTWAP(resetPrice, uint32(block.timestamp));
        emit TWAPReset(pairId, resetPrice, uint32(block.timestamp));
    }

    /**
     * @dev Check if TWAP is stale
     */
    function isTWAPStale(bytes32 pairId) external view validPair(pairId) returns (bool) {
        return _twapStates[pairId].isTWAPStale(uint32(block.timestamp));
    }

    /**
     * @dev Get TWAP configuration
     */
    function getTWAPConfig(bytes32 pairId) external view validPair(pairId) returns (TWAPLib.TWAPConfig memory) {
        return _twapConfigs[pairId];
    }

    /**
     * @dev Update TWAP configuration
     */
    function updateTWAPConfig(
        bytes32 pairId,
        TWAPLib.TWAPConfig memory newConfig
    ) external override onlyLeader validPair(pairId) {
        require(TWAPLib.validateTWAPConfig(newConfig), "TWAPModular: invalid config");
        _twapConfigs[pairId] = newConfig;
    }

    /**
     * @dev Calculate TWAP efficiency score
     */
    function getTWAPEfficiency(bytes32 pairId) external view validPair(pairId) returns (uint256) {
        TWAPLib.TWAPState storage state = _twapStates[pairId];
        TWAPLib.TWAPConfig memory config = _twapConfigs[pairId];
        return state.calculateTWAPEfficiency(uint32(block.timestamp), config.observationPeriod);
    }

    /**
     * @dev Modular contract execution hooks
     */
    function beforeAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // Decode action data
        (bytes32 pairId, uint256 price) = abi.decode(data, (bytes32, uint256));

        // Update TWAP before action
        if (_twapConfigs[pairId].observationPeriod > 0) {
            TWAPLib.TWAPState storage state = _twapStates[pairId];
            uint32 currentTime = uint32(block.timestamp);

            // Check if update is needed
            if (currentTime - state.lastUpdateTime >= _twapConfigs[pairId].observationPeriod) {
                state.updateTWAP(price, currentTime);
                emit TWAPUpdated(pairId, price, state.getTWAP(currentTime), currentTime);
            }
        }

        return true;
    }

    function afterAction(bytes32 actionId, bytes memory data) external override onlyLeader returns (bool) {
        // TWAP updates are handled in beforeAction to ensure price accuracy
        return true;
    }

    function validateAction(bytes32 actionId, bytes memory data) external view override returns (bool) {
        (bytes32 pairId, uint256 price) = abi.decode(data, (bytes32, uint256));

        if (_twapConfigs[pairId].observationPeriod == 0) return true; // Allow if not initialized

        TWAPLib.TWAPState storage state = _twapStates[pairId];
        TWAPLib.TWAPConfig memory config = _twapConfigs[pairId];
        uint32 currentTime = uint32(block.timestamp);

        // Validate price against TWAP
        return state.validatePriceAgainstTWAP(price, currentTime, config.maxPriceDeviation);
    }

    // Required interface functions
    function beforeInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterInit(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeValidation(bytes memory data) external view override returns (bool) { return true; }
    function afterValidation(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterExecution(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterCleanup(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterTransfer(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterMint(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function beforeBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }
    function afterBurn(bytes memory data) external override onlyLeader returns (bool) { return true; }

    // Access control
    modifier onlyLeader() {
        require(msg.sender == IModularLeader(address(this)).getLeader(), "TWAPModular: only leader");
        _;
    }
}
