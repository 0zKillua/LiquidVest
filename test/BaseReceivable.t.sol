// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/core/BaseReceivable.sol";

contract BaseReceivableTest is Test {
    BaseReceivable public receivable;
    address public owner;
    address public user1;
    address public user2;

    event ReceivableCreated(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 faceValue,
        uint256 vestingTimestamp,
        BaseReceivable.RiskTier riskTier
    );

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy BaseReceivable contract
        receivable = new BaseReceivable();
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testMintReceivable() public {
        uint256 faceValue = 1000 ether;
        uint256 vestingPeriod = 30 days;
        BaseReceivable.RiskTier riskTier = BaseReceivable.RiskTier.LOW;

        vm.startPrank(user1);
        
        vm.expectEmit(true, true, false, true);
        emit ReceivableCreated(
            0, // First token ID
            user1,
            faceValue,
            block.timestamp + vestingPeriod,
            riskTier
        );

        uint256 tokenId = receivable.mintReceivable(
            faceValue,
            vestingPeriod,
            riskTier
        );

        BaseReceivable.Receivable memory rec = receivable.getReceivable(tokenId);
        
        assertEq(rec.issuer, user1);
        assertEq(rec.faceValue, faceValue);
        assertEq(rec.vestingTimestamp, block.timestamp + vestingPeriod);
        assertEq(uint8(rec.riskTier), uint8(riskTier));
        assertEq(rec.isPaid, false);
        
        vm.stopPrank();
    }

    function testFailMintZeroFaceValue() public {
        vm.startPrank(user1);
        receivable.mintReceivable(0, 30 days, BaseReceivable.RiskTier.LOW);
        vm.stopPrank();
    }

    function testFailMintZeroVestingPeriod() public {
        vm.startPrank(user1);
        receivable.mintReceivable(1000 ether, 0, BaseReceivable.RiskTier.LOW);
        vm.stopPrank();
    }

    function testUpdateReceivableStatus() public {
        // First mint a receivable
        uint256 tokenId = receivable.mintReceivable(
            1000 ether,
            30 days,
            BaseReceivable.RiskTier.LOW
        );

        // Update status
        receivable.updateReceivableStatus(
            tokenId,
            BaseReceivable.ReceivableStatus.MATURED
        );

        BaseReceivable.Receivable memory rec = receivable.getReceivable(tokenId);
        assertEq(
            uint8(rec.status),
            uint8(BaseReceivable.ReceivableStatus.MATURED)
        );
    }

    function testIsMatured() public {
        uint256 vestingPeriod = 30 days;
        uint256 tokenId = receivable.mintReceivable(
            1000 ether,
            vestingPeriod,
            BaseReceivable.RiskTier.LOW
        );

        assertFalse(receivable.isMatured(tokenId));

        // Warp time to after vesting period
        vm.warp(block.timestamp + vestingPeriod + 1);
        assertTrue(receivable.isMatured(tokenId));
    }

    function testPause() public {
        receivable.pause();
        vm.expectRevert("Pausable: paused");
        receivable.mintReceivable(
            1000 ether,
            30 days,
            BaseReceivable.RiskTier.LOW
        );
    }

    function testUnpause() public {
        receivable.pause();
        receivable.unpause();
        
        uint256 tokenId = receivable.mintReceivable(
            1000 ether,
            30 days,
            BaseReceivable.RiskTier.LOW
        );
        
        assertTrue(tokenId == 0);
    }
}