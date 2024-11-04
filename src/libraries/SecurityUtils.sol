
/*
SecurityUtils library provides:
Signature verification for secure operations
Transaction value validation
Parameter validation utilities
Secure random number generation
Cooldown period management
Operation attempt limiting
Security configuration management
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title SecurityUtils - Library for security-related functions
/// @notice Implements security checks and validations for the protocol
library SecurityUtils {
    using ECDSA for bytes32;
    using Address for address;

    struct SecurityConfig {
        uint256 maxTransactionValue;
        uint256 cooldownPeriod;
        uint256 maxAttemptsPerDay;
        bool requireSignature;
    }

    /// @notice Verify a signed message for secure operations
    /// @param message The original message that was signed
    /// @param signature The signature to verify
    /// @param expectedSigner The address that should have signed the message
    /// @return bool Whether the signature is valid
    function verifySignature(
        bytes32 message,
        bytes memory signature,
        address expectedSigner
    ) internal pure returns (bool) {
        bytes32 ethSignedMessage = message.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessage.recover(signature);
        return recoveredSigner == expectedSigner;
    }

    /// @notice Generate a unique operation hash
    /// @param operator Address initiating the operation
    /// @param operationType Operation identifier
    /// @param nonce Operation nonce
    /// @return bytes32 Unique operation hash
    function generateOperationHash(
        address operator,
        bytes4 operationType,
        uint256 nonce
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(operator, operationType, nonce)
        );
    }

    /// @notice Validate transaction value against limits
    /// @param value Transaction value
    /// @param config Security configuration
    /// @return bool Whether the transaction value is valid
    function validateTransactionValue(
        uint256 value,
        SecurityConfig memory config
    ) internal pure returns (bool) {
        return value <= config.maxTransactionValue;
    }

    /// @notice Check if an address is a contract
    /// @param account Address to check
    /// @return bool Whether the address is a contract
    function isContract(
        address account
    ) internal view returns (bool) {
        return account.isContract();
    }

    /// @notice Validate multiple parameters in a single call
    /// @param params Array of parameters to validate
    /// @param validationMask Bit mask indicating which validations to perform
    /// @return bool Whether all validations pass
    function validateParameters(
        bytes[] memory params,
        uint256 validationMask
    ) internal pure returns (bool) {
        for (uint256 i = 0; i < params.length; i++) {
            if (validationMask & (1 << i) != 0) {
                if (!_validateParameter(params[i], i)) {
                    return false;
                }
            }
        }
        return true;
    }

    /// @notice Internal parameter validation
    /// @param param Parameter to validate
    /// @param validationType Type of validation to perform
    /// @return bool Whether the parameter is valid
    function _validateParameter(
        bytes memory param,
        uint256 validationType
    ) private pure returns (bool) {
        if (param.length == 0) return false;
        
        if (validationType == 0) {
            // Address validation
            require(param.length == 20, "Invalid address length");
            address addr = abi.decode(param, (address));
            return addr != address(0);
        } else if (validationType == 1) {
            // Amount validation
            uint256 amount = abi.decode(param, (uint256));
            return amount > 0;
        }
        
        return true;
    }

    /// @notice Generate a secure random number (for non-critical operations)
    /// @param seed Additional entropy source
    /// @return uint256 Pseudo-random number
    function generateSecureRandom(
        uint256 seed
    ) internal view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    seed
                )
            )
        );
    }

    /// @notice Check if a cooldown period has passed
    /// @param lastOperationTime Last operation timestamp
    /// @param cooldownPeriod Required cooldown period
    /// @return bool Whether the cooldown period has passed
    function hasCooldownPassed(
        uint256 lastOperationTime,
        uint256 cooldownPeriod
    ) internal view returns (bool) {
        return block.timestamp >= lastOperationTime + cooldownPeriod;
    }

    /// @notice Validate operation attempts within time window
    /// @param attempts Number of attempts
    /// @param config Security configuration
    /// @param timeWindow Time window to check
    /// @return bool Whether the operation should be allowed
    function validateOperationAttempts(
        uint256 attempts,
        SecurityConfig memory config,
        uint256 timeWindow
    ) internal pure returns (bool) {
        if (timeWindow >= 1 days) {
            return attempts < config.maxAttemptsPerDay;
        }
        uint256 maxAttemptsForWindow = (config.maxAttemptsPerDay * timeWindow) / 1 days;
        return attempts < maxAttemptsForWindow;
    }

    /// @notice Create a security configuration
    /// @param maxValue Maximum transaction value
    /// @param cooldown Cooldown period
    /// @param maxAttempts Maximum attempts per day
    /// @param requireSig Whether to require signatures
    /// @return SecurityConfig The created configuration
    function createSecurityConfig(
        uint256 maxValue,
        uint256 cooldown,
        uint256 maxAttempts,
        bool requireSig
    ) internal pure returns (SecurityConfig memory) {
        return SecurityConfig({
            maxTransactionValue: maxValue,
            cooldownPeriod: cooldown,
            maxAttemptsPerDay: maxAttempts,
            requireSignature: requireSig
        });
    }
}