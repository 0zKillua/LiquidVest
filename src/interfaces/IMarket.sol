// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IMarket - Interface for market operations
/// @notice Defines common functionality for primary and secondary markets
interface IMarket {
    struct Listing {
        address seller;
        uint256 price;
        bool isActive;
        uint256 timestamp;
    }

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

    event ListingCanceled(
        uint256 indexed tokenId,
        address indexed seller
    );

    /// @notice List a receivable for sale
    /// @param tokenId The ID of the receivable token
    /// @param price The listing price
    function listReceivable(
        uint256 tokenId,
        uint256 price
    ) external returns (bool);

    /// @notice Purchase a listed receivable
    /// @param tokenId The ID of the receivable to purchase
    function buyReceivable(uint256 tokenId) external payable;

    /// @notice Cancel an active listing
    /// @param tokenId The ID of the receivable listing to cancel
    function cancelListing(uint256 tokenId) external;

    /// @notice Get listing information
    /// @param tokenId The ID of the receivable
    function getListing(
        uint256 tokenId
    ) external view returns (
        address seller,
        uint256 price,
        bool isActive
    );
}