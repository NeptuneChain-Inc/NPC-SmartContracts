// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title NPC_RoleManager
 * @dev This contract manages roles and addresses for centralized control.
 */
contract NPC_RoleManager is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

    event BackendAddressAdded(address indexed account);
    event BackendAddressRemoved(address indexed account);
    event AdminAddressAdded(address indexed account);
    event AdminAddressRemoved(address indexed account);

    /**
     * @dev Constructor to initialize roles.
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function isBackendAddress(address account) public view returns (bool) {
        return hasRole(BACKEND_ROLE, account);
    }

    function isOnlyAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function onlyAdminOrBackend(
        address account
    ) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account) || hasRole(BACKEND_ROLE, account);
    }

    /**
     * @dev Add a new backend address.
     * @param account The address to add.
     */
    function addBackendAddress(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(BACKEND_ROLE, account);
        emit BackendAddressAdded(account);
    }

    /**
     * @dev Remove a backend address.
     * @param account The address to remove.
     */
    function removeBackendAddress(address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        revokeRole(BACKEND_ROLE, account);
        emit BackendAddressRemoved(account);
    }

    /**
     * @dev Add a new admin address.
     * @param account The address to add.
     */
    function addAdminAddress(address account) external onlyRole(ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
        emit AdminAddressAdded(account);
    }

    /**
     * @dev Remove a admin address.
     * @param account The address to remove.
     */
    function removeAdminAddress(address account) external onlyRole(ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
        emit AdminAddressRemoved(account);
    }
}
