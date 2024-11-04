// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/IDiscountCalculator.sol";



/*
MarketRouter contract provides:
Price discovery across both primary and secondary markets
Best execution routing for trades
Fallback mechanisms if one market is unavailable
Administrative functions for updating market addresses

*/ 


/// @title MarketRouter - Routes trades between markets for best execution
/// @notice Provides routing and price discovery across primary and secondary markets
contract MarketRouter is Ownable, ReentrancyGuard {
    IMarket public primaryMarket;
    IMarket public secondaryMarket;
    IDiscountCalculator public calculator;

    struct MarketPrice {
        uint256 price;
        bool isAvailable;
        address market;
    }

    event BestPriceExecution(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed market,
        uint256 executionPrice
    );

    event MarketUpdated(
        address indexed market,
        bool isPrimary,
        bool isActive
    );

    constructor(
        address _primaryMarket,
        address _secondaryMarket,
        address _calculator
    ) {
        primaryMarket = IMarket(_primaryMarket);
        secondaryMarket = IMarket(_secondaryMarket);
        calculator = IDiscountCalculator(_calculator);
    }

    /// @notice Finds the best available price for a receivable across markets
    /// @param tokenId The ID of the receivable to price check
    /// @return bestPrice The lowest available price
    /// @return marketAddress The address of the market offering the best price
    function findBestPrice(
        uint256 tokenId
    ) public view returns (uint256 bestPrice, address marketAddress) {
        MarketPrice memory primaryPrice = _getPrimaryMarketPrice(tokenId);
        MarketPrice memory secondaryPrice = _getSecondaryMarketPrice(tokenId);

        if (!primaryPrice.isAvailable && !secondaryPrice.isAvailable) {
            revert("No available listings");
        }

        if (primaryPrice.isAvailable && !secondaryPrice.isAvailable) {
            return (primaryPrice.price, primaryPrice.market);
        }

        if (!primaryPrice.isAvailable && secondaryPrice.isAvailable) {
            return (secondaryPrice.price, secondaryPrice.market);
        }

        // Compare prices if available in both markets
        if (primaryPrice.price <= secondaryPrice.price) {
            return (primaryPrice.price, primaryPrice.market);
        } else {
            return (secondaryPrice.price, secondaryPrice.market);
        }
    }

    /// @notice Executes a purchase at the best available price
    /// @param tokenId The ID of the receivable to purchase
    function executeBestPrice(
        uint256 tokenId
    ) external payable nonReentrant {
        (uint256 bestPrice, address market) = findBestPrice(tokenId);
        require(msg.value >= bestPrice, "Insufficient payment");

        // Execute the trade on the appropriate market
        if (market == address(primaryMarket)) {
            primaryMarket.buyReceivable{value: msg.value}(tokenId);
        } else {
            secondaryMarket.buySecondaryListing{value: msg.value}(tokenId);
        }

        emit BestPriceExecution(tokenId, msg.sender, market, msg.value);
    }

    /// @notice Gets the price from the primary market
    /// @param tokenId The receivable token ID
    /// @return MarketPrice struct with price and availability
    function _getPrimaryMarketPrice(
        uint256 tokenId
    ) internal view returns (MarketPrice memory) {
        try primaryMarket.getListing(tokenId) returns (
            address seller,
            uint256 price,
            bool isActive
        ) {
            return MarketPrice({
                price: price,
                isAvailable: isActive,
                market: address(primaryMarket)
            });
        } catch {
            return MarketPrice({
                price: 0,
                isAvailable: false,
                market: address(0)
            });
        }
    }

    /// @notice Gets the price from the secondary market
    /// @param tokenId The receivable token ID
    /// @return MarketPrice struct with price and availability
    function _getSecondaryMarketPrice(
        uint256 tokenId
    ) internal view returns (MarketPrice memory) {
        try secondaryMarket.getListing(tokenId) returns (
            address seller,
            uint256 price,
            bool isActive
        ) {
            return MarketPrice({
                price: price,
                isAvailable: isActive,
                market: address(secondaryMarket)
            });
        } catch {
            return MarketPrice({
                price: 0,
                isAvailable: false,
                market: address(0)
            });
        }
    }

    /// @notice Updates market addresses
    /// @param market The new market address
    /// @param isPrimary Whether this is the primary market
    function updateMarket(
        address market,
        bool isPrimary
    ) external onlyOwner {
        require(market != address(0), "Invalid market address");
        
        if (isPrimary) {
            primaryMarket = IMarket(market);
        } else {
            secondaryMarket = IMarket(market);
        }

        emit MarketUpdated(market, isPrimary, true);
    }

    /// @notice Updates the calculator address
    /// @param _calculator The new calculator address
    function updateCalculator(address _calculator) external onlyOwner {
        require(_calculator != address(0), "Invalid calculator address");
        calculator = IDiscountCalculator(_calculator);
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}