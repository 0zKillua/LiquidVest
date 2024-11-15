// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title IBaseReceivable - Interface for the base receivable token
/// @notice Defines core functionality for receivable tokens
interface IBaseReceivable is IERC721 {
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

    /// @notice Mint a new receivable token
    /// @param faceValue The full amount to be paid at maturity
    /// @param vestingPeriod Duration until maturity in seconds
    /// @param riskTier Risk classification of the receivable
    function mintReceivable(
        uint256 faceValue,
        uint256 vestingPeriod,
        RiskTier riskTier
    ) external returns (uint256);

    /// @notice Update the status of a receivable
    /// @param tokenId The ID of the receivable to update
    /// @param newStatus The new status to set
    function updateReceivableStatus(
        uint256 tokenId,
        ReceivableStatus newStatus
    ) external;

    /// @notice Check if a receivable has matured
    /// @param tokenId The ID of the receivable to check
    function isMatured(uint256 tokenId) external view returns (bool);

    /// @notice Get the full details of a receivable
    /// @param tokenId The ID of the receivable
    function getReceivable(
        uint256 tokenId
    ) external view returns (Receivable memory);

    /// @notice Get the owner of a receivable token
    /// @param tokenId The ID of the receivable
    function ownerOf(uint256 tokenId) external view returns (address);

    /// @notice Check if an operator is approved for all tokens of an owner
    /// @param owner The owner address
    /// @param operator The operator address
    function getApprovalForAll(
        address owner,
        address operator
    ) external view returns (bool);
}