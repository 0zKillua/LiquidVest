// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBaseReceivable.sol";
import "./interfaces/IDiscountCalculator.sol";

/// @title SecondaryMarket - Manages resale of receivables
/// @notice Facilitates secondary market transactions between investors
contract SecondaryMarket is ReentrancyGuard, Pausable, Ownable {
    IBaseReceivable public immutable receivableToken;
    IDiscountCalculator public immutable calculator;
    
    struct SecondaryListing {
        address seller;
        uint256 price;
        bool isActive;
        uint256 timestamp;
    }
    
    mapping(uint256 => SecondaryListing) public secondaryListings;
    mapping(address => uint256) public proceeds;
    
    uint256 public constant LISTING_DURATION = 7 days;
    uint256 public protocolFee = 25; // 0.25% in basis points
    
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
    event SecondaryListingCanceled(
        uint256 indexed tokenId,
        address indexed seller
    );
    
    constructor(address _receivableToken, address _calculator) {
        receivableToken = IBaseReceivable(_receivableToken);
        calculator = IDiscountCalculator(_calculator);
    }
    
    /// @notice Lists a receivable on the secondary market
    /// @param tokenId The ID of the receivable token
    /// @param price The listing price in base currency
    function createSecondaryListing(
        uint256 tokenId,
        uint256 price
    ) external whenNotPaused nonReentrant {
        require(
            receivableToken.ownerOf(tokenId) == msg.sender,
            "Not token owner"
        );
        require(price > 0, "Price must be above zero");
        require(
            receivableToken.getApprovalForAll(msg.sender, address(this)),
            "Market not approved"
        );
        
        secondaryListings[tokenId] = SecondaryListing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: block.timestamp
        });
        
        emit SecondaryListingCreated(tokenId, msg.sender, price);
    }
    
    /// @notice Purchases a listed receivable from secondary market
    /// @param tokenId The ID of the receivable to purchase
    function buySecondaryListing(
        uint256 tokenId
    ) external payable whenNotPaused nonReentrant {
        SecondaryListing memory listing = secondaryListings[tokenId];
        require(listing.isActive, "Listing not active");
        require(
            block.timestamp <= listing.timestamp + LISTING_DURATION,
            "Listing expired"
        );
        require(msg.value >= listing.price, "Insufficient payment");
        
        secondaryListings[tokenId].isActive = false;
        
        uint256 feeAmount = (msg.value * protocolFee) / 10000;
        uint256 sellerProceeds = msg.value - feeAmount;
        
        proceeds[listing.seller] += sellerProceeds;
        proceeds[owner()] += feeAmount;
        
        receivableToken.transferFrom(listing.seller, msg.sender, tokenId);
        
        emit SecondaryListingSold(
            tokenId,
            listing.seller,
            msg.sender,
            msg.value
        );
    }
    
    /// @notice Updates the protocol fee
    /// @param newFee New fee in basis points
    function updateProtocolFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high"); // Max 10%
        protocolFee = newFee;
    }
    
    // Additional functions similar to PrimaryMarket (cancelListing, withdrawProceeds, pause/unpause)
    // ... implementation continues
}