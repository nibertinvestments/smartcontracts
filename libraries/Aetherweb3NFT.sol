// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";
import "./Aetherweb3Safety.sol";

/**
 * @title Aetherweb3NFT
 * @dev NFT utility library for marketplace operations and NFT management
 * @notice Provides NFT pricing, rarity calculations, marketplace fees, and NFT utilities
 */
library Aetherweb3NFT {
    using Aetherweb3Math for uint256;

    // NFT collection information
    struct NFTCollection {
        address contractAddress;   // NFT contract address
        string name;              // Collection name
        string symbol;            // Collection symbol
        uint256 totalSupply;      // Total supply
        uint256 maxSupply;        // Maximum supply
        uint256 floorPrice;       // Floor price
        uint256 volume24h;        // 24h volume
        uint256 marketCap;        // Market capitalization
        uint256 rarityScore;      // Collection rarity score
        bool isVerified;         // Verified collection
        bool isActive;           // Active collection
    }

    // NFT token information
    struct NFTToken {
        uint256 tokenId;          // Token ID
        address owner;            // Current owner
        address creator;          // Original creator
        uint256 royaltyFee;       // Royalty fee percentage
        uint256 rarityScore;      // Token rarity score
        uint256 lastPrice;        // Last sale price
        uint256 listingPrice;     // Current listing price
        uint256 createdAt;        // Creation timestamp
        uint256 lastTransfer;     // Last transfer timestamp
        string metadataURI;       // Metadata URI
        TokenStatus status;       // Token status
    }

    // Token status enumeration
    enum TokenStatus {
        NOT_MINTED,
        LISTED,
        AUCTION,
        SOLD,
        TRANSFERRED,
        BURNED
    }

    // Marketplace listing
    struct MarketplaceListing {
        uint256 listingId;        // Unique listing ID
        address seller;           // Seller address
        address nftContract;      // NFT contract address
        uint256 tokenId;          // Token ID
        uint256 price;            // Listing price
        uint256 auctionEndTime;   // Auction end time (0 for fixed price)
        uint256 highestBid;       // Highest bid amount
        address highestBidder;    // Highest bidder address
        uint256 minimumBid;       // Minimum bid amount
        ListingStatus status;     // Listing status
        ListingType listingType;  // Listing type
    }

    // Listing status enumeration
    enum ListingStatus {
        ACTIVE,
        SOLD,
        CANCELLED,
        EXPIRED
    }

    // Listing type enumeration
    enum ListingType {
        FIXED_PRICE,
        AUCTION,
        DUTCH_AUCTION
    }

    // NFT marketplace configuration
    struct MarketplaceConfig {
        uint256 marketplaceFee;   // Marketplace fee percentage
        uint256 minimumListingPrice; // Minimum listing price
        uint256 maximumListingPrice; // Maximum listing price
        uint256 auctionDuration;  // Default auction duration
        uint256 bidIncrement;     // Minimum bid increment
        bool royaltiesEnabled;    // Royalties enabled
        bool auctionsEnabled;     // Auctions enabled
        bool dutchAuctionsEnabled; // Dutch auctions enabled
    }

    // NFT trading statistics
    struct NFTTradingStats {
        uint256 totalVolume;      // Total trading volume
        uint256 totalTransactions; // Total transactions
        uint256 uniqueTraders;    // Unique traders
        uint256 averagePrice;     // Average sale price
        uint256 floorPrice;       // Floor price
        uint256 highestSale;      // Highest sale price
        uint256 lowestSale;       // Lowest sale price
        uint256 volume24h;        // 24h volume
        uint256 transactions24h;  // 24h transactions
    }

    /**
     * @dev Calculates NFT rarity score based on traits
     * @param traitCounts Array of trait counts for each trait type
     * @param totalSupply Total supply of NFTs
     * @return rarityScore Calculated rarity score
     */
    function calculateRarityScore(
        uint256[] memory traitCounts,
        uint256 totalSupply
    ) internal pure returns (uint256 rarityScore) {
        if (traitCounts.length == 0 || totalSupply == 0) return 0;

        uint256 totalRarity = 0;
        for (uint256 i = 0; i < traitCounts.length; i++) {
            if (traitCounts[i] == 0) continue;
            uint256 traitRarity = totalSupply * Aetherweb3Math.WAD / traitCounts[i];
            totalRarity += traitRarity;
        }

        rarityScore = totalRarity / traitCounts.length;
    }

    /**
     * @dev Calculates NFT floor price based on recent sales
     * @param recentSales Array of recent sale prices
     * @param percentile Percentile for floor calculation (e.g., 10 for 10th percentile)
     * @return floorPrice Calculated floor price
     */
    function calculateFloorPrice(
        uint256[] memory recentSales,
        uint256 percentile
    ) internal pure returns (uint256 floorPrice) {
        if (recentSales.length == 0) return 0;

        // Sort sales in ascending order (simplified bubble sort for small arrays)
        uint256[] memory sortedSales = new uint256[](recentSales.length);
        for (uint256 i = 0; i < recentSales.length; i++) {
            sortedSales[i] = recentSales[i];
        }

        for (uint256 i = 0; i < sortedSales.length - 1; i++) {
            for (uint256 j = 0; j < sortedSales.length - i - 1; j++) {
                if (sortedSales[j] > sortedSales[j + 1]) {
                    uint256 temp = sortedSales[j];
                    sortedSales[j] = sortedSales[j + 1];
                    sortedSales[j + 1] = temp;
                }
            }
        }

        uint256 index = (sortedSales.length * percentile) / 100;
        if (index >= sortedSales.length) {
            index = sortedSales.length - 1;
        }

        floorPrice = sortedSales[index];
    }

    /**
     * @dev Calculates marketplace fees for NFT transaction
     * @param salePrice Sale price of NFT
     * @param royaltyFee Royalty fee percentage
     * @param marketplaceFee Marketplace fee percentage
     * @return totalFees Total fees breakdown
     */
    function calculateMarketplaceFees(
        uint256 salePrice,
        uint256 royaltyFee,
        uint256 marketplaceFee
    ) internal pure returns (
        uint256 totalFees,
        uint256 royaltyAmount,
        uint256 marketplaceAmount,
        uint256 sellerReceives
    ) {
        royaltyAmount = salePrice.wmul(royaltyFee);
        marketplaceAmount = salePrice.wmul(marketplaceFee);
        totalFees = royaltyAmount + marketplaceAmount;
        sellerReceives = salePrice - totalFees;
    }

    /**
     * @dev Calculates NFT collection market cap
     * @param floorPrice Floor price of collection
     * @param totalSupply Total supply of NFTs
     * @return marketCap Calculated market capitalization
     */
    function calculateMarketCap(
        uint256 floorPrice,
        uint256 totalSupply
    ) internal pure returns (uint256 marketCap) {
        marketCap = floorPrice * totalSupply;
    }

    /**
     * @dev Validates NFT listing parameters
     * @param listing Marketplace listing
     * @param config Marketplace configuration
     * @return isValid True if listing is valid
     */
    function validateNFTListing(
        MarketplaceListing memory listing,
        MarketplaceConfig memory config
    ) internal pure returns (bool isValid) {
        if (listing.seller == address(0)) return false;
        if (listing.nftContract == address(0)) return false;
        if (listing.price < config.minimumListingPrice) return false;
        if (listing.price > config.maximumListingPrice) return false;
        if (listing.listingType == ListingType.AUCTION && !config.auctionsEnabled) return false;
        if (listing.listingType == ListingType.DUTCH_AUCTION && !config.dutchAuctionsEnabled) return false;
        return true;
    }

    /**
     * @dev Calculates auction price for Dutch auction
     * @param startPrice Starting price
     * @param endPrice Ending price
     * @param startTime Auction start time
     * @param endTime Auction end time
     * @param currentTime Current time
     * @return currentPrice Current auction price
     */
    function calculateDutchAuctionPrice(
        uint256 startPrice,
        uint256 endPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 currentTime
    ) internal pure returns (uint256 currentPrice) {
        if (currentTime >= endTime) return endPrice;
        if (currentTime <= startTime) return startPrice;

        uint256 timeElapsed = currentTime - startTime;
        uint256 totalDuration = endTime - startTime;

        if (totalDuration == 0) return startPrice;

        uint256 priceDrop = startPrice - endPrice;
        uint256 priceReduction = priceDrop * timeElapsed / totalDuration;

        currentPrice = startPrice - priceReduction;
    }

    /**
     * @dev Calculates NFT trading volume statistics
     * @param salePrices Array of sale prices
     * @param timeWindows Array of time windows for each sale
     * @param currentTime Current timestamp
     * @return stats Trading statistics
     */
    function calculateTradingStats(
        uint256[] memory salePrices,
        uint256[] memory timeWindows,
        uint256 currentTime
    ) internal pure returns (NFTTradingStats memory stats) {
        if (salePrices.length == 0) return stats;

        uint256 totalVolume = 0;
        uint256 minPrice = type(uint256).max;
        uint256 maxPrice = 0;
        uint256 volume24h = 0;
        uint256 transactions24h = 0;

        for (uint256 i = 0; i < salePrices.length; i++) {
            totalVolume += salePrices[i];

            if (salePrices[i] < minPrice) minPrice = salePrices[i];
            if (salePrices[i] > maxPrice) maxPrice = salePrices[i];

            // Check if sale is within 24 hours
            if (currentTime - timeWindows[i] <= 24 hours) {
                volume24h += salePrices[i];
                transactions24h++;
            }
        }

        stats.totalVolume = totalVolume;
        stats.totalTransactions = salePrices.length;
        stats.averagePrice = totalVolume / salePrices.length;
        stats.floorPrice = minPrice;
        stats.highestSale = maxPrice;
        stats.lowestSale = minPrice == type(uint256).max ? 0 : minPrice;
        stats.volume24h = volume24h;
        stats.transactions24h = transactions24h;
    }

    /**
     * @dev Calculates NFT portfolio value
     * @param tokenIds Array of token IDs
     * @param floorPrices Array of floor prices for each token
     * @param ownedQuantities Array of owned quantities
     * @return totalValue Total portfolio value
     */
    function calculatePortfolioValue(
        uint256[] memory tokenIds,
        uint256[] memory floorPrices,
        uint256[] memory ownedQuantities
    ) internal pure returns (uint256 totalValue) {
        require(
            tokenIds.length == floorPrices.length &&
            floorPrices.length == ownedQuantities.length,
            "Array lengths must match"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            totalValue += floorPrices[i] * ownedQuantities[i];
        }
    }

    /**
     * @dev Validates NFT collection parameters
     * @param collection NFT collection
     * @return isValid True if collection is valid
     */
    function validateNFTCollection(
        NFTCollection memory collection
    ) internal pure returns (bool isValid) {
        if (collection.contractAddress == address(0)) return false;
        if (bytes(collection.name).length == 0) return false;
        if (bytes(collection.symbol).length == 0) return false;
        if (collection.totalSupply > collection.maxSupply) return false;
        return true;
    }

    /**
     * @dev Calculates NFT bid increment
     * @param currentBid Current highest bid
     * @param minimumIncrement Minimum increment percentage
     * @return nextBid Minimum next bid amount
     */
    function calculateBidIncrement(
        uint256 currentBid,
        uint256 minimumIncrement
    ) internal pure returns (uint256 nextBid) {
        uint256 increment = currentBid.wmul(minimumIncrement);
        nextBid = currentBid + increment;
    }

    /**
     * @dev Checks if auction has ended
     * @param listing Marketplace listing
     * @param currentTime Current timestamp
     * @return hasEnded True if auction has ended
     */
    function hasAuctionEnded(
        MarketplaceListing memory listing,
        uint256 currentTime
    ) internal pure returns (bool hasEnded) {
        return listing.auctionEndTime > 0 && currentTime >= listing.auctionEndTime;
    }

    /**
     * @dev Calculates NFT collection rarity distribution
     * @param rarityScores Array of rarity scores
     * @return distribution Rarity distribution percentages
     */
    function calculateRarityDistribution(
        uint256[] memory rarityScores
    ) internal pure returns (uint256[] memory distribution) {
        if (rarityScores.length == 0) return new uint256[](0);

        // Define rarity tiers (Common, Uncommon, Rare, Epic, Legendary)
        uint256[] memory tierThresholds = new uint256[](4);
        tierThresholds[0] = 25 * Aetherweb3Math.WAD / 100;  // 25% - Common
        tierThresholds[1] = 50 * Aetherweb3Math.WAD / 100;  // 50% - Uncommon
        tierThresholds[2] = 75 * Aetherweb3Math.WAD / 100;  // 75% - Rare
        tierThresholds[3] = 95 * Aetherweb3Math.WAD / 100;  // 95% - Epic

        distribution = new uint256[](5); // 5 tiers

        for (uint256 i = 0; i < rarityScores.length; i++) {
            if (rarityScores[i] <= tierThresholds[0]) {
                distribution[0]++; // Common
            } else if (rarityScores[i] <= tierThresholds[1]) {
                distribution[1]++; // Uncommon
            } else if (rarityScores[i] <= tierThresholds[2]) {
                distribution[2]++; // Rare
            } else if (rarityScores[i] <= tierThresholds[3]) {
                distribution[3]++; // Epic
            } else {
                distribution[4]++; // Legendary
            }
        }

        // Convert to percentages
        for (uint256 i = 0; i < distribution.length; i++) {
            distribution[i] = distribution[i] * Aetherweb3Math.WAD / rarityScores.length;
        }
    }

    /**
     * @dev Calculates NFT wash trading score
     * @param transactions Array of transaction data (buyer, seller, price, timestamp)
     * @param timeWindow Time window to analyze
     * @return washScore Wash trading score (0-100, higher = more suspicious)
     */
    function calculateWashTradingScore(
        address[] memory buyers,
        address[] memory sellers,
        uint256[] memory prices,
        uint256[] memory timestamps,
        uint256 timeWindow
    ) internal pure returns (uint256 washScore) {
        if (buyers.length != sellers.length ||
            sellers.length != prices.length ||
            prices.length != timestamps.length) return 0;

        uint256 suspiciousTransactions = 0;

        for (uint256 i = 0; i < buyers.length; i++) {
            for (uint256 j = i + 1; j < buyers.length; j++) {
                // Check for round-trip trading
                if ((buyers[i] == sellers[j] && sellers[i] == buyers[j]) ||
                    (buyers[i] == buyers[j] && sellers[i] == sellers[j])) {

                    // Check if transactions are within time window
                    uint256 timeDiff = timestamps[j] > timestamps[i] ?
                        timestamps[j] - timestamps[i] :
                        timestamps[i] - timestamps[j];

                    if (timeDiff <= timeWindow) {
                        // Check for similar prices
                        uint256 priceDiff = prices[j] > prices[i] ?
                            prices[j] - prices[i] :
                            prices[i] - prices[j];

                        uint256 avgPrice = (prices[i] + prices[j]) / 2;
                        uint256 priceVariation = priceDiff * Aetherweb3Math.WAD / avgPrice;

                        if (priceVariation <= Aetherweb3Math.WAD / 10) { // 10% variation
                            suspiciousTransactions++;
                        }
                    }
                }
            }
        }

        washScore = suspiciousTransactions * 100 / buyers.length;
    }

    /**
     * @dev Calculates NFT holder distribution
     * @param holderCounts Array of holder counts per quantity tier
     * @return concentration Holder concentration index
     */
    function calculateHolderConcentration(
        uint256[] memory holderCounts
    ) internal pure returns (uint256 concentration) {
        if (holderCounts.length == 0) return 0;

        uint256 totalHolders = 0;
        uint256 weightedSum = 0;

        for (uint256 i = 0; i < holderCounts.length; i++) {
            totalHolders += holderCounts[i];
            weightedSum += holderCounts[i] * (i + 1); // Weight by quantity held
        }

        if (totalHolders == 0) return 0;

        uint256 averageHolding = weightedSum / totalHolders;
        concentration = averageHolding * Aetherweb3Math.WAD / holderCounts.length;
    }
}
