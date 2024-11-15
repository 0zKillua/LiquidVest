// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/finance/FeeController.sol";

contract FeeControllerTest is Test {
    FeeController public feeController;
    
    address public owner;
    address public treasury;
    address public stakingRewards;
    address public market;
    
    uint256 public constant TRANSACTION_AMOUNT = 1000 ether;

    event FeeCollected(
        uint256 indexed tokenId,
        address indexed market,
        uint256 amount,
        uint256 feeType
    );
    
    event FeeDistributed(
        address indexed recipient,
        uint256 amount,
        uint256 distributionType
    );
    
    event FeeStructureUpdated(
        uint256 primaryMarketFee,
        uint256 secondaryMarketFee,
        uint256 earlyExitFee
    );

    function setUp() public {
        owner = address(this);
        treasury = makeAddr("treasury");
        stakingRewards = makeAddr("stakingRewards");
        market = makeAddr("market");
        
        feeController = new FeeController(treasury, stakingRewards);
        
        // Authorize market
        feeController.setMarketAuthorization(market, true);
    }

    function testCalculatePrimaryFee() public {
        uint256 expectedFee = (TRANSACTION_AMOUNT * 50) / 10000; // 0.5%
        uint256 calculatedFee = feeController.calculatePrimaryFee(TRANSACTION_AMOUNT);
        
        assertEq(calculatedFee, expectedFee);
    }

    function testCalculateSecondaryFee() public {
        // Regular secondary market fee
        uint256 expectedRegularFee = (TRANSACTION_AMOUNT * 100) / 10000; // 1%
        uint256 calculatedRegularFee = feeController.calculateSecondaryFee(
            TRANSACTION_AMOUNT,
            false
        );
        
        assertEq(calculatedRegularFee, expectedRegularFee);
        
        // Early exit fee
        uint256 expectedEarlyExitFee = (TRANSACTION_AMOUNT * 300) / 10000; // 1% + 2%
        uint256 calculatedEarlyExitFee = feeController.calculateSecondaryFee(
            TRANSACTION_AMOUNT,
            true
        );
        
        assertEq(calculatedEarlyExitFee, expectedEarlyExitFee);
    }

    function testCollectFee() public {
        uint256 tokenId = 0;
        
        vm.startPrank(market);
        
        vm.expectEmit(true, true, false, true);
        emit FeeCollected(tokenId, market, 5 ether, 1); // Primary market fee
        
        uint256 feeAmount = feeController.collectFee(
            tokenId,
            TRANSACTION_AMOUNT,
            false,
            false
        );
        
        assertEq(feeAmount, 5 ether); // 0.5% of 1000 ether
        assertEq(feeController.receivableFeesPaid(tokenId), 5 ether);
        
        vm.stopPrank();
    }

    function testDistributeFees() public {
        // First collect some fees
        vm.deal(market, TRANSACTION_AMOUNT);
        
        vm.prank(market);
        feeController.collectFee{value: 5 ether}(0, TRANSACTION_AMOUNT, false, false);
        
        uint256 treasuryInitialBalance = treasury.balance;
        uint256 stakingInitialBalance = stakingRewards.balance;
        
        // Distribute fees
        feeController.distributeFees();
        
        // Check distributions (70% treasury, 30% staking)
        assertEq(treasury.balance - treasuryInitialBalance, 3.5 ether);
        assertEq(stakingRewards.balance - stakingInitialBalance, 1.5 ether);
    }

    function testUpdateFeeStructure() public {
        uint256 newPrimaryFee = 100; // 1%
        uint256 newSecondaryFee = 200; // 2%
        uint256 newEarlyExitFee = 300; // 3%
        
        vm.expectEmit(true, true, false, true);
        emit FeeStructureUpdated(newPrimaryFee, newSecondaryFee, newEarlyExitFee);
        
        feeController.updateFeeStructure(
            newPrimaryFee,
            newSecondaryFee,
            newEarlyExitFee
        );
        
        (
            uint256 primaryFee,
            uint256 secondaryFee,
            uint256 earlyExitFee,
        ) = feeController.fees();
        
        assertEq(primaryFee, newPrimaryFee);
        assertEq(secondaryFee, newSecondaryFee);
        assertEq(earlyExitFee, newEarlyExitFee);
    }

    function testFailUpdateFeeStructureTooHigh() public {
        feeController.updateFeeStructure(501, 1001, 1001); // Above maximum allowed
    }

    function testUpdateDistribution() public {
        address newTreasury = makeAddr("newTreasury");
        address newStaking = makeAddr("newStaking");
        uint256 newTreasuryShare = 60;
        uint256 newStakingShare = 40;
        
        feeController.updateDistribution(
            newTreasury,
            newStaking,
            newTreasuryShare,
            newStakingShare
        );
        
        (
            address updatedTreasury,
            address updatedStaking,
            uint256 updatedTreasuryShare,
            uint256 updatedStakingShare
        ) = feeController.distribution();
        
        assertEq(updatedTreasury, newTreasury);
        assertEq(updatedStaking, newStaking);
        assertEq(updatedTreasuryShare, newTreasuryShare);
        assertEq(updatedStakingShare, newStakingShare);
    }

    function testFailUpdateDistributionInvalidShares() public {
        feeController.updateDistribution(
            treasury,
            stakingRewards,
            80,
            30 // Shares sum to 110%
        );
    }

    function testPauseAndUnpause() public {
        feeController.pause();
        
        vm.expectRevert("Pausable: paused");
        vm.prank(market);
        feeController.collectFee(0, TRANSACTION_AMOUNT, false, false);
        
        feeController.unpause();
        
        vm.prank(market);
        feeController.collectFee(0, TRANSACTION_AMOUNT, false, false);
    }

    function testFuzzFeeCalculation(uint256 amount) public {
        // Bound amount to reasonable ranges
        amount = bound(amount, 1 ether, 1000000 ether);
        
        uint256 primaryFee = feeController.calculatePrimaryFee(amount);
        uint256 secondaryFee = feeController.calculateSecondaryFee(amount, false);
        uint256 earlyExitFee = feeController.calculateSecondaryFee(amount, true);
        
        // Verify fee relationships
        assertTrue(primaryFee < secondaryFee);
        assertTrue(secondaryFee < earlyExitFee);
        assertTrue(primaryFee <= (amount * 500) / 10000); // Max 5%
    }
}