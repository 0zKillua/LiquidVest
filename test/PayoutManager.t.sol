// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/finance/PayoutManager.sol";
import "../src/core/BaseReceivable.sol";
import "../src/finance/EscrowVault.sol";

contract PayoutManagerTest is Test {
    PayoutManager public payoutManager;
    BaseReceivable public receivable;
    EscrowVault public escrowVault;
    
    address public owner;
    address public issuer;
    address public investor;
    
    uint256 public constant FACE_VALUE = 1000 ether;
    uint256 public constant VESTING_PERIOD = 30 days;
    uint256 public constant GRACE_PERIOD = 3 days;

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

    function setUp() public {
        owner = address(this);
        issuer = makeAddr("issuer");
        investor = makeAddr("investor");
        
        // Deploy contracts
        receivable = new BaseReceivable();
        escrowVault = new EscrowVault(address(receivable));
        payoutManager = new PayoutManager(address(receivable), address(escrowVault));
        
        // Set PayoutManager as authorized in EscrowVault
        escrowVault.updatePayoutManager(address(payoutManager));
        
        // Fund accounts
        vm.deal(issuer, 2000 ether);
        vm.deal(investor, 1000 ether);
        
        // Mint a receivable for testing
        vm.prank(issuer);
        receivable.mintReceivable(
            FACE_VALUE,
            VESTING_PERIOD,
            BaseReceivable.RiskTier.LOW
        );
    }

    function testDepositCollateral() public {
        uint256 collateralAmount = 100 ether;
        
        vm.startPrank(issuer);
        
        vm.expectEmit(true, false, false, true);
        emit CollateralDeposited(issuer, collateralAmount);
        
        payoutManager.depositCollateral{value: collateralAmount}();
        
        assertEq(payoutManager.issuerCollateral(issuer), collateralAmount);
        
        vm.stopPrank();
    }

    function testProcessPayout() public {
        uint256 tokenId = 0;
        uint256 collateralAmount = 200 ether; // 20% of face value
        
        // Deposit collateral
        vm.prank(issuer);
        payoutManager.depositCollateral{value: collateralAmount}();
        
        // Transfer receivable to investor
        vm.prank(issuer);
        receivable.transferFrom(issuer, investor, tokenId);
        
        // Deposit funds to escrow
        vm.prank(issuer);
        escrowVault.depositFunds{value: FACE_VALUE}(tokenId);
        
        // Warp to maturity
        vm.warp(block.timestamp + VESTING_PERIOD);
        
        vm.startPrank(investor);
        
        vm.expectEmit(true, true, false, true);
        emit PayoutProcessed(tokenId, investor, FACE_VALUE, block.timestamp);
        
        payoutManager.processPayout(tokenId);
        
        assertEq(investor.balance, 1000 ether + FACE_VALUE);
        
        vm.stopPrank();
    }

    function testFailProcessPayoutBeforeMaturity() public {
        uint256 tokenId = 0;
        
        vm.prank(investor);
        payoutManager.processPayout(tokenId);
    }

    function testFailProcessPayoutAfterGracePeriod() public {
        uint256 tokenId = 0;
        
        // Warp to after grace period
        vm.warp(block.timestamp + VESTING_PERIOD + GRACE_PERIOD + 1);
        
        vm.prank(investor);
        payoutManager.processPayout(tokenId);
    }

    function testWithdrawCollateral() public {
        uint256 collateralAmount = 100 ether;
        
        vm.startPrank(issuer);
        
        payoutManager.depositCollateral{value: collateralAmount}();
        
        vm.expectEmit(true, false, false, true);
        emit CollateralWithdrawn(issuer, collateralAmount);
        
        payoutManager.withdrawCollateral(collateralAmount);
        
        assertEq(payoutManager.issuerCollateral(issuer), 0);
        assertEq(issuer.balance, 2000 ether);
        
        vm.stopPrank();
    }

    function testFailWithdrawExcessCollateral() public {
        uint256 collateralAmount = 100 ether;
        
        vm.startPrank(issuer);
        
        payoutManager.depositCollateral{value: collateralAmount}();
        payoutManager.withdrawCollateral(collateralAmount + 1 ether);
        
        vm.stopPrank();
    }

    function testUpdateCollateralRate() public {
        uint256 newRate = 1500; // 15%
        
        payoutManager.updateCollateralRate(newRate);
        assertEq(payoutManager.collateralRate(), newRate);
    }

    function testFailUpdateCollateralRateTooHigh() public {
        uint256 newRate = 5001; // 50.01%
        payoutManager.updateCollateralRate(newRate);
    }

    function testPauseAndUnpause() public {
        payoutManager.pause();
        
        vm.expectRevert("Pausable: paused");
        vm.prank(issuer);
        payoutManager.depositCollateral{value: 1 ether}();
        
        payoutManager.unpause();
        
        vm.prank(issuer);
        payoutManager.depositCollateral{value: 1 ether}();
    }
}