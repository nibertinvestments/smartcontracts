// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Aetherweb3Safety
 * @dev Security utility library providing common safety patterns
 * @notice Combines multiple security mechanisms for robust contract protection
 */
abstract contract Aetherweb3Safety is ReentrancyGuard, Pausable, Ownable {
    // Emergency controls
    bool public emergencyMode;
    mapping(address => bool) public emergencyAdmins;

    // Rate limiting
    mapping(address => uint256) public lastActionTime;
    uint256 public rateLimit = 1 hours;

    // Whitelist controls
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled;

    // Blacklist controls
    mapping(address => bool) public blacklist;

    // Events
    event EmergencyModeActivated(address indexed activator);
    event EmergencyModeDeactivated(address indexed deactivator);
    event EmergencyAdminAdded(address indexed admin);
    event EmergencyAdminRemoved(address indexed admin);
    event WhitelistEnabled();
    event WhitelistDisabled();
    event AddressWhitelisted(address indexed account);
    event AddressBlacklisted(address indexed account);
    event RateLimitUpdated(uint256 oldLimit, uint256 newLimit);

    // Modifiers
    modifier onlyEmergencyAdmin() {
        require(
            emergencyAdmins[msg.sender] || msg.sender == owner(),
            "Aetherweb3Safety: caller is not emergency admin"
        );
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklist[account], "Aetherweb3Safety: address is blacklisted");
        _;
    }

    modifier onlyWhitelisted() {
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "Aetherweb3Safety: address not whitelisted");
        }
        _;
    }

    modifier rateLimited() {
        require(
            block.timestamp >= lastActionTime[msg.sender] + rateLimit,
            "Aetherweb3Safety: rate limit exceeded"
        );
        lastActionTime[msg.sender] = block.timestamp;
        _;
    }

    modifier notInEmergency() {
        require(!emergencyMode, "Aetherweb3Safety: emergency mode active");
        _;
    }

    /**
     * @dev Activates emergency mode
     * @notice Only emergency admins can activate emergency mode
     */
    function activateEmergencyMode() external onlyEmergencyAdmin {
        emergencyMode = true;
        emit EmergencyModeActivated(msg.sender);
    }

    /**
     * @dev Deactivates emergency mode
     * @notice Only owner can deactivate emergency mode
     */
    function deactivateEmergencyMode() external onlyOwner {
        emergencyMode = false;
        emit EmergencyModeDeactivated(msg.sender);
    }

    /**
     * @dev Adds an emergency admin
     * @param admin Address to add as emergency admin
     */
    function addEmergencyAdmin(address admin) external onlyOwner {
        require(admin != address(0), "Aetherweb3Safety: invalid address");
        emergencyAdmins[admin] = true;
        emit EmergencyAdminAdded(admin);
    }

    /**
     * @dev Removes an emergency admin
     * @param admin Address to remove from emergency admins
     */
    function removeEmergencyAdmin(address admin) external onlyOwner {
        emergencyAdmins[admin] = false;
        emit EmergencyAdminRemoved(admin);
    }

    /**
     * @dev Enables whitelist functionality
     */
    function enableWhitelist() external onlyOwner {
        whitelistEnabled = true;
        emit WhitelistEnabled();
    }

    /**
     * @dev Disables whitelist functionality
     */
    function disableWhitelist() external onlyOwner {
        whitelistEnabled = false;
        emit WhitelistDisabled();
    }

    /**
     * @dev Adds address to whitelist
     * @param account Address to whitelist
     */
    function addToWhitelist(address account) external onlyOwner {
        require(account != address(0), "Aetherweb3Safety: invalid address");
        whitelist[account] = true;
        emit AddressWhitelisted(account);
    }

    /**
     * @dev Removes address from whitelist
     * @param account Address to remove from whitelist
     */
    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
    }

    /**
     * @dev Adds address to blacklist
     * @param account Address to blacklist
     */
    function addToBlacklist(address account) external onlyOwner {
        require(account != address(0), "Aetherweb3Safety: invalid address");
        blacklist[account] = true;
        emit AddressBlacklisted(account);
    }

    /**
     * @dev Removes address from blacklist
     * @param account Address to remove from blacklist
     */
    function removeFromBlacklist(address account) external onlyOwner {
        blacklist[account] = false;
    }

    /**
     * @dev Updates rate limit
     * @param newLimit New rate limit in seconds
     */
    function setRateLimit(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Aetherweb3Safety: invalid rate limit");
        uint256 oldLimit = rateLimit;
        rateLimit = newLimit;
        emit RateLimitUpdated(oldLimit, newLimit);
    }

    /**
     * @dev Batch operation for adding multiple addresses to whitelist
     * @param accounts Array of addresses to whitelist
     */
    function batchAddToWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Aetherweb3Safety: invalid address");
            whitelist[accounts[i]] = true;
            emit AddressWhitelisted(accounts[i]);
        }
    }

    /**
     * @dev Batch operation for adding multiple addresses to blacklist
     * @param accounts Array of addresses to blacklist
     */
    function batchAddToBlacklist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Aetherweb3Safety: invalid address");
            blacklist[accounts[i]] = true;
            emit AddressBlacklisted(accounts[i]);
        }
    }

    /**
     * @dev Checks if an address is authorized (not blacklisted and whitelisted if required)
     * @param account Address to check
     * @return True if authorized
     */
    function isAuthorized(address account) external view returns (bool) {
        if (blacklist[account]) return false;
        if (whitelistEnabled && !whitelist[account]) return false;
        return true;
    }

    /**
     * @dev Gets the current safety status
     * @return emergency Emergency mode status
     * @return paused Pause status
     * @return whitelistEnabled Whitelist status
     */
    function getSafetyStatus() external view returns (bool emergency, bool paused, bool whitelistEnabled) {
        return (emergencyMode, paused(), whitelistEnabled);
    }
}
