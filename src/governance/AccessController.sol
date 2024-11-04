
/*
AccessController contract provides:
Role-based access control with configurable roles
Operation cooldown periods
Member limits per role
Operation tracking
Role activation/deactivation
Emergency controls

*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title AccessController - Manages protocol access control
/// @notice Implements role-based access control for the invoice discounting protocol
contract AccessController is AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct RoleData {
        string name;
        string description;
        bool isActive;
        uint256 maxMembers;
    }

    mapping(bytes32 => RoleData) public roleInfo;
    mapping(address => mapping(bytes32 => uint256)) public lastActionTimestamp;
    
    uint256 public constant COOLDOWN_PERIOD = 1 hours;
    
    event RoleConfigured(
        bytes32 indexed role,
        string name,
        uint256 maxMembers
    );
    
    event OperationPerformed(
        address indexed account,
        bytes32 indexed role,
        bytes4 indexed selector
    );

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        
        // Configure default roles
        _configureRole(
            ADMIN_ROLE,
            "Administrator",
            "Full protocol administration rights",
            3
        );
        
        _configureRole(
            OPERATOR_ROLE,
            "Operator",
            "Day-to-day operation management",
            5
        );
        
        _configureRole(
            MARKET_ROLE,
            "Market Manager",
            "Market operations management",
            10
        );
        
        _configureRole(
            RISK_MANAGER_ROLE,
            "Risk Manager",
            "Risk assessment and management",
            5
        );
        
        _configureRole(
            PAUSER_ROLE,
            "Pauser",
            "Emergency pause rights",
            3
        );
    }

    /// @notice Configure a role's parameters
    /// @param role The role to configure
    /// @param name Role name
    /// @param description Role description
    /// @param maxMembers Maximum number of members allowed
    function _configureRole(
        bytes32 role,
        string memory name,
        string memory description,
        uint256 maxMembers
    ) internal {
        roleInfo[role] = RoleData({
            name: name,
            description: description,
            isActive: true,
            maxMembers: maxMembers
        });

        emit RoleConfigured(role, name, maxMembers);
    }

    /// @notice Check if an account can perform an operation
    /// @param account The account to check
    /// @param role The required role
    /// @param selector The function selector
    function canPerform(
        address account,
        bytes32 role,
        bytes4 selector
    ) public view returns (bool) {
        if (!hasRole(role, account)) return false;
        if (!roleInfo[role].isActive) return false;
        
        uint256 lastAction = lastActionTimestamp[account][role];
        if (lastAction + COOLDOWN_PERIOD > block.timestamp) return false;
        
        return true;
    }

    /// @notice Record an operation being performed
    /// @param account The account performing the operation
    /// @param role The role being used
    /// @param selector The function selector
    function recordOperation(
        address account,
        bytes32 role,
        bytes4 selector
    ) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Unauthorized");
        
        lastActionTimestamp[account][role] = block.timestamp;
        
        emit OperationPerformed(account, role, selector);
    }

    /// @notice Grant a role to an account
    /// @param role The role to grant
    /// @param account The account to receive the role
    function grantProtocolRole(
        bytes32 role,
        address account
    ) external onlyRole(ADMIN_ROLE) {
        require(roleInfo[role].isActive, "Role not active");
        require(
            getRoleMemberCount(role) < roleInfo[role].maxMembers,
            "Max members reached"
        );
        
        grantRole(role, account);
    }

    /// @notice Revoke a role from an account
    /// @param role The role to revoke
    /// @param account The account to revoke from
    function revokeProtocolRole(
        bytes32 role,
        address account
    ) external onlyRole(ADMIN_ROLE) {
        revokeRole(role, account);
    }

    /// @notice Update role configuration
    /// @param role The role to update
    /// @param name New role name
    /// @param description New role description
    /// @param maxMembers New maximum member count
    function updateRoleConfig(
        bytes32 role,
        string calldata name,
        string calldata description,
        uint256 maxMembers
    ) external onlyRole(ADMIN_ROLE) {
        require(maxMembers > 0, "Invalid max members");
        require(
            maxMembers >= getRoleMemberCount(role),
            "Below current member count"
        );
        
        _configureRole(role, name, description, maxMembers);
    }

    /// @notice Deactivate a role
    /// @param role The role to deactivate
    function deactivateRole(
        bytes32 role
    ) external onlyRole(ADMIN_ROLE) {
        require(role != ADMIN_ROLE, "Cannot deactivate admin");
        roleInfo[role].isActive = false;
    }

    /// @notice Activate a role
    /// @param role The role to activate
    function activateRole(
        bytes32 role
    ) external onlyRole(ADMIN_ROLE) {
        roleInfo[role].isActive = true;
    }

    /// @notice Check if a role is active
    /// @param role The role to check
    function isRoleActive(
        bytes32 role
    ) external view returns (bool) {
        return roleInfo[role].isActive;
    }

    /// @notice Emergency pause
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}