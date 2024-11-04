// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IDiscountCalculator - Interface for discount calculations
/// @notice Defines functions for calculating receivable discounts
interface IDiscountCalculator {
    event RiskPremiumUpdated(uint8 tier, uint256 premium);

    /// @notice Calculate the discounted price of a receivable
    /// @param faceValue The full amount to be paid at maturity
    /// @param timeRemaining Seconds until maturity
    /// @param riskTier Risk classification of the receivable
    function calculateDiscountedPrice(
        uint256 faceValue,
        uint256 timeRemaining,
        uint8 riskTier
    ) external view returns (uint256);

    /// @notice Update the risk premium for a specific tier
    /// @param tier The risk tier to update
    /// @param premium The new premium in basis points
    function updateRiskPremium(
        uint8 tier,
        uint256 premium
    ) external;

    /// @notice Get the current effective discount rate for a risk tier
    /// @param riskTier The risk tier to query
    function getEffectiveRate(
        uint8 riskTier
    ) external view returns (uint256);
}