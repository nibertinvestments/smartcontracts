// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './interfaces/IAetherweb3Oracle.sol';

/// @title Aetherweb3 Price Oracle
/// @notice Provides price feeds for tokens in the Aetherweb3 ecosystem
/// @dev Supports multiple price sources and aggregation
contract Aetherweb3Oracle is IAetherweb3Oracle {
    struct PriceData {
        uint256 price;      // Price in USD with 8 decimals
        uint256 timestamp;  // Last update timestamp
        uint256 confidence; // Confidence interval (0-10000, representing 0-100%)
    }

    struct PriceSource {
        address source;     // Address of the price source
        uint256 weight;     // Weight for aggregation (0-100)
        bool isActive;      // Whether this source is active
    }

    mapping(address => PriceData) public prices;
    mapping(address => PriceSource[]) public priceSources;
    mapping(address => bool) public authorizedUpdaters;

    address public owner;
    uint256 public constant MAX_SOURCES = 10;
    uint256 public constant PRICE_DECIMALS = 8;
    uint256 public constant MAX_PRICE_STALENESS = 24 hours;

    event PriceUpdated(address indexed token, uint256 price, uint256 timestamp);
    event SourceAdded(address indexed token, address indexed source, uint256 weight);
    event SourceRemoved(address indexed token, address indexed source);
    event UpdaterAuthorized(address indexed updater);
    event UpdaterRevoked(address indexed updater);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAuthorizedUpdater() {
        require(authorizedUpdaters[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }

    /// @inheritdoc IAetherweb3Oracle
    function getPrice(address token) external view override returns (uint256) {
        PriceData memory data = prices[token];
        require(data.timestamp > 0, "Price not available");
        require(block.timestamp - data.timestamp <= MAX_PRICE_STALENESS, "Price too stale");
        return data.price;
    }

    /// @inheritdoc IAetherweb3Oracle
    function getPriceWithConfidence(address token) external view override returns (uint256 price, uint256 confidence) {
        PriceData memory data = prices[token];
        require(data.timestamp > 0, "Price not available");
        require(block.timestamp - data.timestamp <= MAX_PRICE_STALENESS, "Price too stale");
        return (data.price, data.confidence);
    }

    /// @inheritdoc IAetherweb3Oracle
    function updatePrice(address token, uint256 price) external override onlyAuthorizedUpdater {
        require(price > 0, "Invalid price");

        prices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: 10000 // 100% confidence for direct updates
        });

        emit PriceUpdated(token, price, block.timestamp);
    }

    /// @inheritdoc IAetherweb3Oracle
    function updatePriceFromSource(
        address token,
        uint256 price,
        uint256 confidence,
        address source
    ) external override onlyAuthorizedUpdater {
        require(price > 0, "Invalid price");
        require(confidence <= 10000, "Invalid confidence");

        // Verify source is authorized for this token
        PriceSource[] memory sources = priceSources[token];
        bool sourceAuthorized = false;
        uint256 sourceWeight = 0;

        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].source == source && sources[i].isActive) {
                sourceAuthorized = true;
                sourceWeight = sources[i].weight;
                break;
            }
        }

        require(sourceAuthorized, "Source not authorized");

        // Update price with weighted confidence
        uint256 weightedConfidence = (confidence * sourceWeight) / 100;

        prices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: weightedConfidence
        });

        emit PriceUpdated(token, price, block.timestamp);
    }

    /// @inheritdoc IAetherweb3Oracle
    function addPriceSource(
        address token,
        address source,
        uint256 weight
    ) external override onlyOwner {
        require(weight > 0 && weight <= 100, "Invalid weight");
        require(priceSources[token].length < MAX_SOURCES, "Too many sources");

        // Check if source already exists
        PriceSource[] storage sources = priceSources[token];
        for (uint256 i = 0; i < sources.length; i++) {
            require(sources[i].source != source, "Source already exists");
        }

        sources.push(PriceSource({
            source: source,
            weight: weight,
            isActive: true
        }));

        emit SourceAdded(token, source, weight);
    }

    /// @inheritdoc IAetherweb3Oracle
    function removePriceSource(address token, address source) external override onlyOwner {
        PriceSource[] storage sources = priceSources[token];
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].source == source) {
                sources[i].isActive = false;
                emit SourceRemoved(token, source);
                return;
            }
        }
        revert("Source not found");
    }

    /// @inheritdoc IAetherweb3Oracle
    function getPriceSources(address token) external view override returns (address[] memory, uint256[] memory) {
        PriceSource[] memory sources = priceSources[token];
        uint256 activeCount = 0;

        // Count active sources
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                activeCount++;
            }
        }

        address[] memory activeSources = new address[](activeCount);
        uint256[] memory weights = new uint256[](activeCount);

        uint256 index = 0;
        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].isActive) {
                activeSources[index] = sources[i].source;
                weights[index] = sources[i].weight;
                index++;
            }
        }

        return (activeSources, weights);
    }

    /// @inheritdoc IAetherweb3Oracle
    function isPriceStale(address token) external view override returns (bool) {
        PriceData memory data = prices[token];
        if (data.timestamp == 0) return true;
        return block.timestamp - data.timestamp > MAX_PRICE_STALENESS;
    }

    /// @inheritdoc IAetherweb3Oracle
    function authorizeUpdater(address updater) external override onlyOwner {
        authorizedUpdaters[updater] = true;
        emit UpdaterAuthorized(updater);
    }

    /// @inheritdoc IAetherweb3Oracle
    function revokeUpdater(address updater) external override onlyOwner {
        authorizedUpdaters[updater] = false;
        emit UpdaterRevoked(updater);
    }

    /// @inheritdoc IAetherweb3Oracle
    function transferOwnership(address newOwner) external override onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
}
