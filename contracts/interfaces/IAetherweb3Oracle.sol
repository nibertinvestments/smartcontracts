// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Aetherweb3 Oracle Interface
/// @notice Interface for price oracle functionality
interface IAetherweb3Oracle {
    /// @notice Get the current price for a token
    /// @param token The token address
    /// @return The price in USD with 8 decimals
    function getPrice(address token) external view returns (uint256);

    /// @notice Get the current price with confidence interval
    /// @param token The token address
    /// @return price The price in USD with 8 decimals
    /// @return confidence The confidence level (0-10000)
    function getPriceWithConfidence(address token) external view returns (uint256 price, uint256 confidence);

    /// @notice Update the price for a token
    /// @param token The token address
    /// @param price The new price in USD with 8 decimals
    function updatePrice(address token, uint256 price) external;

    /// @notice Update price from a specific source
    /// @param token The token address
    /// @param price The new price in USD with 8 decimals
    /// @param confidence The confidence level (0-10000)
    /// @param source The source address
    function updatePriceFromSource(
        address token,
        uint256 price,
        uint256 confidence,
        address source
    ) external;

    /// @notice Add a price source for a token
    /// @param token The token address
    /// @param source The source address
    /// @param weight The weight for this source (0-100)
    function addPriceSource(address token, address source, uint256 weight) external;

    /// @notice Remove a price source for a token
    /// @param token The token address
    /// @param source The source address
    function removePriceSource(address token, address source) external;

    /// @notice Get all active price sources for a token
    /// @param token The token address
    /// @return sources Array of source addresses
    /// @return weights Array of source weights
    function getPriceSources(address token) external view returns (address[] memory sources, uint256[] memory weights);

    /// @notice Check if a token's price is stale
    /// @param token The token address
    /// @return True if the price is stale
    function isPriceStale(address token) external view returns (bool);

    /// @notice Authorize an address to update prices
    /// @param updater The address to authorize
    function authorizeUpdater(address updater) external;

    /// @notice Revoke authorization from an updater
    /// @param updater The address to revoke
    function revokeUpdater(address updater) external;

    /// @notice Transfer ownership of the oracle
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external;
}
