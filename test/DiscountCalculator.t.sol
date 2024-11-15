// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/core/DiscountCalculator.sol";

contract DiscountCalculatorTest is Test {
    DiscountCalculator public calculator;
    address public owner;
    address public user1;

    uint256 constant FACE_VALUE = 1000 ether;
    uint256 constant VESTING_PERIOD = 180 days;
    uint256 constant BASE_DISCOUNT_RATE = 500; // 5%

    event RiskPremiumUpdated(uint8 tier, uint256 premium);

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        calculator = new DiscountCalculator();
    }

    function testCalculateDiscountedPrice() public {
        uint256 timeRemaining = 90 days;
        uint8 riskTier = 0; // LOW risk

        uint256 discountedPrice = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            timeRemaining,
            riskTier
        );

        // Expected price should be less than face value
        assertTrue(discountedPrice < FACE_VALUE);
        // Basic sanity check for reasonable discount
        assertTrue(discountedPrice > (FACE_VALUE * 90) / 100); // Should be > 90% of face value
    }

    function testRiskTierPremiums() public {
        uint256 timeRemaining = 90 days;
        
        // Calculate prices for different risk tiers
        uint256 lowRiskPrice = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            timeRemaining,
            0
        );
        uint256 mediumRiskPrice = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            timeRemaining,
            1
        );
        uint256 highRiskPrice = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            timeRemaining,
            2
        );

        // Higher risk should mean lower price
        assertTrue(lowRiskPrice > mediumRiskPrice);
        assertTrue(mediumRiskPrice > highRiskPrice);
    }

    function testUpdateRiskPremium() public {
        uint8 tier = 1;
        uint256 newPremium = 300; // 3%

        vm.expectEmit(true, false, false, true);
        emit RiskPremiumUpdated(tier, newPremium);

        calculator.updateRiskPremium(tier, newPremium);
        
        assertEq(calculator.getEffectiveRate(tier), BASE_DISCOUNT_RATE + newPremium);
    }

    function testFailUpdateRiskPremiumTooHigh() public {
        uint8 tier = 1;
        uint256 newPremium = 2100; // 21% - above maximum allowed

        calculator.updateRiskPremium(tier, newPremium);
    }

    function testTimeImpactOnDiscount() public {
        uint8 riskTier = 0;
        
        uint256 price90Days = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            90 days,
            riskTier
        );
        
        uint256 price180Days = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            180 days,
            riskTier
        );

        // Longer time should mean lower price
        assertTrue(price90Days > price180Days);
    }

    function testZeroTimeRemaining() public {
        uint8 riskTier = 0;
        
        uint256 price = calculator.calculateDiscountedPrice(
            FACE_VALUE,
            0,
            riskTier
        );

        // Price should be face value when no time remaining
        assertEq(price, FACE_VALUE);
    }

    function testFuzzDiscountCalculation(
        uint256 faceValue,
        uint256 timeRemaining,
        uint8 riskTier
    ) public {
        // Bound inputs to reasonable ranges
        faceValue = bound(faceValue, 100, 1000000 ether);
        timeRemaining = bound(timeRemaining, 0, 365 days);
        riskTier = uint8(bound(riskTier, 0, 2));

        uint256 discountedPrice = calculator.calculateDiscountedPrice(
            faceValue,
            timeRemaining,
            riskTier
        );

        // Basic invariants
        assertTrue(discountedPrice <= faceValue);
        if (timeRemaining == 0) {
            assertEq(discountedPrice, faceValue);
        }
    }

    function testDiscountWithMaxValues() public {
        uint256 maxFaceValue = type(uint128).max; // Use uint128 to avoid overflow
        uint256 maxTime = 365 days;
        uint8 maxRiskTier = 2;

        uint256 discountedPrice = calculator.calculateDiscountedPrice(
            maxFaceValue,
            maxTime,
            maxRiskTier
        );

        // Should handle large numbers without reverting
        assertTrue(discountedPrice > 0);
        assertTrue(discountedPrice < maxFaceValue);
    }
}