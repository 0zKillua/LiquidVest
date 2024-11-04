// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBaseReceivable.sol";

/// @title RiskManager - Manages risk assessment for receivables
/// @notice Handles risk tier assignment and validation
contract RiskManager is Ownable {
    IBaseReceivable public receivableContract;
    
    struct RiskParameters {
        uint256 maxFaceValue;
        uint256 minVestingPeriod;
        uint256 maxVestingPeriod;
        bool isActive;
    }

    mapping(uint8 => RiskParameters) public riskTierParameters;
    mapping(address => uint8) public issuerDefaultRiskTier;
    
    event RiskTierParametersUpdated(
        uint8 tier,
        uint256 maxFaceValue,
        uint256 minVestingPeriod,
        uint256 maxVestingPeriod
    );
    event IssuerRiskTierUpdated(address issuer, uint8 tier);

    constructor(address _receivableContract) {
        receivableContract = IBaseReceivable(_receivableContract);
        
        // Initialize default risk parameters
        riskTierParameters[0] = RiskParameters({
            maxFaceValue: 100000 ether,
            minVestingPeriod: 30 days,
            maxVestingPeriod: 365 days,
            isActive: true
        });
        
        riskTierParameters[1] = RiskParameters({
            maxFaceValue: 50000 ether,
            minVestingPeriod: 30 days,
            maxVestingPeriod: 180 days,
            isActive: true
        });
        
        riskTierParameters[2] = RiskParameters({
            maxFaceValue: 10000 ether,
            minVestingPeriod: 30 days,
            maxVestingPeriod: 90 days,
            isActive: true
        });
    }

    /// @notice Validates if a receivable meets risk parameters
    /// @param faceValue The face value of the receivable
    /// @param vestingPeriod The vesting period in seconds
    /// @param riskTier The proposed risk tier
    function validateReceivable(
        uint256 faceValue,
        uint256 vestingPeriod,
        uint8 riskTier
    ) public view returns (bool) {
        RiskParameters memory params = riskTierParameters[riskTier];
        
        require(params.isActive, "Risk tier not active");
        require(faceValue <= params.maxFaceValue, "Face value too high");
        require(
            vestingPeriod >= params.minVestingPeriod,
            "Vesting period too short"
        );
        require(
            vestingPeriod <= params.maxVestingPeriod,
            "Vesting period too long"
        );
        
        return true;
    }

    /// @notice Updates risk parameters for a tier
    /// @param tier The risk tier to update
    /// @param params The new risk parameters
    function updateRiskTierParameters(
        uint8 tier,
        RiskParameters calldata params
    ) external onlyOwner {
        require(tier <= 2, "Invalid risk tier");
        
        riskTierParameters[tier] = params;
        
        emit RiskTierParametersUpdated(
            tier,
            params.maxFaceValue,
            params.minVestingPeriod,
            params.maxVestingPeriod
        );
    }

    /// @notice Sets the default risk tier for an issuer
    /// @param issuer The issuer address
    /// @param tier The risk tier to assign
    function setIssuerRiskTier(
        address issuer,
        uint8 tier
    ) external onlyOwner {
        require(tier <= 2, "Invalid risk tier");
        require(riskTierParameters[tier].isActive, "Risk tier not active");
        
        issuerDefaultRiskTier[issuer] = tier;
        emit IssuerRiskTierUpdated(issuer, tier);
    }
}