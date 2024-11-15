// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ISecondaryMarket {
    struct SecondaryListing {
        address seller;
        uint256 price;
        bool isActive;
        uint256 timestamp;
    }

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

    function createSecondaryListing(
        uint256 tokenId,
        uint256 price
    ) external returns (bool);

    function buySecondaryListing(
        uint256 tokenId
    ) external payable;

    function cancelSecondaryListing(
        uint256 tokenId
    ) external;

    function getListing(
        uint256 tokenId
    ) external view returns (
        address seller,
        uint256 price,
        bool isActive
    );

    function secondaryListings(
        uint256 tokenId
    ) external view returns (
        address seller,
        uint256 price,
        bool isActive,
        uint256 timestamp
    );
}