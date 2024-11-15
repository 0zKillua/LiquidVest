// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/finance/EscrowVault.sol";
import "../src/core/BaseReceivable.sol";

contract EscrowVaultTest is Test {
    EscrowVault public vault;
    BaseReceivable public receivable;
    
    address public owner;
    address public issuer;
    address public investor;
    address public payoutManager;
    
    uint256 public constant FACE_VALUE = 1000 ether;
    uint256 public constant VESTING_PERIOD = 30 days;
    uint256 public constant LOCK_PERIOD = 1 days;

    event FundsDeposited(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 amount
    );
    
    event FundsReleased(
        uint256 indexed tokenId,
        address indexed recipient,
        uint256 amount
    );
    
    event IssuerBalanceUpdated(
        address indexed issuer,
        uint256 newBalance
    );

    function setUp() public {
        owner = address(this);
        issuer = makeAddr("issuer");
        investor = makeAddr("investor");
        payoutManager = makeAddr("payoutManager");
        
        // Deploy contracts
        receivable = new BaseReceivable();
        vault = new EscrowVault(address(receivable));
        
        // Set payout manager
        vault.updatePayoutManager(payoutManager);
        
        // Fund accounts
        vm.deal(issuer, 2000 ether);
        vm.deal(investor, 1000 ether);
        
        // Mint receivable
        vm.prank(issuer);
        receivable.mintReceivable(
            FACE_VALUE,
            VESTING_PERIOD,
            BaseReceivable.RiskTier.LOW
        );
    }

    function testDepositFunds() public {
        uint256 tokenId = 0;
        
        vm.startPrank(issuer);
        
        vm.expectEmit(true, true, false, true);
        emit FundsDeposited(tokenId, issuer, FACE_VALUE);
        
        vault.depositFunds{value: FACE_VALUE}(tokenId);
        
        EscrowVault.EscrowBalance memory balance = vault.getEscrowBalance(tokenId);
        assertEq(balance.amount, FACE_VALUE);
        assertTrue(balance.isLocked);
        assertEq(balance.lockTimestamp, block.timestamp);
        
        vm.stopPrank();
    }

    function testReleaseFunds() public {
        uint256 tokenId = 0;
        
        // First deposit funds
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(tokenId);
        
        // Warp past lock period
        vm.warp(block.timestamp + LOCK_PERIOD + 1);
        
        // Release funds
        vm.prank(payoutManager);
        
        vm.expectEmit(true, true, false, true);
        emit FundsReleased(tokenId, investor, FACE_VALUE);
        
        bool success = vault.releaseFunds(tokenId, investor, FACE_VALUE);
        assertTrue(success);
        
        EscrowVault.EscrowBalance memory balance = vault.getEscrowBalance(tokenId);
        assertEq(balance.amount, 0);
        assertFalse(balance.isLocked);
    }

    function testFailReleaseBeforeLockPeriod() public {
        uint256 tokenId = 0;
        
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(tokenId);
        
        vm.prank(payoutManager);
        vault.releaseFunds(tokenId, investor, FACE_VALUE);
    }

    function testFailReleaseUnauthorized() public {
        uint256 tokenId = 0;
        
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(tokenId);
        
        vm.warp(block.timestamp + LOCK_PERIOD + 1);
        
        // Try to release from unauthorized address
        vm.prank(issuer);
        vault.releaseFunds(tokenId, investor, FACE_VALUE);
    }

    function testDepositIssuerBalance() public {
        uint256 depositAmount = 500 ether;
        
        vm.startPrank(issuer);
        
        vm.expectEmit(true, false, false, true);
        emit IssuerBalanceUpdated(issuer, depositAmount);
        
        vault.depositIssuerBalance{value: depositAmount}();
        
        assertEq(vault.issuerBalances(issuer), depositAmount);
        
        vm.stopPrank();
    }

    function testUpdateLockPeriod() public {
        uint256 newLockPeriod = 2 days;
        
        vault.updateLockPeriod(newLockPeriod);
        assertEq(vault.lockPeriod(), newLockPeriod);
    }

    function testFailUpdateLockPeriodTooLong() public {
        uint256 newLockPeriod = 8 days; // Max is 7 days
        vault.updateLockPeriod(newLockPeriod);
    }

    function testEmergencyWithdraw() public {
        // First deposit some funds
        uint256 tokenId = 0;
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(tokenId);
        
        uint256 withdrawAmount = FACE_VALUE / 2;
        uint256 initialBalance = address(owner).balance;
        
        vault.emergencyWithdraw(withdrawAmount);
        
        assertEq(address(owner).balance - initialBalance, withdrawAmount);
    }

    function testPauseAndUnpause() public {
        vault.pause();
        
        vm.expectRevert("Pausable: paused");
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(0);
        
        vault.unpause();
        
        vm.prank(issuer);
        vault.depositFunds{value: FACE_VALUE}(0);
    }

    function testFuzzDepositAmount(uint256 amount) public {
        // Bound amount to reasonable ranges
        amount = bound(amount, 1 ether, 1000000 ether);
        
        vm.assume(amount <= issuer.balance);
        
        vm.prank(issuer);
        vault.depositIssuerBalance{value: amount}();
        
        assertEq(vault.issuerBalances(issuer), amount);
    }
}