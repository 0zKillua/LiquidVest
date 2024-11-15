// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/core/BaseReceivable.sol";
import "../src/core/DiscountCalculator.sol";
import "../src/market/PrimaryMarket.sol";
import "../src/market/SecondaryMarket.sol";
import "../src/finance/PayoutManager.sol";
import "../src/finance/EscrowVault.sol";
import "../src/governance/ProtocolConfig.sol";

contract IntegrationTest is Test {
    BaseReceivable public receivable;
    DiscountCalculator public calculator;
    PrimaryMarket public primaryMarket;
    SecondaryMarket public secondaryMarket;
    PayoutManager public payoutManager;
    EscrowVault public escrowVault;
    ProtocolConfig public config;
    
    address public owner;
    address public issuer;
    address public investor1;
    address public investor2;
    
    uint256 public constant FACE_VALUE = 1000 ether;
    uint256 public constant VESTING_PERIOD = 180 days;

    function setUp() public {
        owner = address(this);
        issuer = makeAddr("issuer");
        investor1 = makeAddr("investor1");
        investor2 = makeAddr("investor2");
        
        // Deploy contracts
        receivable = new BaseReceivable();
        calculator = new DiscountCalculator();
        primaryMarket = new PrimaryMarket(address(receivable), address(calculator));
        secondaryMarket = new SecondaryMarket(address(receivable), address(calculator));
        payoutManager = new PayoutManager(address(receivable), address(escrowVault));
        escrowVault = new EscrowVault(address(receivable));
        config = new ProtocolConfig();
        
        // Set up relationships between contracts
        escrowVault.updatePayoutManager(address(payoutManager));
        
        // Fund accounts
        vm.deal(issuer, 2000 ether);
        vm.deal(investor1, 1000 ether);
        vm.deal(investor2, 1000 ether);
    }

    function testFullWorkflow() public {
        // Mint a new receivable
        vm.startPrank(issuer);
        uint256 tokenId = receivable.mintReceivable(
            FACE_VALUE,
            VESTING_PERIOD,
            BaseReceivable.RiskTier.LOW
        );
        receivable.setApprovalForAll(address(primaryMarket), true);
        vm.stopPrank();
        
        // List on primary market and buy
        vm.prank(investor1);
        primaryMarket.listReceivable(tokenId, 950 ether); // Discounted price
        primaryMarket.buyReceivable{value: 950 ether}(tokenId);
        
        // Resell on secondary market and buy again
        vm.prank(investor1);
        secondaryMarket.createSecondaryListing(tokenId, 960 ether); // New discounted price
        vm.prank(investor2);
        secondaryMarket.buySecondaryListing{value: 960 ether}(tokenId);
        
        // Deposit funds into escrow vault for payout
        vm.prank(issuer);
        escrowVault.depositFunds{value: FACE_VALUE}(tokenId);
        
        // Warp to maturity date
        vm.warp(block.timestamp + VESTING_PERIOD);
        
        // Process payout
        vm.prank(investor2);
        payoutManager.processPayout(tokenId);
        
        assertEq(investor2.balance, 1960 ether); // Initial balance + payout
        
        // Verify token is burnt after payout
        assertFalse(receivable.exists(tokenId));
    }
}