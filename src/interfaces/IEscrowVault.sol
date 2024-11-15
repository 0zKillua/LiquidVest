// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IEscrowVault - Interface for secure fund management
/// @notice Defines functionality for handling escrowed funds
interface IEscrowVault {
    struct EscrowBalance {
        uint256 amount;
        uint256 lockTimestamp;
        bool isLocked;
    }

    event FundsDeposited(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 amount
    );

    event FundsReleased(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 amount
    );

    event IssuerBalanceUpdated(
        address indexed issuer,
        uint256 newBalance
    );

    /// @notice Deposit funds for a specific receivable
    /// @param tokenId The ID of the receivable token
    function depositFunds(uint256 tokenId) external payable;

    /// @notice Release funds to the receivable holder
    /// @param tokenId The ID of the receivable token
    /// @param recipient The address to receive the funds
    /// @param amount The amount to release
    function releaseFunds(
        uint256 tokenId,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice Get the escrow balance for a receivable
    /// @param tokenId The ID of the receivable token
    function getEscrowBalance(
        uint256 tokenId
    ) external view returns (EscrowBalance memory);

    /// @notice Deposit general issuer balance
    function depositIssuerBalance() external payable;
}