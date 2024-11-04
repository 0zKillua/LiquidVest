// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IRiskManager - Interface for risk management
/// @notice Defines functionality for risk assessment and management
interface IRiskManager {
    struct RiskParameters {
        uint256 maxFaceValue;
        uint256 minVestingPeriod;
        uint256 maxVestingPeriod;
        bool isActive;
    }

    event RiskTierParametersUpdated(
        uint8 tier,
        uint256 maxFaceValue,
        uint256 minVestingPeriod,
        uint256 maxVestingPeriod
    );

    event IssuerRiskTierUpdated(
        address indexed issuer,
        uint8 tier
    );

    /// @notice Validate if a receivable meets risk parameters
    /// @param faceValue The face value of the receivable
    /// @param vestingPeriod The vesting period in seconds
    /// @param riskTier The proposed risk tier
    function validateReceivable(
        uint256 faceValue,
        uint256 vestingPeriod,
        uint8 riskTier
    ) external view returns (bool);

    /// @notice Update risk parameters for a tier
    /// @param tier The risk tier to update
    /// @param params The new risk parameters
    function updateRiskTierParameters(
        uint8 tier,
        RiskParameters calldata params
    ) external;

    /// @notice Set the default risk tier for an issuer
    /// @param issuer The issuer address
    /// @param tier The risk tier to assign
    function setIssuerRiskTier(
        address issuer,
        uint8 tier
    ) external;

    /// @notice Get the current risk tier for an issuer
    /// @param issuer The issuer address
    function getIssuerRiskTier(
        address issuer
    ) external view returns (uint8);
}