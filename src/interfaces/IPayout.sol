// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IPayout - Interface for payout management
/// @notice Defines functionality for handling receivable payouts
interface IPayout {
    event PayoutProcessed(
        uint256 indexed tokenId,
        address indexed receiver,
        uint256 amount,
        uint256 timestamp
    );

    event CollateralDeposited(
        address indexed issuer,
        uint256 amount
    );

    event CollateralWithdrawn(
        address indexed issuer,
        uint256 amount
    );

    /// @notice Process payout for a matured receivable
    /// @param tokenId The ID of the receivable token
    function processPayout(uint256 tokenId) external;

    /// @notice Deposit collateral for issuing receivables
    function depositCollateral() external payable;

    /// @notice Withdraw available collateral
    /// @param amount Amount of collateral to withdraw
    function withdrawCollateral(uint256 amount) external;

    /// @notice Get the collateral balance for an issuer
    /// @param issuer Address of the issuer
    function getCollateralBalance(
        address issuer
    ) external view returns (uint256);
}