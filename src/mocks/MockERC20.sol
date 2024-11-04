// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockERC20 - Mock ERC20 token for testing
/// @notice Implements a basic ERC20 token with minting capabilities
contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;
    bool public transfersAllowed = true;

    event TransferStatusUpdated(bool allowed);

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalsValue
    ) ERC20(name, symbol) {
        _decimals = decimalsValue;
    }

    /// @notice Mint tokens to a specified address
    /// @param to Address to receive the tokens
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Override decimals
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Enable or disable transfers
    /// @param allowed Whether transfers should be allowed
    function setTransfersAllowed(bool allowed) external onlyOwner {
        transfersAllowed = allowed;
        emit TransferStatusUpdated(allowed);
    }

    /// @notice Override transfer to add transfer restriction
    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(transfersAllowed, "Transfers not allowed");
        return super.transfer(to, amount);
    }

    /// @notice Override transferFrom to add transfer restriction
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(transfersAllowed, "Transfers not allowed");
        return super.transferFrom(from, to, amount);
    }

    /// @notice Burn tokens from the caller's address
    /// @param amount Amount of tokens to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// @notice Burn tokens from a specified address
    /// @param from Address to burn tokens from
    /// @param amount Amount of tokens to burn
    function burnFrom(address from, uint256 amount) external {
        uint256 currentAllowance = allowance(from, msg.sender);
        require(currentAllowance >= amount, "Burn amount exceeds allowance");
        _approve(from, msg.sender, currentAllowance - amount);
        _burn(from, amount);
    }
}