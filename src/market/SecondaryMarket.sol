// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ISecondaryMarket.sol";
import "../interfaces/IBaseReceivable.sol";
import "../interfaces/IDiscountCalculator.sol";

contract SecondaryMarket is ISecondaryMarket, ReentrancyGuard, Pausable, Ownable {
    IBaseReceivable public immutable receivableToken;
    IDiscountCalculator public immutable calculator;
    
    mapping(uint256 => SecondaryListing) public override secondaryListings;
    mapping(address => uint256) public sellerProceeds;
    
    uint256 public constant LISTING_DURATION = 7 days;
    uint256 public protocolFee = 100; // 1% in basis points

    constructor(
        address _receivableToken,
        address _calculator
    ) {
        receivableToken = IBaseReceivable(_receivableToken);
        calculator = IDiscountCalculator(_calculator);
    }

    function createSecondaryListing(
        uint256 tokenId,
        uint256 price
    ) external override nonReentrant whenNotPaused returns (bool) {
        require(price > 0, "Price must be positive");
        require(
            receivableToken.ownerOf(tokenId) == msg.sender,
            "Not token owner"
        );
        
        secondaryListings[tokenId] = SecondaryListing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: block.timestamp
        });
        
        emit SecondaryListingCreated(tokenId, msg.sender, price);
        return true;
    }

    function buySecondaryListing(
        uint256 tokenId
    ) external override payable nonReentrant whenNotPaused {
        SecondaryListing memory listing = secondaryListings[tokenId];
        require(listing.isActive, "Listing not active");
        require(
            block.timestamp <= listing.timestamp + LISTING_DURATION,
            "Listing expired"
        );
        require(msg.value >= listing.price, "Insufficient payment");
        
        secondaryListings[tokenId].isActive = false;
        sellerProceeds[listing.seller] += msg.value;
        
        receivableToken.transferFrom(listing.seller, msg.sender, tokenId);
        
        emit SecondaryListingSold(
            tokenId,
            listing.seller,
            msg.sender,
            msg.value
        );
    }

    function cancelSecondaryListing(
        uint256 tokenId
    ) external override nonReentrant {
        SecondaryListing memory listing = secondaryListings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.isActive, "Listing not active");
        
        secondaryListings[tokenId].isActive = false;
        
        emit SecondaryListingCanceled(tokenId, msg.sender);
    }

    function getListing(
        uint256 tokenId
    ) external view override returns (
        address seller,
        uint256 price,
        bool isActive
    ) {
        SecondaryListing memory listing = secondaryListings[tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }

    // Additional functions for protocol management
    function updateProtocolFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        protocolFee = newFee;
    }

    function withdrawProceeds() external nonReentrant {
        uint256 pendingProceeds = sellerProceeds[msg.sender];
        require(pendingProceeds > 0, "No proceeds available");
        
        sellerProceeds[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: pendingProceeds}("");
        require(success, "Transfer failed");
    }

    function calculateEarlyExitPenalty(
        uint256 price
    ) public view returns (uint256) {
        return (price * protocolFee) / 10000;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Function to handle direct ETH transfers
    receive() external payable {}
}