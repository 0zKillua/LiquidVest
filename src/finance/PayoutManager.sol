// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBaseReceivable.sol";
import "./interfaces/IEscrowVault.sol";


/*
PayoutManager contract provides:
Maturity settlement processing
Collateral management for issuers
Grace period handling
Security features including reentrancy protection and pausability
Administrative functions for parameter updates
contract works in conjunction with an EscrowVault to ensure secure handling of funds and proper settlement of matured receivables.

*/
/// @title PayoutManager - Handles receivable maturity and settlements
/// @notice Manages the payout process for matured receivables
contract PayoutManager is ReentrancyGuard, Ownable, Pausable {
    IBaseReceivable public immutable receivableToken;
    IEscrowVault public escrowVault;
    
    struct PayoutStatus {
        bool isPaid;
        uint256 paidAmount;
        uint256 paidTimestamp;
        address payoutReceiver;
    }
    
    mapping(uint256 => PayoutStatus) public payouts;
    mapping(address => uint256) public issuerCollateral;
    
    uint256 public constant GRACE_PERIOD = 3 days;
    uint256 public collateralRate = 1000; // 10% in basis points
    
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
    
    constructor(address _receivableToken, address _escrowVault) {
        receivableToken = IBaseReceivable(_receivableToken);
        escrowVault = IEscrowVault(_escrowVault);
    }

    /// @notice Process payout for a matured receivable
    /// @param tokenId The ID of the receivable token
    function processPayout(
        uint256 tokenId
    ) external nonReentrant whenNotPaused {
        require(
            receivableToken.isMatured(tokenId),
            "Receivable not matured"
        );
        require(!payouts[tokenId].isPaid, "Already paid");
        
        address currentHolder = receivableToken.ownerOf(tokenId);
        (
            address issuer,
            uint256 faceValue,
            uint256 vestingTimestamp,
            ,
            bool isPaid
        ) = receivableToken.getReceivable(tokenId);
        
        require(!isPaid, "Receivable already settled");
        require(
            block.timestamp <= vestingTimestamp + GRACE_PERIOD,
            "Grace period expired"
        );

        // Check if issuer has sufficient collateral
        uint256 requiredCollateral = (faceValue * collateralRate) / 10000;
        require(
            issuerCollateral[issuer] >= requiredCollateral,
            "Insufficient collateral"
        );

        // Process the payout
        bool success = escrowVault.releaseFunds(
            tokenId,
            currentHolder,
            faceValue
        );
        require(success, "Payout failed");

        // Update payout status
        payouts[tokenId] = PayoutStatus({
            isPaid: true,
            paidAmount: faceValue,
            paidTimestamp: block.timestamp,
            payoutReceiver: currentHolder
        });

        // Reduce issuer collateral
        issuerCollateral[issuer] -= requiredCollateral;

        emit PayoutProcessed(
            tokenId,
            currentHolder,
            faceValue,
            block.timestamp
        );
    }

    /// @notice Deposit collateral for issuing receivables
    function depositCollateral() external payable whenNotPaused {
        require(msg.value > 0, "Must deposit something");
        
        issuerCollateral[msg.sender] += msg.value;
        
        emit CollateralDeposited(msg.sender, msg.value);
    }

    /// @notice Withdraw available collateral
    /// @param amount Amount of collateral to withdraw
    function withdrawCollateral(
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be positive");
        require(
            issuerCollateral[msg.sender] >= amount,
            "Insufficient collateral"
        );

        // Check if withdrawal would leave enough collateral for active receivables
        uint256 requiredCollateral = _calculateRequiredCollateral(msg.sender);
        require(
            issuerCollateral[msg.sender] - amount >= requiredCollateral,
            "Insufficient remaining collateral"
        );

        issuerCollateral[msg.sender] -= amount;
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Calculate required collateral for active receivables
    /// @param issuer Address of the issuer
    /// @return required Total required collateral
    function _calculateRequiredCollateral(
        address issuer
    ) internal view returns (uint256 required) {
        // Implementation would iterate through active receivables
        // and sum up required collateral based on face values
        // This is a placeholder - actual implementation needed
        return 0;
    }

    /// @notice Update the collateral rate
    /// @param newRate New collateral rate in basis points
    function updateCollateralRate(uint256 newRate) external onlyOwner {
        require(newRate <= 5000, "Rate too high"); // Max 50%
        collateralRate = newRate;
    }

    /// @notice Update the escrow vault address
    /// @param newVault New escrow vault address
    function updateEscrowVault(address newVault) external onlyOwner {
        require(newVault != address(0), "Invalid vault address");
        escrowVault = IEscrowVault(newVault);
    }

    /// @notice Emergency pause for all payout operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause payout operations
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}