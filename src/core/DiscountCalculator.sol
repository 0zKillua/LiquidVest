// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../libraries/DiscountMath.sol";

/// @title DiscountCalculator - Calculates discounted prices for receivables
/// @notice Provides pricing logic based on time and risk tiers
contract DiscountCalculator is Ownable {
    using DiscountMath for uint256;

    // Risk premium in basis points (1 = 0.01%)
    mapping(uint8 => uint256) public riskPremiums;
    
    uint256 public constant BASE_DISCOUNT_RATE = 500; // 5% = 500 basis points
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    event RiskPremiumUpdated(uint8 tier, uint256 premium);

    constructor() {
        // Initialize default risk premiums
        riskPremiums[0] = 0;     // LOW: +0%
        riskPremiums[1] = 200;   // MEDIUM: +2%
        riskPremiums[2] = 500;   // HIGH: +5%
    }

    /// @notice Calculates the discounted price of a receivable
    /// @param faceValue The full amount to be paid at maturity
    /// @param timeRemaining Seconds until maturity
    /// @param riskTier Risk classification of the receivable
    /// @return price The calculated discounted price
    function calculateDiscountedPrice(
        uint256 faceValue,
        uint256 timeRemaining,
        uint8 riskTier
    ) public view returns (uint256) {
        require(faceValue > 0, "Face value must be positive");
        require(timeRemaining > 0, "Time remaining must be positive");
        require(riskTier <= 2, "Invalid risk tier");

        uint256 effectiveRate = BASE_DISCOUNT_RATE + riskPremiums[riskTier];
        
        return DiscountMath.calculateTimeDiscount(
            faceValue,
            timeRemaining,
            effectiveRate,
            SECONDS_PER_YEAR
        );
    }

    /// @notice Updates the risk premium for a specific tier
    /// @param tier The risk tier to update
    /// @param premium The new premium in basis points
    function updateRiskPremium(
        uint8 tier,
        uint256 premium
    ) external onlyOwner {
        require(tier <= 2, "Invalid risk tier");
        require(premium <= 2000, "Premium too high"); // Max 20%
        
        riskPremiums[tier] = premium;
        emit RiskPremiumUpdated(tier, premium);
    }

    /// @notice Gets the current effective discount rate for a risk tier
    /// @param riskTier The risk tier to query
    /// @return The total discount rate in basis points
    function getEffectiveRate(
        uint8 riskTier
    ) external view returns (uint256) {
        require(riskTier <= 2, "Invalid risk tier");
        return BASE_DISCOUNT_RATE + riskPremiums[riskTier];
    }
}