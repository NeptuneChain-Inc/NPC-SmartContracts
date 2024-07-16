// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NPC_AccountManager.sol";
import "./NPC_RoleManager.sol";

/**
 * @title NeptuneChainVerification
 * @dev This contract manages the verification of assets using ERC721 tokens. It integrates with NPC_AccountManager for centralized account management and NPC_RoleManager for centralized role management.
 */
contract NeptuneChainVerification is
    ERC721Enumerable,
    Pausable,
    ReentrancyGuard
{
    NPC_RoleManager private roleManager;
    NPC_AccountManager private accountManager;

    int256 public qTime = 0.1 hours;

    struct VerificationData {
        uint256 id;
        string accountID;
        bool approved;
        uint256[] disputes;
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

    // NFT credit types and supply limit mapping
    mapping(uint256 => string[]) private _creditTypes;
    mapping(uint256 => mapping(string => uint256)) private _creditSupplyLimits;

    mapping(string => VerificationData) public verifications; // assetID => VerificationData
    mapping(uint256 => DisputeData) public disputes; // disputeID => DisputeData
    mapping(string => uint256) public lastSubmission; // accountID => timestamp
    mapping(string => uint256) public verifierReputation; // accountID => score

    event CreditTypesUpdated(uint256 indexed tokenId, string[] creditTypes);
    event CreditSupplyLimitUpdated(
        uint256 indexed tokenId,
        string creditType,
        uint256 supplyLimit
    );

    event AssetSubmitted(uint256 id, string assetID, string accountID);
    event AssetVerified(uint256 id, string assetID, string accountID);
    event DisputeRaised(
        string assetID,
        uint256 disputeID,
        string reason,
        string accountID
    );
    event DisputeResolved(
        string assetID,
        uint256 disputeID,
        string solution,
        string accountID
    );

    /**
     * @dev Initializes the contract
     * @param accountManagerAddress The address of the NPC_AccountManager contract.
     * @param roleManagerAddress The address of the NPC_RoleManager contract.
     */
    constructor(address accountManagerAddress, address roleManagerAddress)
        ERC721("NeptuneChain", "NPC")
    {
        roleManager = NPC_RoleManager(roleManagerAddress);
        accountManager = NPC_AccountManager(accountManagerAddress);
    }

    modifier onlyAdmin() {
        require(
            roleManager.isOnlyAdmin(msg.sender),
            "Caller is not a backend address."
        );
        _;
    }

    modifier onlyBackend() {
        require(
            roleManager.isBackendAddress(msg.sender),
            "Caller is not a backend address."
        );
        _;
    }

    modifier notBlacklisted(string memory accountID) {
        require(
            accountManager.isNotBlacklisted(accountID),
            "Caller is not a backend address."
        );
        _;
    }

    modifier rateLimited(string memory accountID) {
        require(
            int256(block.timestamp - lastSubmission[accountID]) > qTime,
            "You need to wait before another submission."
        );
        _;
    }

    modifier isVerifier(string memory accountID) {
        NPC_AccountManager.AccountData memory account = accountManager
            .getAccountData(accountID);
        require(
            keccak256(abi.encodePacked(account.role)) == keccak256("verifier"),
            "User is not a verifier."
        );
        _;
    }

    modifier isAsset(string memory assetID) {
        require(verifications[assetID].id > 0, "Asset does not exist");
        _;
    }

    modifier isDispute(uint256 disputeID) {
        require(
            disputes[disputeID].closed == false,
            "Dispute does not exist or closed"
        );
        _;
    }

    /**
     * @dev Get the credit types associated with an NFT.
     * @param tokenId The ID of the NFT.
     * @return The credit types associated with the NFT.
     */
    function getCreditTypes(uint256 tokenId)
        external
        view
        returns (string[] memory)
    {
        return _creditTypes[tokenId];
    }

    /**
     * @dev Get the supply limit for a specific credit type of an NFT.
     * @param tokenId The ID of the NFT.
     * @param creditType The credit type to get the supply limit for.
     * @return The supply limit for the credit type.
     */
    function getCreditSupplyLimit(uint256 tokenId, string calldata creditType)
        external
        view
        returns (uint256)
    {
        return _creditSupplyLimits[tokenId][creditType];
    }

    /**
     * @dev Submit a new asset for verification.
     * @param accountID The ID of the account submitting the asset.
     * @param assetID The ID of the asset to submit.
     * @return The ID of the submitted asset.
     */
    function submitAsset(string memory accountID, string memory assetID)
        external
        whenNotPaused
        onlyBackend
        rateLimited(accountID)
        notBlacklisted(accountID)
        returns (uint256)
    {
        VerificationData storage verification = verifications[assetID];
        verification.id = ++totalSubmissions;
        verification.accountID = accountID;
        verification.approved = false;

        lastSubmission[accountID] = block.timestamp;
        emit AssetSubmitted(totalSubmissions, assetID, accountID);
        return totalSubmissions;
    }

    /**
     * @dev Approve a submitted asset.
     * @param accountID The ID of the verifier account approving the asset.
     * @param assetID The ID of the asset to approve.
     * @param creditTypes The types of credits associated with the NFT.
     * @param creditSupplyLimits The supply limits for each credit type.
     */
    function approveAsset(
        string memory accountID,
        string memory assetID,
        string[] memory creditTypes,
        uint256[] memory creditSupplyLimits
    )
        external
        whenNotPaused
        onlyBackend
        notBlacklisted(accountID)
        isVerifier(accountID)
        isAsset(assetID)
    {
        VerificationData storage verification = verifications[assetID];
        require(!verification.approved, "Data already verified.");
        require(
            creditTypes.length == creditSupplyLimits.length,
            "Credit types and supply limits length mismatch"
        );

        uint256 tokenId = verification.id;

        NPC_AccountManager.AccountData memory account = accountManager
            .getAccountData(verification.accountID);
        _mint(account.txAddress, tokenId);

        // Manually copy each element
        for (uint256 i = 0; i < creditTypes.length; i++) {
            _creditTypes[tokenId].push(creditTypes[i]);
            _creditSupplyLimits[tokenId][creditTypes[i]] = creditSupplyLimits[
                i
            ];
        }

        emit CreditTypesUpdated(tokenId, creditTypes);
        for (uint256 i = 0; i < creditTypes.length; i++) {
            emit CreditSupplyLimitUpdated(
                tokenId,
                creditTypes[i],
                creditSupplyLimits[i]
            );
        }

        verification.approved = true;
        verifierReputation[accountID]++;
        totalApprovals++;
        emit AssetVerified(tokenId, assetID, accountID);
    }

    /**
     * @dev Raise a dispute for an asset.
     * @param accountID The ID of the account raising the dispute.
     * @param assetID The ID of the asset to dispute.
     * @param reason The reason for the dispute.
     */
    function raiseDispute(
        string memory accountID,
        string memory assetID,
        string memory reason
    )
        external
        whenNotPaused
        onlyBackend
        notBlacklisted(accountID)
        isAsset(assetID)
    {
        require(
            keccak256(abi.encodePacked(verifications[assetID].accountID)) ==
                keccak256(abi.encodePacked(accountID)),
            "Only the data submitter can raise a dispute."
        );

        disputes[++totalDisputes] = DisputeData({
            assetID: assetID,
            reason: reason,
            solution: "",
            status: "submitted",
            closed: false
        });
        verifications[assetID].disputes.push(totalDisputes);

        emit DisputeRaised(assetID, totalDisputes, reason, accountID);
    }

    /**
     * @dev Resolve a dispute for an asset.
     * @param accountID The ID of the verifier account resolving the dispute.
     * @param disputeID The ID of the dispute to resolve.
     * @param solution The solution to the dispute.
     * @param status The status of the dispute.
     */
    function resolveDispute(
        string memory accountID,
        uint256 disputeID,
        string memory solution,
        string memory status
    )
        external
        whenNotPaused
        onlyBackend
        notBlacklisted(accountID)
        isDispute(disputeID)
    {
        DisputeData storage dispute = disputes[disputeID];

        dispute.status = status;
        dispute.solution = solution;
        dispute.closed = true;

        emit DisputeResolved(dispute.assetID, disputeID, solution, accountID);
    }

    /**
     * @dev Set the query time interval.
     * @param newQTime The new query time interval in seconds.
     */
    function setQTime(int256 newQTime) external onlyAdmin {
        qTime = newQTime;
    }

    /**
     * @dev Pause the contract.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpause the contract.
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev Emergency function to transfer out any accidental Ether sent to the contract.
     */
    function emergencyWithdraw() external onlyAdmin {
        payable(msg.sender).transfer(address(this).balance);
    }
}
