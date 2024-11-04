/*
EscrowVault contract provides:
Secure storage of funds for receivables
Lock period management for security
Controlled release of funds through PayoutManager
Emergency controls and pausability
Balance tracking for both specific receivables and issuers
The contract works closely with the PayoutManager to ensure secure and proper handling of funds during the receivable lifecycle.
*/


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IBaseReceivable.sol";

/// @title EscrowVault - Secure storage for receivable funds
/// @notice Manages the escrow of funds for receivable payments
contract EscrowVault is ReentrancyGuard, Ownable, Pausable {
    IBaseReceivable public immutable receivableToken;
    
    struct EscrowBalance {
        uint256 amount;
        uint256 lockTimestamp;
        bool isLocked;
    }
    
    mapping(uint256 => EscrowBalance) public escrowBalances;
    mapping(address => uint256) public issuerBalances;
    
    address public payoutManager;
    uint256 public lockPeriod = 1 days;
    
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
    
    modifier onlyPayoutManager() {
        require(msg.sender == payoutManager, "Only PayoutManager");
        _;
    }

    constructor(address _receivableToken) {
        receivableToken = IBaseReceivable(_receivableToken);
    }

    /// @notice Deposit funds for a specific receivable
    /// @param tokenId The ID of the receivable token
    function depositFunds(
        uint256 tokenId
    ) external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Must deposit funds");
        
        (
            address issuer,
            uint256 faceValue,
            ,
            ,
            bool isPaid
        ) = receivableToken.getReceivable(tokenId);
        
        require(!isPaid, "Receivable already paid");
        require(msg.sender == issuer, "Only issuer can deposit");
        require(
            msg.value == faceValue,
            "Must deposit exact face value"
        );

        escrowBalances[tokenId] = EscrowBalance({
            amount: msg.value,
            lockTimestamp: block.timestamp,
            isLocked: true
        });

        emit FundsDeposited(tokenId, issuer, msg.value);
    }

    /// @notice Release funds to the receivable holder
    /// @param tokenId The ID of the receivable token
    /// @param recipient The address to receive the funds
    /// @param amount The amount to release
    function releaseFunds(
        uint256 tokenId,
        address recipient,
        uint256 amount
    ) external onlyPayoutManager nonReentrant returns (bool) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        
        EscrowBalance storage balance = escrowBalances[tokenId];
        require(balance.isLocked, "Funds not locked");
        require(balance.amount >= amount, "Insufficient funds");
        require(
            block.timestamp >= balance.lockTimestamp + lockPeriod,
            "Funds still locked"
        );

        balance.amount -= amount;
        if (balance.amount == 0) {
            balance.isLocked = false;
        }

        (bool success, ) = payable(recipient).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsReleased(tokenId, recipient, amount);
        return true;
    }

    /// @notice Deposit general issuer balance
    function depositIssuerBalance() external payable whenNotPaused {
        require(msg.value > 0, "Must deposit funds");
        
        issuerBalances[msg.sender] += msg.value;
        
        emit IssuerBalanceUpdated(msg.sender, issuerBalances[msg.sender]);
    }

    /// @notice Get the escrow balance for a receivable
    /// @param tokenId The ID of the receivable token
    function getEscrowBalance(
        uint256 tokenId
    ) external view returns (EscrowBalance memory) {
        return escrowBalances[tokenId];
    }

    /// @notice Update the payout manager address
    /// @param _payoutManager New payout manager address
    function updatePayoutManager(address _payoutManager) external onlyOwner {
        require(_payoutManager != address(0), "Invalid address");
        payoutManager = _payoutManager;
    }

    /// @notice Update the lock period
    /// @param _lockPeriod New lock period in seconds
    function updateLockPeriod(uint256 _lockPeriod) external onlyOwner {
        require(_lockPeriod <= 7 days, "Lock period too long");
        lockPeriod = _lockPeriod;
    }

    /// @notice Emergency withdrawal by owner
    /// @param amount Amount to withdraw
    function emergencyWithdraw(
        uint256 amount
    ) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient balance");
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /// @notice Emergency pause for all vault operations
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause vault operations
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}