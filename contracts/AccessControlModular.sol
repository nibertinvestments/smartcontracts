// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract AccessControlModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct UserRole {
        uint256 roleId;
        uint256 permissions;    // Bitfield of permissions
        uint256 expiry;         // Role expiry timestamp
        bool isActive;
    }

    struct RoleConfig {
        string name;
        uint256 basePermissions;
        uint256 maxUsers;
        bool transferable;
    }

    mapping(address => UserRole) public userRoles;
    mapping(uint256 => RoleConfig) public roleConfigs;
    mapping(address => uint256) public userLastActivity;
    mapping(address => uint256) public userTransactionCount;

    uint256 public constant MAX_ROLES = 16;
    uint256 public constant PERMISSION_TRANSFER = 1;
    uint256 public constant PERMISSION_TRADE = 2;
    uint256 public constant PERMISSION_STAKE = 4;
    uint256 public constant PERMISSION_VOTE = 8;
    uint256 public constant PERMISSION_ADMIN = 16;

    event RoleAssigned(address indexed user, uint256 roleId, uint256 permissions);
    event RoleRevoked(address indexed user, uint256 roleId);
    event PermissionGranted(address indexed user, uint256 permission);
    event PermissionRevoked(address indexed user, uint256 permission);
    event AccessDenied(address indexed user, string reason);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    constructor() {
        // Initialize default roles
        roleConfigs[1] = RoleConfig("Basic User", PERMISSION_TRADE, 10000, true);
        roleConfigs[2] = RoleConfig("Premium User", PERMISSION_TRADE | PERMISSION_STAKE, 5000, true);
        roleConfigs[3] = RoleConfig("VIP User", PERMISSION_TRADE | PERMISSION_STAKE | PERMISSION_VOTE, 1000, true);
        roleConfigs[4] = RoleConfig("Admin", PERMISSION_ADMIN, 10, false);
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function createRole(
        uint256 roleId,
        string calldata name,
        uint256 basePermissions,
        uint256 maxUsers,
        bool transferable
    ) external onlyOwner {
        require(roleId > 0 && roleId <= MAX_ROLES, "Invalid role ID");
        require(bytes(name).length > 0, "Role name required");

        roleConfigs[roleId] = RoleConfig({
            name: name,
            basePermissions: basePermissions,
            maxUsers: maxUsers,
            transferable: transferable
        });
    }

    function assignRole(address user, uint256 roleId, uint256 expiry) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(roleConfigs[roleId].basePermissions > 0, "Role does not exist");

        userRoles[user] = UserRole({
            roleId: roleId,
            permissions: roleConfigs[roleId].basePermissions,
            expiry: expiry,
            isActive: true
        });

        userLastActivity[user] = block.timestamp;

        emit RoleAssigned(user, roleId, roleConfigs[roleId].basePermissions);
    }

    function revokeRole(address user) external onlyOwner {
        require(userRoles[user].isActive, "User has no active role");

        uint256 roleId = userRoles[user].roleId;
        userRoles[user].isActive = false;

        emit RoleRevoked(user, roleId);
    }

    function grantPermission(address user, uint256 permission) external onlyOwner {
        require(userRoles[user].isActive, "User has no active role");
        require(isValidPermission(permission), "Invalid permission");

        userRoles[user].permissions |= permission;
        emit PermissionGranted(user, permission);
    }

    function revokePermission(address user, uint256 permission) external onlyOwner {
        require(userRoles[user].isActive, "User has no active role");

        userRoles[user].permissions &= ~permission;
        emit PermissionRevoked(user, permission);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeAction) {
            return abi.encode(checkAccess(caller, PERMISSION_TRADE, "trade"));
        }

        if (tupleType == IModularTuple.TupleType.BeforeTransfer) {
            (address from,,) = abi.decode(data, (address, address, uint256));
            return abi.encode(checkAccess(from, PERMISSION_TRANSFER, "transfer"));
        }

        if (tupleType == IModularTuple.TupleType.BeforeMint) {
            (address minter,,) = abi.decode(data, (address, address, uint256));
            return abi.encode(checkAccess(minter, PERMISSION_ADMIN, "mint"));
        }

        if (tupleType == IModularTuple.TupleType.BeforeBurn) {
            (address burner,,) = abi.decode(data, (address, address, uint256));
            return abi.encode(checkAccess(burner, PERMISSION_ADMIN, "burn"));
        }

        return abi.encode(true); // Allow by default
    }

    function checkAccess(
        address user,
        uint256 requiredPermission,
        string memory action
    ) internal returns (bool) {
        UserRole memory role = userRoles[user];

        // Check if user has an active role
        if (!role.isActive) {
            emit AccessDenied(user, "No active role");
            return false;
        }

        // Check role expiry
        if (role.expiry > 0 && block.timestamp > role.expiry) {
            userRoles[user].isActive = false;
            emit AccessDenied(user, "Role expired");
            return false;
        }

        // Check permission
        if ((role.permissions & requiredPermission) == 0) {
            emit AccessDenied(user, string(abi.encodePacked("Missing permission for ", action)));
            return false;
        }

        // Update activity tracking
        userLastActivity[user] = block.timestamp;
        userTransactionCount[user] += 1;

        return true;
    }

    function hasPermission(address user, uint256 permission) external view returns (bool) {
        UserRole memory role = userRoles[user];
        if (!role.isActive) return false;
        if (role.expiry > 0 && block.timestamp > role.expiry) return false;
        return (role.permissions & permission) != 0;
    }

    function getUserRole(address user) external view returns (UserRole memory) {
        return userRoles[user];
    }

    function getRoleConfig(uint256 roleId) external view returns (RoleConfig memory) {
        return roleConfigs[roleId];
    }

    function isValidPermission(uint256 permission) internal pure returns (bool) {
        return permission > 0 && permission <= PERMISSION_ADMIN * 2 - 1;
    }

    function getUserActivity(address user) external view returns (uint256 lastActivity, uint256 txCount) {
        return (userLastActivity[user], userTransactionCount[user]);
    }

    function getContractName() external pure returns (string memory) {
        return "AccessControlModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("ACCESS_CONTROL");
    }

    function validate(bytes calldata data) external view returns (bool) {
        if (data.length < 20) return false;
        (address user) = abi.decode(data, (address));
        return user != address(0);
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 25000; // Conservative estimate for access checks
    }

    function isActive() external view returns (bool) {
        return !paused && leaderContract != address(0);
    }

    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    ) {
        return (
            this.getContractName(),
            this.getContractVersion(),
            this.getContractType(),
            this.isActive(),
            leaderContract
        );
    }
}
