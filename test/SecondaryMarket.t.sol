// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/market/SecondaryMarket.sol";
import "../src/core/BaseReceivable.sol";
import "../src/core/DiscountCalculator.sol";
import "../src/mocks/MockERC20.sol";

contract SecondaryMarketTest is Test {
    SecondaryMarket public market;
    BaseReceivable public receivable;
    DiscountCalculator public calculator;
    
    address public owner;
    address public issuer;
    address public firstBuyer;
    address public secondBuyer;
    
    uint256 public constant FACE_VALUE = 1000 ether;
    uint256 public constant VESTING_PERIOD = 180 days;
    uint256 public constant INITIAL_PRICE = 950 ether;
    uint256 public constant RESALE_PRICE = 975 ether;

    event SecondaryListingCreated(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    
    event SecondaryListingSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    function setUp() public {
        owner = address(this);
        issuer = makeAddr("issuer");
        firstBuyer = makeAddr("firstBuyer");
        secondBuyer = makeAddr("secondBuyer");
        
        // Deploy contracts
        receivable = new BaseReceivable();
        calculator = new DiscountCalculator();
        market = new SecondaryMarket(address(receivable), address(calculator));
        
        // Fund test accounts
        vm.deal(issuer, 100 ether);
        vm.deal(firstBuyer, 100 ether);
        vm.deal(secondBuyer, 100 ether);
        
        // Setup initial receivable and transfer to first buyer
        vm.startPrank(issuer);
        uint256 tokenId = receivable.mintReceivable(
            FACE_VALUE,
            VESTING_PERIOD,
            BaseReceivable.RiskTier.LOW
        );
        receivable.approve(firstBuyer, tokenId);
        receivable.transferFrom(issuer, firstBuyer, tokenId);
        vm.stopPrank();
        
        // Approve market for first buyer
        vm.prank(firstBuyer);
        receivable.setApprovalForAll(address(market), true);
    }

    function testCreateSecondaryListing() public {
        uint256 tokenId = 0;
        
        vm.startPrank(firstBuyer);
        
        vm.expectEmit(true, true, false, true);
        emit SecondaryListingCreated(tokenId, firstBuyer, RESALE_PRICE);
        
        market.createSecondaryListing(tokenId, RESALE_PRICE);
        
        (
            address listingSeller,
            uint256 listingPrice,
            bool isActive,
            uint256 timestamp
        ) = market.secondaryListings(tokenId);
        
        assertEq(listingSeller, firstBuyer);
        assertEq(listingPrice, RESALE_PRICE);
        assertTrue(isActive);
        assertEq(timestamp, block.timestamp);
        
        vm.stopPrank();
    }

    function testBuySecondaryListing() public {
        uint256 tokenId = 0;
        
        // Create listing
        vm.prank(firstBuyer);
        market.createSecondaryListing(tokenId, RESALE_PRICE);
        
        // Buy from secondary market
        vm.startPrank(secondBuyer);
        
        vm.expectEmit(true, true, true, true);
        emit SecondaryListingSold(tokenId, firstBuyer, secondBuyer, RESALE_PRICE);
        
        market.buySecondaryListing{value: RESALE_PRICE}(tokenId);
        
        // Verify ownership transfer
        assertEq(receivable.ownerOf(tokenId), secondBuyer);
        
        // Verify listing is closed
        (,, bool isActive,) = market.secondaryListings(tokenId);
        assertFalse(isActive);
        
        vm.stopPrank();
    }

    function testFailBuyExpiredListing() public {
        uint256 tokenId = 0;
        
        // Create listing
        vm.prank(firstBuyer);
        market.createSecondaryListing(tokenId, RESALE_PRICE);
        
        // Warp past listing duration
        vm.warp(block.timestamp + market.LISTING_DURATION() + 1);
        
        // Try to buy expired listing
        vm.prank(secondBuyer);
        market.buySecondaryListing{value: RESALE_PRICE}(tokenId);
    }

    function testCalculateEarlyExitPenalty() public {
        uint256 tokenId = 0;
        
        // Create listing with early exit
        vm.prank(firstBuyer);
        market.createSecondaryListing(tokenId, RESALE_PRICE);
        
        // Check if early exit penalty is applied
        uint256 penaltyAmount = market.calculateEarlyExitPenalty(RESALE_PRICE);
        assertTrue(penaltyAmount > 0);
        assertTrue(penaltyAmount <= (RESALE_PRICE * market.protocolFee()) / 10000);
    }

    function testWithdrawSecondaryProceeds() public {
        uint256 tokenId = 0;
        
        // List and sell receivable
        vm.prank(firstBuyer);
        market.createSecondaryListing(tokenId, RESALE_PRICE);
        
        vm.prank(secondBuyer);
        market.buySecondaryListing{value: RESALE_PRICE}(tokenId);
        
        // Check seller's proceeds
        uint256 proceeds = market.proceeds(firstBuyer);
        assertTrue(proceeds > 0);
        
        // Withdraw proceeds
        uint256 initialBalance = firstBuyer.balance;
        
        vm.prank(firstBuyer);
        market.withdrawProceeds();
        
        assertTrue(firstBuyer.balance > initialBalance);
        assertEq(market.proceeds(firstBuyer), 0);
    }

    function testFuzzSecondaryListingPrice(uint256 price) public {
        // Bound price to reasonable ranges
        price = bound(price, 1 ether, FACE_VALUE);
        
        uint256 tokenId = 0;
        
        vm.prank(firstBuyer);
        market.createSecondaryListing(tokenId, price);
        
        (,uint256 listingPrice,,) = market.secondaryListings(tokenId);
        assertEq(listingPrice, price);
    }

    function testUpdateProtocolFee() public {
        uint256 newFee = 50; // 0.5%
        
        market.updateProtocolFee(newFee);
        assertEq(market.protocolFee(), newFee);
    }

    function testFailUpdateProtocolFeeTooHigh() public {
        uint256 newFee = 1001; // 10.01%
        market.updateProtocolFee(newFee);
    }
}