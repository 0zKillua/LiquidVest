
/*
DiscountMath library provides:
Time-based discount calculations using continuous compounding
Yield calculations for investors
Early exit penalty calculations
Minimum holding period discount calculations
Discount validation functions

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title DiscountMath - Library for discount calculations
/// @notice Implements time-based discounting with risk adjustments
library DiscountMath {
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant PRECISION = 1e18;
    
    /// @notice Calculate time-based discount
    /// @param faceValue The full amount to be paid at maturity
    /// @param timeRemaining Seconds until maturity
    /// @param effectiveRate Combined base rate and risk premium in basis points
    /// @param annualPeriod Standard period for rate calculation (usually 1 year)
    /// @return discountedPrice The calculated present value
    function calculateTimeDiscount(
        uint256 faceValue,
        uint256 timeRemaining,
        uint256 effectiveRate,
        uint256 annualPeriod
    ) internal pure returns (uint256) {
        // Convert basis points to decimal (1 bp = 0.01%)
        uint256 rate = (effectiveRate * PRECISION) / 10000;
        
        // Calculate time factor
        uint256 timeFactor = (timeRemaining * PRECISION) / annualPeriod;
        
        // Calculate discount factor using continuous compounding
        // PV = FV * e^(-r*t)
        uint256 discountFactor = _exponentialDecay(rate, timeFactor);
        
        // Apply discount factor to face value
        return (faceValue * discountFactor) / PRECISION;
    }

    /// @notice Calculate the yield for a given purchase
    /// @param purchasePrice The amount paid for the receivable
    /// @param faceValue The full amount at maturity
    /// @param timeRemaining Seconds until maturity
    /// @return yieldRate Annual yield rate in basis points
    function calculateYield(
        uint256 purchasePrice,
        uint256 faceValue,
        uint256 timeRemaining
    ) internal pure returns (uint256) {
        require(purchasePrice < faceValue, "Invalid price");
        
        // Calculate raw yield
        uint256 yield = faceValue - purchasePrice;
        
        // Annualize the yield
        uint256 annualizedYield = (yield * SECONDS_PER_YEAR * PRECISION) / 
            (purchasePrice * timeRemaining);
        
        // Convert to basis points
        return (annualizedYield * 10000) / PRECISION;
    }

    /// @notice Calculate exponential decay for continuous compounding
    /// @param rate The decay rate
    /// @param time The time factor
    /// @return The decay factor
    function _exponentialDecay(
        uint256 rate,
        uint256 time
    ) private pure returns (uint256) {
        // Using Taylor series approximation for e^(-r*t)
        uint256 rateTimeProduct = (rate * time) / PRECISION;
        
        uint256 decay = PRECISION; // First term: 1
        uint256 term = PRECISION; // Initialize term
        
        // Calculate first 4 terms of Taylor series
        for (uint256 i = 1; i <= 4; i++) {
            term = (term * rateTimeProduct) / (i * PRECISION);
            if (i % 2 == 1) {
                decay -= term;
            } else {
                decay += term;
            }
        }
        
        return decay;
    }

    /// @notice Calculate early exit penalty
    /// @param currentPrice Current discounted price
    /// @param penaltyRate Penalty rate in basis points
    /// @return penalty The calculated penalty amount
    function calculateEarlyExitPenalty(
        uint256 currentPrice,
        uint256 penaltyRate
    ) internal pure returns (uint256) {
        return (currentPrice * penaltyRate) / 10000;
    }

    /// @notice Calculate minimum holding period discount
    /// @param faceValue The full amount at maturity
    /// @param minHoldingPeriod Minimum holding period in seconds
    /// @param baseRate Base discount rate in basis points
    /// @return minDiscount The minimum discount amount
    function calculateMinHoldingDiscount(
        uint256 faceValue,
        uint256 minHoldingPeriod,
        uint256 baseRate
    ) internal pure returns (uint256) {
        uint256 minTimeFactor = (minHoldingPeriod * PRECISION) / SECONDS_PER_YEAR;
        uint256 rateInPrecision = (baseRate * PRECISION) / 10000;
        
        return (faceValue * rateInPrecision * minTimeFactor) / (PRECISION * PRECISION);
    }

    /// @notice Validate discount parameters
    /// @param discountedPrice The calculated discounted price
    /// @param faceValue The full amount at maturity
    /// @param maxDiscount Maximum allowed discount percentage
    /// @return bool Whether the discount is valid
    function validateDiscount(
        uint256 discountedPrice,
        uint256 faceValue,
        uint256 maxDiscount
    ) internal pure returns (bool) {
        uint256 discount = faceValue - discountedPrice;
        uint256 discountPercentage = (discount * 10000) / faceValue;
        
        return discountPercentage <= maxDiscount;
    }
}