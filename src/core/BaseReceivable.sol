// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title BaseReceivable - Core receivable token implementation
/// @notice Manages the tokenization of receivables
contract BaseReceivable is ERC721, Ownable, ReentrancyGuard, Pausable {
    enum RiskTier { LOW, MEDIUM, HIGH }
    enum ReceivableStatus { ACTIVE, MATURED, DEFAULTED }

    struct Receivable {
        address issuer;
        uint256 faceValue;
        uint256 vestingTimestamp;
        RiskTier riskTier;
        ReceivableStatus status;
        uint256 issuanceDate;
        bool isPaid;
    }

    mapping(uint256 => Receivable) public receivables;
    uint256 private _tokenIdCounter;

    event ReceivableCreated(
        uint256 indexed tokenId,
        address indexed issuer,
        uint256 faceValue,
        uint256 vestingTimestamp,
        RiskTier riskTier
    );
    event ReceivableStatusUpdated(
        uint256 indexed tokenId,
        ReceivableStatus status
    );

    constructor() ERC721("Invoice Receivable", "INVC") {}

    /// @notice Creates a new receivable token
    /// @param faceValue The full amount to be paid at maturity
    /// @param vestingPeriod Duration until maturity in seconds
    /// @param riskTier Risk classification of the receivable
    function mintReceivable(
        uint256 faceValue,
        uint256 vestingPeriod,
        RiskTier riskTier
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(faceValue > 0, "Face value must be positive");
        require(vestingPeriod > 0, "Vesting period must be positive");

        uint256 tokenId = _tokenIdCounter++;
        uint256 vestingTimestamp = block.timestamp + vestingPeriod;

        receivables[tokenId] = Receivable({
            issuer: msg.sender,
            faceValue: faceValue,
            vestingTimestamp: vestingTimestamp,
            riskTier: riskTier,
            status: ReceivableStatus.ACTIVE,
            issuanceDate: block.timestamp,
            isPaid: false
        });

        _safeMint(msg.sender, tokenId);

        emit ReceivableCreated(
            tokenId,
            msg.sender,
            faceValue,
            vestingTimestamp,
            riskTier
        );

        return tokenId;
    }

    /// @notice Updates the status of a receivable
    /// @param tokenId The ID of the receivable to update
    /// @param newStatus The new status to set
    function updateReceivableStatus(
        uint256 tokenId,
        ReceivableStatus newStatus
    ) external onlyOwner {
        require(_exists(tokenId), "Receivable does not exist");
        require(
            receivables[tokenId].status != newStatus,
            "Status already set"
        );

        receivables[tokenId].status = newStatus;
        emit ReceivableStatusUpdated(tokenId, newStatus);
    }

    /// @notice Checks if a receivable has matured
    /// @param tokenId The ID of the receivable to check
    function isMatured(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Receivable does not exist");
        return block.timestamp >= receivables[tokenId].vestingTimestamp;
    }

    /// @notice Gets the full details of a receivable
    /// @param tokenId The ID of the receivable
    function getReceivable(uint256 tokenId) 
        external 
        view 
        returns (Receivable memory) 
    {
        require(_exists(tokenId), "Receivable does not exist");
        return receivables[tokenId];
    }

    /// @notice Emergency pause for all token operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token operations
    function unpause() external onlyOwner {
        _unpause();
    }
}