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
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    int256 qTime = 1 hours;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); // Define DEFAULT_ADMIN_ROLE

    struct VerificationData {
        address farmer;
        string ipfsMetadataHash; // IPFS hash for data
        bool approved;
    }

    mapping(address => uint256) public verifierReputation;
    mapping(uint256 => VerificationData) public verifications;
    mapping(address => uint256) public lastSubmission;


    event DataSubmitted(uint256 dataId, address indexed farmer);
    event Verified(uint256 dataId, address indexed verifier);
    event DisputeRaised(uint256 dataId, address indexed farmer, string reason);
    event DisputeResolved(uint256 dataId, address indexed admin, bool approved);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(VERIFIER_ROLE, msg.sender);
    }

    modifier rateLimited(address user) {
        require(
            int256(block.timestamp - lastSubmission[user]) > qTime,
            "You need to wait for 1 hour between submissions."
        );
        _;
    }

    function submitData(string memory ipfsMetadataHash) external whenNotPaused rateLimited(msg.sender) returns (uint256) {
        verifications[totalSupply()] = VerificationData({
            farmer: msg.sender,
            ipfsMetadataHash: ipfsMetadataHash,
            approved: false
        });
        lastSubmission[msg.sender] = block.timestamp;
        emit DataSubmitted(totalSupply(), msg.sender);
        return totalSupply();
    }

    function approveData(uint256 dataId) external whenNotPaused onlyRole(VERIFIER_ROLE) {
        require(!verifications[dataId].approved, "Data already verified.");

        if (advancedDataValidation(verifications[dataId].ipfsMetadataHash)) {
            verifications[dataId].approved = true;
            verifierReputation[msg.sender] += 1;
            _mint(verifications[dataId].farmer, dataId);

            emit Verified(dataId, msg.sender);
        } else {
            verifierReputation[msg.sender] -= 1;
        }
    }

    function raiseDispute(uint256 dataId, string memory reason) external whenNotPaused {
        require(
            verifications[dataId].farmer == msg.sender,
            "Only the data submitter can raise a dispute."
        );

        emit DisputeRaised(dataId, msg.sender, reason);
    }

    function resolveDispute(uint256 dataId, bool approved) external whenNotPaused onlyRole(ADMIN_ROLE) {
        require(!verifications[dataId].approved, "Data already verified.");

        verifications[dataId].approved = approved;
        if (approved) {
            _mint(verifications[dataId].farmer, dataId);
        }

        emit DisputeResolved(dataId, msg.sender, approved);
    }

    function advancedDataValidation(string memory ipfsMetadataHash) internal pure returns(bool) {
        // Implement advanced validation logic. Could involve off-chain computation and proofs.
        // For this placeholder, assume data is always valid.
        return bytes(ipfsMetadataHash).length > 0;
    }


    function addVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        grantRole(VERIFIER_ROLE, verifier);
        verifierReputation[verifier] = 100;
    }

    function removeVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        revokeRole(VERIFIER_ROLE, verifier);
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

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl, ERC721Enumerable) returns (bool) {
    return AccessControl.supportsInterface(interfaceId) || ERC721Enumerable.supportsInterface(interfaceId);
}
}