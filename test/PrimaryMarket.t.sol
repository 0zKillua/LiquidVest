// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/market/PrimaryMarket.sol";
import "../src/core/BaseReceivable.sol";
import "../src/core/DiscountCalculator.sol";
import "../src/mocks/MockERC20.sol";

contract PrimaryMarketTest is Test {
    PrimaryMarket public market;
    BaseReceivable public receivable;
    DiscountCalculator public calculator;
    MockERC20 public paymentToken;
    
    address public owner;
    address public seller;
    address public buyer;
    
    uint256 public constant FACE_VALUE = 1000 ether;
    uint256 public constant VESTING_PERIOD = 180 days;
    
    event ReceivableListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    
    event ReceivableSold(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed buyer,
        uint256 price
    );

    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        
        // Deploy contracts
        receivable = new BaseReceivable();
        calculator = new DiscountCalculator();
        market = new PrimaryMarket(address(receivable), address(calculator));
        
        // Fund test accounts
        vm.deal(seller, 100 ether);
        vm.deal(buyer, 100 ether);
        
        // Mint a receivable for testing
        vm.startPrank(seller);
        receivable.mintReceivable(
            FACE_VALUE,
            VESTING_PERIOD,
            BaseReceivable.RiskTier.LOW
        );
        receivable.setApprovalForAll(address(market), true);
        vm.stopPrank();
    }

    function testListReceivable() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether; // 95% of face value
        
        vm.startPrank(seller);
        
        vm.expectEmit(true, true, false, true);
        emit ReceivableListed(tokenId, seller, price);
        
        market.listReceivable(tokenId, price);
        
        (address listingSeller, uint256 listingPrice, bool isActive) = market.getListing(tokenId);
        assertEq(listingSeller, seller);
        assertEq(listingPrice, price);
        assertTrue(isActive);
        
        vm.stopPrank();
    }

    function testBuyReceivable() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether;
        
        // First list the receivable
        vm.prank(seller);
        market.listReceivable(tokenId, price);
        
        // Buy the receivable
        vm.startPrank(buyer);
        
        vm.expectEmit(true, true, true, true);
        emit ReceivableSold(tokenId, seller, buyer, price);
        
        market.buyReceivable{value: price}(tokenId);
        
        // Verify ownership transfer
        assertEq(receivable.ownerOf(tokenId), buyer);
        
        // Verify listing is no longer active
        (,, bool isActive) = market.getListing(tokenId);
        assertFalse(isActive);
        
        vm.stopPrank();
    }

    function testFailBuyReceivableInsufficientPayment() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether;
        
        vm.prank(seller);
        market.listReceivable(tokenId, price);
        
        vm.prank(buyer);
        market.buyReceivable{value: price - 1}(tokenId);
    }

    function testCancelListing() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether;
        
        vm.startPrank(seller);
        market.listReceivable(tokenId, price);
        market.cancelListing(tokenId);
        
        (,, bool isActive) = market.getListing(tokenId);
        assertFalse(isActive);
        vm.stopPrank();
    }

    function testFailBuyUnlistedReceivable() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether;
        
        vm.prank(buyer);
        market.buyReceivable{value: price}(tokenId);
    }

    function testWithdrawProceeds() public {
        uint256 tokenId = 0;
        uint256 price = 950 ether;
        
        // List and sell receivable
        vm.prank(seller);
        market.listReceivable(tokenId, price);
        
        vm.prank(buyer);
        market.buyReceivable{value: price}(tokenId);
        
        // Check seller's proceeds
        uint256 proceeds = market.proceeds(seller);
        assertEq(proceeds, price);
        
        // Withdraw proceeds
        uint256 initialBalance = seller.balance;
        
        vm.prank(seller);
        market.withdrawProceeds();
        
        assertEq(seller.balance - initialBalance, price);
        assertEq(market.proceeds(seller), 0);
    }

    function testPauseAndUnpause() public {
        market.pause();
        
        vm.expectRevert("Pausable: paused");
        vm.prank(seller);
        market.listReceivable(0, 950 ether);
        
        market.unpause();
        
        vm.prank(seller);
        market.listReceivable(0, 950 ether);
    }

    function testFuzzListingPrice(uint256 price) public {
        // Bound price to reasonable ranges
        price = bound(price, 1 ether, FACE_VALUE);
        
        vm.prank(seller);
        market.listReceivable(0, price);
        
        (,uint256 listingPrice,) = market.getListing(0);
        assertEq(listingPrice, price);
    }
}