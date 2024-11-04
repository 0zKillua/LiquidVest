/*
FeeController contract provides:
Fee calculation for different market operations
Fee collection from authorized markets
Fee distribution between treasury and staking rewards
Flexible fee structure management
Market authorization controls
Emergency controls and pausability
*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title FeeController - Manages protocol fees and distribution
/// @notice Handles fee calculation and distribution for all protocol operations
contract FeeController is Ownable, ReentrancyGuard, Pausable {
    struct FeeStructure {
        uint256 primaryMarketFee;    // basis points (1/100 of 1%)
        uint256 secondaryMarketFee;  // basis points
        uint256 earlyExitFee;        // basis points
        bool isActive;
    }

    struct FeeDistribution {
        address treasury;
        address stakingRewards;
        uint256 treasuryShare;      // percentage of total fees
        uint256 stakingShare;       // percentage of total fees
    }

    FeeStructure public fees;
    FeeDistribution public distribution;
    
    mapping(address => bool) public authorizedMarkets;
    mapping(uint256 => uint256) public receivableFeesPaid;
    
    event FeeCollected(
        uint256 indexed tokenId,
        address indexed market,
        uint256 amount,
        uint256 feeType
    );
    
    event FeeDistributed(
        address indexed recipient,
        uint256 amount,
        uint256 distributionType
    );
    
    event FeeStructureUpdated(
        uint256 primaryMarketFee,
        uint256 secondaryMarketFee,
        uint256 earlyExitFee
    );

    constructor(
        address _treasury,
        address _stakingRewards
    ) {
        fees = FeeStructure({
            primaryMarketFee: 50,    // 0.5%
            secondaryMarketFee: 100,  // 1%
            earlyExitFee: 200,       // 2%
            isActive: true
        });

        distribution = FeeDistribution({
            treasury: _treasury,
            stakingRewards: _stakingRewards,
            treasuryShare: 70,        // 70%
            stakingShare: 30          // 30%
        });
    }

    /// @notice Calculate fee for a primary market transaction
    /// @param amount The transaction amount
    /// @return fee The calculated fee amount
    function calculatePrimaryFee(
        uint256 amount
    ) public view returns (uint256) {
        require(fees.isActive, "Fees are disabled");
        return (amount * fees.primaryMarketFee) / 10000;
    }

    /// @notice Calculate fee for a secondary market transaction
    /// @param amount The transaction amount
    /// @param isEarlyExit Whether this is an early exit transaction
    /// @return fee The calculated fee amount
    function calculateSecondaryFee(
        uint256 amount,
        bool isEarlyExit
    ) public view returns (uint256) {
        require(fees.isActive, "Fees are disabled");
        uint256 feeRate = isEarlyExit ? 
            fees.secondaryMarketFee + fees.earlyExitFee : 
            fees.secondaryMarketFee;
        return (amount * feeRate) / 10000;
    }

    /// @notice Collect fees from a market transaction
    /// @param tokenId The receivable token ID
    /// @param amount The transaction amount
    /// @param isSecondary Whether this is a secondary market transaction
    /// @param isEarlyExit Whether this is an early exit
    function collectFee(
        uint256 tokenId,
        uint256 amount,
        bool isSecondary,
        bool isEarlyExit
    ) external nonReentrant whenNotPaused returns (uint256) {
        require(authorizedMarkets[msg.sender], "Unauthorized market");
        
        uint256 feeAmount;
        if (isSecondary) {
            feeAmount = calculateSecondaryFee(amount, isEarlyExit);
        } else {
            feeAmount = calculatePrimaryFee(amount);
        }

        receivableFeesPaid[tokenId] += feeAmount;
        
        emit FeeCollected(
            tokenId,
            msg.sender,
            feeAmount,
            isSecondary ? 2 : 1
        );

        return feeAmount;
    }

    /// @notice Distribute collected fees to treasury and staking rewards
    function distributeFees() external nonReentrant whenNotPaused {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to distribute");

        uint256 treasuryAmount = (balance * distribution.treasuryShare) / 100;
        uint256 stakingAmount = balance - treasuryAmount;

        // Transfer to treasury
        (bool treasurySuccess, ) = payable(distribution.treasury).call{
            value: treasuryAmount
        }("");
        require(treasurySuccess, "Treasury transfer failed");

        // Transfer to staking rewards
        (bool stakingSuccess, ) = payable(distribution.stakingRewards).call{
            value: stakingAmount
        }("");
        require(stakingSuccess, "Staking transfer failed");

        emit FeeDistributed(distribution.treasury, treasuryAmount, 1);
        emit FeeDistributed(distribution.stakingRewards, stakingAmount, 2);
    }

    /// @notice Update fee structure
    /// @param _primaryFee New primary market fee
    /// @param _secondaryFee New secondary market fee
    /// @param _earlyExitFee New early exit fee
    function updateFeeStructure(
        uint256 _primaryFee,
        uint256 _secondaryFee,
        uint256 _earlyExitFee
    ) external onlyOwner {
        require(_primaryFee <= 500, "Primary fee too high");    // Max 5%
        require(_secondaryFee <= 1000, "Secondary fee too high"); // Max 10%
        require(_earlyExitFee <= 1000, "Exit fee too high");    // Max 10%

        fees.primaryMarketFee = _primaryFee;
        fees.secondaryMarketFee = _secondaryFee;
        fees.earlyExitFee = _earlyExitFee;

        emit FeeStructureUpdated(_primaryFee, _secondaryFee, _earlyExitFee);
    }

    /// @notice Update distribution parameters
    /// @param _treasury New treasury address
    /// @param _stakingRewards New staking rewards address
    /// @param _treasuryShare New treasury share percentage
    /// @param _stakingShare New staking share percentage
    function updateDistribution(
        address _treasury,
        address _stakingRewards,
        uint256 _treasuryShare,
        uint256 _stakingShare
    ) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury");
        require(_stakingRewards != address(0), "Invalid staking");
        require(
            _treasuryShare + _stakingShare == 100,
            "Shares must total 100"
        );

        distribution.treasury = _treasury;
        distribution.stakingRewards = _stakingRewards;
        distribution.treasuryShare = _treasuryShare;
        distribution.stakingShare = _stakingShare;
    }

    /// @notice Authorize or deauthorize a market contract
    /// @param market The market address to update
    /// @param authorized Whether to authorize or deauthorize
    function setMarketAuthorization(
        address market,
        bool authorized
    ) external onlyOwner {
        require(market != address(0), "Invalid market");
        authorizedMarkets[market] = authorized;
    }

    /// @notice Emergency pause fee collection
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause fee collection
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}