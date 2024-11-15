// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IBaseReceivable.sol";
import "../interfaces/IDiscountCalculator.sol";

/// @title PrimaryMarket - Manages initial sale of receivables
/// @notice Facilitates primary market transactions between issuers and investors
contract PrimaryMarket is ReentrancyGuard, Pausable, Ownable {

    IBaseReceivable public immutable receivableToken;
    IDiscountCalculator public immutable calculator;
    
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
    }
    
    mapping(uint256 => Listing) public listings;
    mapping(address => uint256) public sellerProceeds;
    
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
    event ListingCanceled(uint256 indexed tokenId, address indexed seller);
    
    constructor(address _receivableToken, address _calculator) {
        receivableToken = IBaseReceivable(_receivableToken);
        calculator = IDiscountCalculator(_calculator);
    }
    
    /// @notice Lists a receivable for initial sale
    /// @param tokenId The ID of the receivable token
    /// @param price The listing price in base currency
    function listReceivable(
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
        
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });
        
        emit ReceivableListed(tokenId, msg.sender, price);
    }
    
    /// @notice Purchases a listed receivable
    /// @param tokenId The ID of the receivable to purchase
    function buyReceivable(
        uint256 tokenId
    ) external payable whenNotPaused nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");
        
        listings[tokenId].isActive = false;
        sellerProceeds[listing.seller] += msg.value;
        
        receivableToken.transferFrom(listing.seller, msg.sender, tokenId);
        
        emit ReceivableSold(tokenId, listing.seller, msg.sender, msg.value);
    }
    
    /// @notice Cancels an active listing
    /// @param tokenId The ID of the receivable listing to cancel
    function cancelListing(
        uint256 tokenId
    ) external nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.seller == msg.sender, "Not the seller");
        require(listing.isActive, "Listing not active");
        
        delete listings[tokenId];
        
        emit ListingCanceled(tokenId, msg.sender);
    }
    
    /// @notice Withdraws accumulated proceeds for the caller
    function withdrawProceeds() external nonReentrant {
        uint256 pendingProceeds = sellerProceeds[msg.sender];
        require(pendingProceeds > 0, "No proceeds available");
        
        sellerProceeds[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: pendingProceeds}("");
        require(success, "Transfer failed");
    }
    
    /// @notice Emergency pause for all market operations
    function pause() external onlyOwner {
        _pause();
    }
    
    /// @notice Unpause market operations
    function unpause() external onlyOwner {
        _unpause();
    }
}