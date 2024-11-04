// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockOracle - Mock price feed and risk assessment oracle
/// @notice Simulates external oracle functionality for testing
contract MockOracle is Ownable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 decimals;
    }

    struct RiskData {
        uint8 riskTier;
        uint256 confidence;
        uint256 timestamp;
    }

    mapping(bytes32 => PriceData) public prices;
    mapping(address => RiskData) public riskAssessments;
    
    uint256 public constant STALENESS_PERIOD = 1 hours;
    
    event PriceUpdated(bytes32 indexed identifier, uint256 price);
    event RiskAssessmentUpdated(
        address indexed subject,
        uint8 riskTier,
        uint256 confidence
    );

    /// @notice Set price data for an asset
    /// @param identifier Asset identifier
    /// @param price Asset price
    /// @param decimals Price decimals
    function setPrice(
        bytes32 identifier,
        uint256 price,
        uint256 decimals
    ) external onlyOwner {
        prices[identifier] = PriceData({
            price: price,
            timestamp: block.timestamp,
            decimals: decimals
        });

        emit PriceUpdated(identifier, price);
    }

    /// @notice Set risk assessment for an address
    /// @param subject Address to assess
    /// @param riskTier Risk tier assignment
    /// @param confidence Confidence level in assessment
    function setRiskAssessment(
        address subject,
        uint8 riskTier,
        uint256 confidence
    ) external onlyOwner {
        require(riskTier <= 2, "Invalid risk tier");
        require(confidence <= 100, "Invalid confidence value");

        riskAssessments[subject] = RiskData({
            riskTier: riskTier,
            confidence: confidence,
            timestamp: block.timestamp
        });

        emit RiskAssessmentUpdated(subject, riskTier, confidence);
    }

    /// @notice Get latest price data
    /// @param identifier Asset identifier
    /// @return price Current price
    /// @return timestamp Last update timestamp
    /// @return decimals Price decimals
    function getLatestPrice(
        bytes32 identifier
    ) external view returns (
        uint256 price,
        uint256 timestamp,
        uint256 decimals
    ) {
        PriceData memory data = prices[identifier];
        require(data.timestamp > 0, "No price data");
        require(
            block.timestamp - data.timestamp <= STALENESS_PERIOD,
            "Price data stale"
        );

        return (data.price, data.timestamp, data.decimals);
    }

    /// @notice Get latest risk assessment
    /// @param subject Address to query
    /// @return riskTier Assigned risk tier
    /// @return confidence Assessment confidence
    /// @return timestamp Last update timestamp
    function getLatestRiskAssessment(
        address subject
    ) external view returns (
        uint8 riskTier,
        uint256 confidence,
        uint256 timestamp
    ) {
        RiskData memory data = riskAssessments[subject];
        require(data.timestamp > 0, "No risk assessment");
        require(
            block.timestamp - data.timestamp <= STALENESS_PERIOD,
            "Risk data stale"
        );

        return (data.riskTier, data.confidence, data.timestamp);
    }

    /// @notice Batch update prices
    /// @param identifiers Array of asset identifiers
    /// @param prices Array of prices
    /// @param decimals Array of decimals
    function batchUpdatePrices(
        bytes32[] calldata identifiers,
        uint256[] calldata prices,
        uint256[] calldata decimals
    ) external onlyOwner {
        require(
            identifiers.length == prices.length &&
            prices.length == decimals.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < identifiers.length; i++) {
            setPrice(identifiers[i], prices[i], decimals[i]);
        }
    }

    /// @notice Batch update risk assessments
    /// @param subjects Array of addresses to assess
    /// @param riskTiers Array of risk tiers
    /// @param confidences Array of confidence levels
    function batchUpdateRiskAssessments(
        address[] calldata subjects,
        uint8[] calldata riskTiers,
        uint256[] calldata confidences
    ) external onlyOwner {
        require(
            subjects.length == riskTiers.length &&
            riskTiers.length == confidences.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < subjects.length; i++) {
            setRiskAssessment(subjects[i], riskTiers[i], confidences[i]);
        }
    }
}