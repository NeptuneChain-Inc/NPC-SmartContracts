// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NPC_AccountManager.sol";
import "./NPC_RoleManager.sol";

interface INPCNFT {
    function ownerOf(uint256 tokenId) external view returns (address);

    function getCreditTypes(uint256 tokenId)
        external
        view
        returns (string[] memory);

    function getCreditSupplyLimit(uint256 tokenId, string calldata creditType)
        external
        view
        returns (uint256);
}

contract NeptuneChainCredits is
    ERC20,
    Pausable,
    UUPSUpgradeable,
    Initializable,
    ReentrancyGuard
{
    // Define roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BACKEND_ROLE = keccak256("BACKEND_ROLE");

        bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 public constant INVESTOR_ROLE = keccak256("INVESTOR_ROLE");

    INPCNFT public npcNFT;
    NPC_AccountManager public accountManager;
    NPC_RoleManager private roleManager;

    // Certificate data structure
    struct Certificate {
        int256 id;
        string recipient;
        string producer;
        string verifier;
        string creditType;
        int256 balance;
        int256 price;
        uint256 timestamp;
    }

    // Supply data structure
    struct Supply {
        uint256 issued;
        uint256 available;
        uint256 donated;
    }

    // Mappings to store data
    mapping(string => mapping(string => mapping(string => Supply)))
        private supply;
    mapping(string => bool) private producerRegistered;
    mapping(string => mapping(string => bool)) private producerVerified;
    mapping(string => string[]) private producerVerifiers;
    mapping(int256 => Certificate) private certificatesById;
    mapping(string => int256[]) private accountCertificates;
    mapping(string => mapping(string => mapping(string => mapping(string => uint256))))
        private accountCreditBalances;
    string[] private creditTypes;
    string[] private producers;

    // Total variables
    int256 private totalSold;
    int256 private totalCertificates;

    // Recovery duration constants
    uint256 public constant MIN_RECOVERY_DURATION = 30 days;
    uint256 public recoveryDuration = 365 days;

    // Events
    event CreditsIssued(
        string indexed producer,
        string verifier,
        string creditType,
        uint256 amount
    );
    event CreditsBought(
        string indexed accountID,
        string producer,
        string verifier,
        string creditType,
        uint256 amount,
        uint256 price
    );
    event CreditsTransferred(
        string indexed senderAccountID,
        string receiverAccountID,
        string producer,
        string verifier,
        string creditType,
        uint256 amount,
        uint256 price
    );
    event CreditsDonated(
        string indexed accountID,
        string producer,
        string verifier,
        string creditType,
        uint256 amount
    );
    event CertificateCreated(
        int256 indexed certificateId,
        string indexed accountID,
        string producer,
        string verifier,
        string creditType,
        uint256 balance
    );
    event TokensRecovered(string indexed accountID, uint256 amount);

    /**
     * @dev Constructor to initialize the ERC20 token.
     */
    constructor() ERC20("NeptuneChainCredits", "NCC") {}

    /**
     * @dev Initializer function to initialize the contract.
     * @param _npcNFT Address of the NPCNFT contract.
     * @param accountManagerAddress The address of the NPC_AccountManager contract.
     * @param roleManagerAddress The address of the NPC_RoleManager contract.
     */
    function initialize(
      address _npcNFT, 
      address accountManagerAddress,
        address roleManagerAddress
        )
        public
        initializer
    {
        npcNFT = INPCNFT(_npcNFT);
                roleManager = NPC_RoleManager(roleManagerAddress);
        accountManager = NPC_AccountManager(accountManagerAddress);
    }

    modifier onlyAdmin() {
        require(
            roleManager.isOnlyAdmin(msg.sender),
            "Caller is not an admin address."
        );
        _;
    }

    modifier onlyAdminOrBackend() {
        require(
            roleManager.onlyAdminOrBackend(msg.sender),
            "Caller is not an admin or  backend address."
        );
        _;
    }

    modifier onlyRegistered(string memory accountID) {
        require(accountManager.isRegistered(accountID), "Account not registered");
        _;
    }

    modifier onlyRegisteredAndNonBlacklisted(string memory accountID) {
        require(accountManager.isNotBlacklisted(accountID), "Account not registered or is blacklisted");
        _;
    }

    modifier onlyRegisteredProducer(string memory producer) {
        require(producerRegistered[producer], "Producer not registered");
        _;
    }

    modifier onlyRegisteredVerifier(
        string memory producer,
        string memory verifier
    ) {
        require(
            producerVerified[producer][verifier],
            "Verifier not registered for this producer"
        );
        _;
    }

    modifier verifyAccountRole(string memory account, bytes32 role) {
        require(
            accountManager.verifyRole(account, role),
            "Account does not have the appropriate role"
        );
        _;
    }

    modifier balanceCovers(string memory accountID, uint256 amount) {
        require(balanceOf(accountManager.getAccountData(accountID).txAddress) >= amount, "Insufficient ERC20 balance");
        _;
    }

    modifier updateLastActive(string memory accountID) {
        accountManager.updateLastActive(accountID);
        _;
    }

    /**
     * @dev Authorize upgrade for UUPS upgradeability.
     * @param newImplementation Address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyAdmin
    {}

    /**
     * @dev Issue credits to a producer.
     * @param senderID The ID of the sender.
     * @param nftTokenId The NFT token ID.
     * @param producer The producer ID.
     * @param verifier The verifier ID.
     * @param creditType The type of credit.
     * @param amount The amount of credits to issue.
     */
    function issueCredits(
        string memory senderID,
        uint256 nftTokenId,
        string memory producer,
        string memory verifier,
        string memory creditType,
        uint256 amount
    )
        public
        onlyAdminOrBackend
        onlyRegisteredAndNonBlacklisted(senderID)
        verifyAccountRole(senderID, PRODUCER_ROLE)
        onlyRegisteredVerifier(producer, verifier)
        updateLastActive(senderID)
        returns (bool)
    {
        require(
            ownerOfNFT(senderID, nftTokenId),
            "Sender does not own the NFT"
        );
        require(
            isAllowedCreditType(nftTokenId, creditType),
            "Credit type not allowed by this NFT"
        );
        require(
            amount <= npcNFT.getCreditSupplyLimit(nftTokenId, creditType),
            "Exceeds allowed supply limit"
        );

        _mint(address(this), amount);

        Supply storage _supply = supply[producer][verifier][creditType];
        _supply.issued += amount;
        _supply.available += amount;

        emit CreditsIssued(producer, verifier, creditType, amount);
        return true;
    }

    /**
     * @dev Buy credits from a producer.
     * @param accountID The ID of the buyer account.
     * @param producer The producer ID.
     * @param verifier The verifier ID.
     * @param creditType The type of credit.
     * @param amount The amount of credits to buy.
     * @param price The price per credit.
     */
    function buyCredits(
        string memory accountID,
        string memory producer,
        string memory verifier,
        string memory creditType,
        uint256 amount,
        uint256 price
    )
        public
        onlyAdminOrBackend
        onlyRegisteredAndNonBlacklisted(accountID)
        verifyAccountRole(accountID, INVESTOR_ROLE)
        updateLastActive(accountID)
        nonReentrant
    {
        require(
            producerVerified[producer][verifier],
            "Verifier not registered for this producer"
        );
        Supply storage _supply = supply[producer][verifier][creditType];
        require(_supply.available >= amount, "Not enough credits available");
        require(balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");

        _transfer(address(this), accountManager.getAccountData(accountID).txAddress, amount);

        _supply.available -= amount;
        accountCreditBalances[accountID][producer][verifier][
            creditType
        ] += amount;
        totalSold += int256(amount);

        _mintCertificate(accountID, producer, verifier, creditType, amount, price);

        emit CreditsBought(
            accountID,
            producer,
            verifier,
            creditType,
            amount,
            price
        );
    }

    /**
     * @dev Transfer credits to another account.
     * @param senderID The ID of the sender.
     * @param recipientID The ID of the recipient.
     * @param producer The producer ID.
     * @param verifier The verifier ID.
     * @param creditType The type of credit.
     * @param amount The amount of credits to transfer.
     * @param price The price per credit.
     */
    function transferCredits(
        string memory senderID,
        string memory recipientID,
        string memory producer,
        string memory verifier,
        string memory creditType,
        uint256 amount,
        uint256 price
    )
        public
        onlyAdminOrBackend
        onlyRegisteredAndNonBlacklisted(senderID)
        onlyRegisteredAndNonBlacklisted(recipientID)
        onlyRegisteredVerifier(producer, verifier)
        updateLastActive(senderID)
        nonReentrant
    {
        require(
            accountCreditBalances[senderID][producer][verifier][creditType] >=
                amount,
            "Insufficient balance"
        );

        accountCreditBalances[senderID][producer][verifier][
            creditType
        ] -= amount;
        accountCreditBalances[recipientID][producer][verifier][
            creditType
        ] += amount;

        _transfer(
            accountManager.getAccountData(senderID).txAddress,
            accountManager.getAccountData(recipientID).txAddress,
            amount
        );

        _mintCertificate(recipientID, producer, verifier, creditType, amount, price);

        emit CreditsTransferred(
            senderID,
            recipientID,
            producer,
            verifier,
            creditType,
            amount,
            price
        );
    }

    /**
     * @dev Donate credits.
     * @param senderID The ID of the sender.
     * @param producer The producer ID.
     * @param verifier The verifier ID.
     * @param creditType The type of credit.
     * @param amount The amount of credits to donate.
     */
    function donateCredits(
        string memory senderID,
        string memory producer,
        string memory verifier,
        string memory creditType,
        uint256 amount
    )
        public
        onlyAdminOrBackend
        onlyRegisteredAndNonBlacklisted(senderID)
        onlyRegisteredVerifier(producer, verifier)
        updateLastActive(senderID)
        nonReentrant
    {
        require(
            accountCreditBalances[senderID][producer][verifier][creditType] >=
                amount,
            "Insufficient balance"
        );

        accountCreditBalances[senderID][producer][verifier][
            creditType
        ] -= amount;
        supply[producer][verifier][creditType].donated += amount;

        _burn(accountManager.getAccountData(senderID).txAddress, uint256(amount));

        emit CreditsDonated(senderID, producer, verifier, creditType, amount);
    }

    function registerProducer(
        string memory producer
    ) external onlyAdminOrBackend {
      string memory _producer = _toLowerCase(producer);
        require(!producerRegistered[_producer], "Producer already registered");
        producerRegistered[_producer] = true;
        producers.push(_producer);
    }

    function registerVerifier(
        string memory producer,
        string memory verifier
    )
        external
        onlyAdminOrBackend
        onlyRegisteredProducer(producer)
    {
      string memory _verifier = _toLowerCase(verifier);
        require(
            !producerVerified[producer][_verifier],
            "Verifier already registered for this producer"
        );

        producerVerified[producer][_verifier] = true;
        producerVerifiers[producer].push(_verifier);
    }

    function setRecoveryDuration(
        uint256 duration
    ) external onlyAdmin {
        require(duration >= MIN_RECOVERY_DURATION, "Duration too short");
        recoveryDuration = duration;
    }

    /**
     * @dev Pause contract.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpause contract.
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    function _mintCertificate(string memory recipient, string memory producer, string memory verifier, string memory creditType, uint256 amount, uint256 price) internal {
         int256 certificateId = ++totalCertificates;
        certificatesById[certificateId] = Certificate({
            id: certificateId,
            recipient: recipient,
            producer: producer,
            verifier: verifier,
            creditType: creditType,
            balance: int256(amount),
            price: int256(price),
            timestamp: block.timestamp
        });
        accountCertificates[recipient].push(certificateId);

        emit CertificateCreated(
            certificateId,
            recipient,
            producer,
            verifier,
            creditType,
            amount
        );
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
     * @dev Check if the sender owns the NFT.
     * @param accountID The ID of the account.
     * @param tokenId The NFT token ID.
     * @return True if the sender owns the NFT, false otherwise.
     */
    function ownerOfNFT(string memory accountID, uint256 tokenId)
        internal
        view
        returns (bool)
    {
        return npcNFT.ownerOf(tokenId) == accountManager.getAccountData(accountID).txAddress;
    }

    /**
     * @dev Check if the credit type is allowed by the NFT.
     * @param tokenId The NFT token ID.
     * @param creditType The type of credit.
     * @return True if the credit type is allowed, false otherwise.
     */
    function isAllowedCreditType(uint256 tokenId, string memory creditType)
        internal
        view
        returns (bool)
    {
        string[] memory allowedCreditTypes = npcNFT.getCreditTypes(tokenId);
        for (uint256 i = 0; i < allowedCreditTypes.length; i++) {
            if (
                keccak256(abi.encodePacked(allowedCreditTypes[i])) ==
                keccak256(abi.encodePacked(creditType))
            ) {
                return true;
            }
        }
        return false;
    }
}