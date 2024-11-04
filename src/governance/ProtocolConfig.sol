/*
ProtocolConfig contract provides:
Centralized management of protocol-wide parameters
Risk parameter management
Market configuration
Contract authorization system
Flexible configuration storage
Emergency controls

*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title ProtocolConfig - Manages protocol-wide configuration
/// @notice Central configuration contract for the invoice discounting protocol
contract ProtocolConfig is Ownable, Pausable {
    using Address for address;

    struct ProtocolParameters {
        uint256 minReceivableAmount;
        uint256 maxReceivableAmount;
        uint256 minVestingPeriod;
        uint256 maxVestingPeriod;
        uint256 gracePeriod;
        bool allowPartialPurchase;
    }

    struct RiskParameters {
        uint256 baseDiscountRate;
        uint256[] riskPremiums;
        uint256 maxCollateralRatio;
        uint256 minCollateralRatio;
    }

    struct MarketParameters {
        uint256 listingDuration;
        uint256 minSecondaryTradeValue;
        uint256 earlyExitPenalty;
        bool enableSecondaryMarket;
    }

    ProtocolParameters public protocolParams;
    RiskParameters public riskParams;
    MarketParameters public marketParams;
    
    mapping(address => bool) public authorizedContracts;
    mapping(bytes32 => uint256) private configValues;
    
    event ProtocolParametersUpdated(
        uint256 minAmount,
        uint256 maxAmount,
        uint256 minVesting,
        uint256 maxVesting
    );
    
    event RiskParametersUpdated(
        uint256 baseRate,
        uint256[] riskPremiums,
        uint256 maxCollateral
    );
    
    event MarketParametersUpdated(
        uint256 listingDuration,
        uint256 minTradeValue,
        bool secondaryEnabled
    );
    
    event ContractAuthorized(address indexed contractAddress, bool status);

    constructor() {
        // Initialize protocol parameters
        protocolParams = ProtocolParameters({
            minReceivableAmount: 100 ether,
            maxReceivableAmount: 1000000 ether,
            minVestingPeriod: 30 days,
            maxVestingPeriod: 365 days,
            gracePeriod: 3 days,
            allowPartialPurchase: false
        });

        // Initialize risk parameters
        uint256[] memory initialPremiums = new uint256[](3);
        initialPremiums[0] = 0;     // LOW risk premium
        initialPremiums[1] = 200;   // MEDIUM risk premium (2%)
        initialPremiums[2] = 500;   // HIGH risk premium (5%)
        
        riskParams = RiskParameters({
            baseDiscountRate: 500,   // 5%
            riskPremiums: initialPremiums,
            maxCollateralRatio: 5000, // 50%
            minCollateralRatio: 1000  // 10%
        });

        // Initialize market parameters
        marketParams = MarketParameters({
            listingDuration: 7 days,
            minSecondaryTradeValue: 10 ether,
            earlyExitPenalty: 200,    // 2%
            enableSecondaryMarket: true
        });
    }

    /// @notice Update protocol parameters
    /// @param newParams New protocol parameters
    function updateProtocolParameters(
        ProtocolParameters calldata newParams
    ) external onlyOwner {
        require(
            newParams.minReceivableAmount < newParams.maxReceivableAmount,
            "Invalid amount range"
        );
        require(
            newParams.minVestingPeriod < newParams.maxVestingPeriod,
            "Invalid vesting range"
        );
        require(
            newParams.maxVestingPeriod <= 730 days,
            "Vesting too long"
        );

        protocolParams = newParams;

        emit ProtocolParametersUpdated(
            newParams.minReceivableAmount,
            newParams.maxReceivableAmount,
            newParams.minVestingPeriod,
            newParams.maxVestingPeriod
        );
    }

    /// @notice Update risk parameters
    /// @param newParams New risk parameters
    function updateRiskParameters(
        RiskParameters calldata newParams
    ) external onlyOwner {
        require(
            newParams.baseDiscountRate <= 2000,
            "Base rate too high"
        ); // Max 20%
        require(
            newParams.riskPremiums.length == 3,
            "Invalid premium count"
        );
        
        for (uint256 i = 0; i < newParams.riskPremiums.length; i++) {
            require(
                newParams.riskPremiums[i] <= 2000,
                "Premium too high"
            ); // Max 20%
        }

        riskParams = newParams;

        emit RiskParametersUpdated(
            newParams.baseDiscountRate,
            newParams.riskPremiums,
            newParams.maxCollateralRatio
        );
    }

    /// @notice Update market parameters
    /// @param newParams New market parameters
    function updateMarketParameters(
        MarketParameters calldata newParams
    ) external onlyOwner {
        require(
            newParams.listingDuration <= 30 days,
            "Duration too long"
        );
        require(
            newParams.earlyExitPenalty <= 1000,
            "Penalty too high"
        ); // Max 10%

        marketParams = newParams;

        emit MarketParametersUpdated(
            newParams.listingDuration,
            newParams.minSecondaryTradeValue,
            newParams.enableSecondaryMarket
        );
    }

    /// @notice Authorize or deauthorize a contract
    /// @param contractAddress The contract to authorize
    /// @param status Authorization status
    function setContractAuthorization(
        address contractAddress,
        bool status
    ) external onlyOwner {
        require(
            contractAddress.isContract(),
            "Not a contract address"
        );
        authorizedContracts[contractAddress] = status;
        emit ContractAuthorized(contractAddress, status);
    }

    /// @notice Get a specific configuration value
    /// @param key The configuration key
    /// @return value The configuration value
    function getConfigValue(
        bytes32 key
    ) external view returns (uint256 value) {
        return configValues[key];
    }

    /// @notice Set a specific configuration value
    /// @param key The configuration key
    /// @param value The new value
    function setConfigValue(
        bytes32 key,
        uint256 value
    ) external onlyOwner {
        configValues[key] = value;
    }

    /// @notice Emergency pause
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause
    function unpause() external onlyOwner {
        _unpause();
    }
}