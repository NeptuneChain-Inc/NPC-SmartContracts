// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./NPC_RoleManager.sol";

/**
 * @title NPC_AccountManager
 * @dev This contract manages account IDs and account data.
 */
contract NPC_AccountManager {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");

    NPC_RoleManager private roleManager;

    // Account data structure
    struct AccountData {
        string role;
        address txAddress;
        bool isBlacklisted;
        uint256 lastActive;
        bool registered;
    }

    // Mappings to store account data
    mapping(string => AccountData) private accountData;

    // Events
    event AccountRegistered(
        string indexed accountID,
        string role,
        address txAddress
    );
    event AccountBlacklisted(string indexed accountID, bool isBlacklisted);

    /**
     * @dev Constructor to initialize roles.
     * @param roleManagerAddress The address of the NPC_RoleManager contract.
     */
    constructor(address roleManagerAddress) {
        roleManager = NPC_RoleManager(roleManagerAddress);
    }

    modifier onlyAdminOrBackend() {
        require(
            roleManager.onlyAdminOrBackend(msg.sender),
            "Caller is not an admin or backend address."
        );
        _;
    }

    modifier onlyRegistered(string memory accountID) {
        require(accountData[accountID].registered, "Account not registered");
        _;
    }

    modifier onlyNotBlacklisted(string memory accountID) {
        require(accountData[accountID].registered, "Account not registered");
        require(!accountData[accountID].isBlacklisted, "Account blacklisted");
        _;
    }

    function verifyRole(string memory accountID, bytes32 role) public view returns(bool) {
        return keccak256(abi.encodePacked(accountData[accountID].role)) == keccak256(abi.encodePacked(_roleToString(role)));
    }

     function isRegistered(string memory accountID) onlyRegistered(accountID) public view returns(bool) {
        return true;
    }

    function isNotBlacklisted(string memory accountID) onlyNotBlacklisted(accountID) public view returns(bool) {
        return true;
    }

    /**
     * @dev Register a new account with a specific role.
     * @param accountID The ID of the account to register.
     * @param role The role of the account.
     * @param txAddress The address of the account.
     */
    function registerAccount(
        string memory accountID,
        string memory role,
        address txAddress
    ) external onlyAdminOrBackend {
        string memory _accountID = _toLowerCase(accountID);
        string memory _role = _toLowerCase(role);
        require(
            !accountData[_accountID].registered,
            "Account already registered"
        );
        accountData[_accountID] = AccountData({
            role: _role,
            txAddress: txAddress,
            isBlacklisted: false,
            lastActive: block.timestamp,
            registered: true
        });
        emit AccountRegistered(_accountID, _role, txAddress);
    }

    /**
     * @dev Blacklist or unblacklist an account.
     * @param accountID The ID of the account to blacklist/unblacklist.
     * @param status The blacklist status (true to blacklist, false to unblacklist).
     */
    function blacklistAccount(string memory accountID, bool status)
        external
        onlyAdminOrBackend
        onlyRegistered(accountID)
    {
        accountData[accountID].isBlacklisted = status;
        emit AccountBlacklisted(accountID, status);
    }

    function updateLastActive(string memory accountID) public {
        accountData[_toLowerCase(accountID)].lastActive = block.timestamp;
    }

    /**
     * @dev Get account data by account ID.
     * @param accountID The ID of the account.
     * @return The account data.
     */
    function getAccountData(string memory accountID)
        external
        view
        returns (AccountData memory)
    {
        return accountData[accountID];
    }

    /**
     * @dev Convert string to lower case.
     * @param str The string to convert.
     * @return The lower case string.
     */
    function _toLowerCase(string memory str)
        internal
        pure
        returns (string memory)
    {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    /**
     * @dev Get role as a string.
     * @param role The role bytes32.
     * @return The role string.
     */
    function _roleToString(bytes32 role) internal pure returns (string memory) {
        if (role == PRODUCER_ROLE) return "producer";
        if (role == VERIFIER_ROLE) return "verifier";
        return "investor";
    }
}
