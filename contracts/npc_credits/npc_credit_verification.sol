// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NeptuneChainVerification is
    ERC721Enumerable,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");
    int256 public qTime = 0.1 hours;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // Define DEFAULT_ADMIN_ROLE

    struct AccountData {
      address txAddress;
      bool isVerifier;
    }

    struct VerificationData {
        uint256 id;
        string accountID;
        bool approved;
        uint256[] disputes; // Array of disputeIDs
    }

    struct DisputeData {
        string assetID;
        string reason;
        string solution;
        string status;
        bool closed;
    }

    uint256 totalSubmissions;
    uint256 totalApprovals;
    uint256 totalDisputes;

    mapping(string => VerificationData) public verifications; // assetID => VerificationData
    mapping(uint256 => DisputeData) public disputes; // disputeID => DisputeData
    mapping(string => uint256) public lastSubmission; // accountID => timestamp
    mapping(string => AccountData) public accountData; // accountID => address
    mapping(string => uint256) public verifierReputation; // accountID => score

    event AssetSubmitted(int256 id, string assetID, string accountID);
    event AssetVerified(int256 id, string assetID, string accountID);
    event DisputeRaised(
        string assetID,
        int256 disputeID,
        string reason,
        string accountID
    );
    event DisputeResolved(
        string assetID,
        int256 disputeID,
        string solution,
        string accountID
    );

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(BACKEND_ROLE, msg.sender);
    }

    modifier rateLimited(string memory accountID) {
        require(
            int256(block.timestamp - lastSubmission[accountID]) > qTime,
            "You need to wait before another submission."
        );
        _;
    }

    modifier isVerifier(string memory accountID) {
        require(
            accountData[accountID].isVerifier,
            "User account  "
        );
        _;
    }

    function registerAccount(string memory accountID, address accountAddress, bool verify) external whenNotPaused onlyRole(BACKEND_ROLE) returns(bool) {
      accountData[accountID] = AccountData({
        txAddress: accountAddress,
        isVerifier: verify
      });
      return true;
    }

    function submitAsset(
        string memory accountID,
        string memory assetID
    ) external whenNotPaused rateLimited(accountID) onlyRole(BACKEND_ROLE) returns (uint256) {
        //Init submissionID
        verifications[assetID] = VerificationData({
            id: ++totalSubmissions,
            account: accountID,
            approved: false,
            disputes: []
        });
        lastSubmission[accountID] = block.timestamp;
        emit AssetSubmitted(totalSubmissions, assetID, accountID);
        return totalSubmissions;
    }

//Only Verifier
    function approveAsset(
        string memory accountID,
        string memory assetID
    ) external whenNotPaused onlyRole(BACKEND_ROLE) {
        VerificationData verification = verifications[assetID];
        require(!verification.approved, "Data already verified.");

        _mint(accountData[verification.account].txAddress, verification.id);

        verification.approved = true;
        verifierReputation[accountID]++;
        totalApprovals++;
        emit AssetVerified(verification.id, assetID, accountID);
    }

//Only Farmer
    function raiseDispute(
        string memory accountID,
        string memory assetID,
        string memory reason
    ) external whenNotPaused onlyRole(BACKEND_ROLE) {
        require(
            verifications[assetID].account == accountID,
            "Only the data submitter can raise a dispute."
        );

        // init disputeID & Write dispute (DisputeData)
        disputes[++totalDisputes] = DisputeData({
            assetID: assetID,
            reason: reason,
            solution: "",
            status: "submitted",
            closed: false
        });
        // Register dispute (VerificationData)
        verifications[assetID].disputes.push(totalDisputes);

        emit DisputeRaised(assetID, totalDisputes, reason, accountID);
    }

//Only Verifier
    function resolveDispute(
        string memory accountID,
        uint256 disputeID,
        string memory solution,
        string memory status,
        bool closed
    ) external whenNotPaused onlyRole(BACKEND_ROLE) {
        DisputeData dispute = disputes[disputeID];
        require(!dispute.closed, "Dispute already closed.");

        dispute.status = status;
        dispute.solution = solution;
        dispute.closed = closed;

        emit DisputeResolved(assetID, disputeID, solution, accountID);
    }

//Admin Functions
    function addVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        grantRole(BACKEND_ROLE, verifier);
        verifierReputation[verifier] = 100;
    }

    function removeVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        revokeRole(BACKEND_ROLE, verifier);
    }

    function setQTime(uint256 newQTime) external onlyRole(ADMIN_ROLE) {
        qTime = newQTime;
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Emergency function to transfer out any accidental Ether sent to the contract.
    function emergencyWithdraw() external onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC721Enumerable) returns (bool) {
        return
            AccessControl.supportsInterface(interfaceId) ||
            ERC721Enumerable.supportsInterface(interfaceId);
    }
}
