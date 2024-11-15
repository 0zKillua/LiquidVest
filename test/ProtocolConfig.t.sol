// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/governance/ProtocolConfig.sol";

contract ProtocolConfigTest is Test {
    ProtocolConfig public config;
    
    address public owner;
    address public user1;
    
    uint256 public constant MIN_RECEIVABLE_AMOUNT = 100 ether;
    uint256 public constant MAX_RECEIVABLE_AMOUNT = 1000000 ether;
    uint256 public constant MIN_VESTING_PERIOD = 30 days;
    uint256 public constant MAX_VESTING_PERIOD = 365 days;

    event ProtocolParametersUpdated(
        uint256 minAmount,
        uint256 maxAmount,
        uint256 minVesting,
        uint256 maxVesting
    );

    event MarketParametersUpdated(
        uint256 listingDuration,
        uint256 minTradeValue,
        bool secondaryEnabled
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        
        config = new ProtocolConfig();
    }

    function testUpdateProtocolParameters() public {
        uint256 newMinAmount = 50 ether;
        uint256 newMaxAmount = 500000 ether;
        uint256 newMinVesting = 60 days;
        uint256 newMaxVesting = 730 days;
        
        vm.expectEmit(true, true, false, true);
        emit ProtocolParametersUpdated(
            newMinAmount,
            newMaxAmount,
            newMinVesting,
            newMaxVesting
        );
        
        config.updateProtocolParameters(
            ProtocolConfig.ProtocolParameters({
                minReceivableAmount: newMinAmount,
                maxReceivableAmount: newMaxAmount,
                minVestingPeriod: newMinVesting,
                maxVestingPeriod: newMaxVesting,
                gracePeriod: 3 days,
                allowPartialPurchase: false
            })
        );
        
        assertEq(config.protocolParams.minReceivableAmount, newMinAmount);
        assertEq(config.protocolParams.maxReceivableAmount, newMaxAmount);
        assertEq(config.protocolParams.minVestingPeriod, newMinVesting);
        assertEq(config.protocolParams.maxVestingPeriod, newMaxVesting);
    }

    function testUpdateMarketParameters() public {
        uint256 newListingDuration = 14 days;
        uint256 newMinTradeValue = 20 ether;
        bool newSecondaryEnabled = false;
        
        vm.expectEmit(true, true, false, true);
        emit MarketParametersUpdated(
            newListingDuration,
            newMinTradeValue,
            newSecondaryEnabled
        );
        
        config.updateMarketParameters(
            ProtocolConfig.MarketParameters({
                listingDuration: newListingDuration,
                minSecondaryTradeValue: newMinTradeValue,
                earlyExitPenalty: 200,
                enableSecondaryMarket: newSecondaryEnabled
            })
        );
        
        assertEq(config.marketParams.listingDuration, newListingDuration);
        assertEq(config.marketParams.minSecondaryTradeValue, newMinTradeValue);
        assertEq(config.marketParams.enableSecondaryMarket, newSecondaryEnabled);
    }

    function testFailUpdateProtocolParamsInvalidRange() public {
        config.updateProtocolParameters(
            ProtocolConfig.ProtocolParameters({
                minReceivableAmount: 1001 ether,
                maxReceivableAmount: 1000 ether,
                minVestingPeriod: 60 days,
                maxVestingPeriod: 730 days,
                gracePeriod: 3 days,
                allowPartialPurchase: false
            })
        );
    }

    function testFailUpdateMarketParamsInvalidListingDuration() public {
        config.updateMarketParameters(
            ProtocolConfig.MarketParameters({
                listingDuration: 31 days,
                minSecondaryTradeValue: 20 ether,
                earlyExitPenalty: 200,
                enableSecondaryMarket: true
            })
        );
    }

    function testPauseAndUnpause() public {
        config.pause();
        
        vm.expectRevert("Pausable: paused");
        config.updateProtocolParameters(
            ProtocolConfig.ProtocolParameters({
                minReceivableAmount: MIN_RECEIVABLE_AMOUNT,
                maxReceivableAmount: MAX_RECEIVABLE_AMOUNT,
                minVestingPeriod: MIN_VESTING_PERIOD,
                maxVestingPeriod: MAX_VESTING_PERIOD,
                gracePeriod: 3 days,
                allowPartialPurchase: false
            })
        );
        
        config.unpause();
        
        config.updateProtocolParameters(
            ProtocolConfig.ProtocolParameters({
                minReceivableAmount: MIN_RECEIVABLE_AMOUNT,
                maxReceivableAmount: MAX_RECEIVABLE_AMOUNT,
                minVestingPeriod: MIN_VESTING_PERIOD,
                maxVestingPeriod: MAX_VESTING_PERIOD,
                gracePeriod: 3 days,
                allowPartialPurchase: false
            })
        );
    }
}