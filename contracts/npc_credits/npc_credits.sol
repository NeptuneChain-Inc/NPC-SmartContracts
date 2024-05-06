// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CreditContract {
    address private contractOwner;
    int256 private totalSupply;
    int256 private totalDonatedSupply;
    int256 private totalSold;
    int256 private totalCertificates;
    string[] private producers;

    mapping(string => mapping(string => mapping(string => Supply))) private supply;
    mapping(string => bool) private producerRegistered;
    mapping(string => mapping(string => bool)) private producerVerified;
    mapping(string => string[]) private producerVerifiers;
    mapping(int256 => Certificate) private certificatesById;
    mapping(string => int256[]) private accountCertificates;
    mapping(string => mapping(string => mapping(string => mapping(string => int256))))
        private accountBalance;
    mapping(string => int256) private accountTotalBalance;
    mapping(string => bool) private creditRegistered;
    string[] private creditTypes;

    struct Certificate {
        int256 id;
        string buyer;
        string producer;
        string verifier;
        string creditType;
        int256 balance;
        int256 price;
        uint256 timestamp;
    }

    struct Supply {
        int256 issued;
        int256 available;
        int256 donated;
    }

    event CreditsIssued( string producer, string verifier, string creditType, int256 amount);
    event CreditsBought(
        string accountID,
        string producer,
        string verifier,
        string creditType,
        int256 amount,
        int256 price
    );
    event CreditsTransferred(
        string senderAccountID,
        string receiverAccountID,
        string producer,
        string verifier,
        string creditType,
        int256 amount,
        int256 price
    );
    event CreditsDonated(
        string accountID,
        string producer,
        string verifier,
        string creditType,
        int256 amount
    );
    event CertificateCreated(
        int256 certificateId,
        string accountID,
        string producer,
        string verifier,
        string creditType,
        int256 balance
    );
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        contractOwner = msg.sender;
    }

    modifier onlyOwner() {
        require(
            msg.sender == contractOwner,
            "Only the contract owner can call this function."
        );
        _;
    }

    function getOwner() public view returns (address _owner) {
        _owner = contractOwner;
    }

    function getTotalSupply() public view returns (int256 _totalSupply) {
        _totalSupply = totalSupply;
    }

    function getTotalDonatedSupply()
        public
        view
        returns (int256 _totalDonatedSupply)
    {
        _totalDonatedSupply = totalDonatedSupply;
    }

    function getTotalCertificates()
        public
        view
        returns (int256 _totalCertificates)
    {
        _totalCertificates = totalCertificates;
    }

    function getCertificateById(
        int256 certificateId
    ) public view returns (Certificate memory _certificate) {
        _certificate = certificatesById[certificateId];
    }

    function getProducers() public view returns (string[] memory _producers) {
        _producers = producers;
    }

    function getProducerVerifiers(
        string memory producer
    ) public view returns (string[] memory _producerVerifiers) {
        _producerVerifiers = producerVerifiers[_toLowerCase(producer)];
    }

    function isCreditRegistered(
        string memory creditType
    ) public view returns (bool _creditRegistered) {
        _creditRegistered = creditRegistered[_toLowerCase(creditType)];
    }

    function getCreditTypes() public view returns(string[] memory _creditTypes) {
        _creditTypes = creditTypes;
    }
    function getSupply(
        string memory producer,
        string memory verifier,
        string memory creditType
    ) public view returns (Supply memory _supply) {
        _supply = supply[_toLowerCase(producer)][
            _toLowerCase(verifier)
        ][_toLowerCase(creditType)];
    }

    function getTotalSold() public view returns(int256 _totalSold) {
       _totalSold = totalSold;
    }

    function getAccountBalance(
        string memory accountID,
        string memory producer,
        string memory verifier,
        string memory creditType
    ) public view returns (int256 _accountBalance) {
        _accountBalance = accountBalance[_toLowerCase(accountID)][
            _toLowerCase(producer)
        ][_toLowerCase(verifier)][_toLowerCase(creditType)];
    }

    function getAccountTotalBalance(
        string memory accountID
    ) public view returns (int256 _accountTotalBalance) {
        _accountTotalBalance = accountTotalBalance[_toLowerCase(accountID)];
    }

    function getAccountCertificates(
        string memory accountID
    ) public view returns (int256[] memory _accountCertificates) {
        _accountCertificates = accountCertificates[_toLowerCase(accountID)];
    }

    function isProducerRegistered(
        string memory producer
    ) public view returns (bool _producerRegistered) {
        _producerRegistered = producerRegistered[_toLowerCase(producer)];
    }

    function isProducerVerified(
        string memory producer,
        string memory verifier
    ) public view returns (bool _producerVerified) {
        _producerVerified = producerVerified[_toLowerCase(producer)][
            _toLowerCase(verifier)
        ];
    }

    function issueCredits(
        string memory _producer,
        string memory _verifier,
        string memory _creditType,
        int256 amount
    ) public onlyOwner returns (bool _issued) {
        string memory producer = _toLowerCase(_producer);
        string memory verifier = _toLowerCase(_verifier);
        string memory creditType = _toLowerCase(_creditType);
        if(!isCreditRegistered(creditType)){
            creditTypes.push(creditType);
            creditRegistered[creditType] = true;
        }
        totalSupply += amount;
        Supply storage _supply = supply[producer][verifier][creditType];
        _supply.issued += amount;
        _supply.available += amount;
        _supply.donated += 0;
        if (!producerRegistered[producer]) {
            producers.push(producer);
            producerRegistered[producer] = true;
        }
        if (!producerVerified[producer][verifier]) {
            producerVerifiers[producer].push(verifier);
            producerVerified[producer][verifier] = true;
        }
        emit CreditsIssued(producer, verifier, creditType, amount);
        _issued = true;
    }

    function buyCredits(
        string memory _accountID,
        string memory _producer,
        string memory _verifier,
        string memory _creditType,
        int256 amount,
        int256 price
    ) public onlyOwner returns (bool _creditsBought) {
        string memory accountID = _toLowerCase(_accountID);
        string memory producer = _toLowerCase(_producer);
        string memory verifier = _toLowerCase(_verifier);
        string memory creditType = _toLowerCase(_creditType);
        require(
            supply[producer][verifier][creditType].available >= amount,
            "Insufficient issued supply from the specified producer and verifier."
        );
        supply[producer][verifier][creditType].available -= amount;
        accountTotalBalance[accountID] += amount;
        totalSold += amount;
        emit CreditsBought(accountID, producer, verifier, creditType, amount, price);
        _creditsBought = _mintCertificate(
            accountID,
            producer,
            verifier,
            creditType,
            amount,
            price
        );
    }

    function transferCredits(
        string memory senderAccountID,
        string memory receiverAccountID,
        string memory _producer,
        string memory _verifier,
        string memory _creditType,
        int256 amount,
        int256 price
    ) public onlyOwner returns (bool _creditsTransferred) {
        string memory sender = _toLowerCase(senderAccountID);
        string memory receiver = _toLowerCase(receiverAccountID);
        string memory producer = _toLowerCase(_producer);
        string memory verifier = _toLowerCase(_verifier);
        string memory creditType = _toLowerCase(_creditType);
        require(_compareStrings(sender, receiver), "Cannot transfer to self.");
        require(
            accountBalance[sender][producer][verifier][creditType] >= amount,
            "Insufficient balance"
        );
        accountBalance[sender][producer][verifier][creditType] -= amount;
        accountTotalBalance[sender] -= amount;
        accountBalance[receiver][producer][verifier][creditType] += amount;
        accountTotalBalance[receiver] += amount;
        emit CreditsTransferred(sender, receiver, producer, verifier, creditType, amount, price);
        _creditsTransferred = _mintCertificate(
            receiver,
            producer,
            verifier,
            creditType,
            amount,
            price
        );
    }

    function donateCredits(
        string memory _accountID,
        string memory _producer,
        string memory _verifier,
        string memory _creditType,
        int256 amount
    ) public onlyOwner returns (bool _creditsDonated) {
        string memory accountID = _toLowerCase(_accountID);
        string memory producer = _toLowerCase(_producer);
        string memory verifier = _toLowerCase(_verifier);
        string memory creditType = _toLowerCase(_creditType);
        require(
            accountBalance[accountID][producer][verifier][creditType] >= amount,
            "Insufficient balance"
        );
        accountBalance[accountID][producer][verifier][creditType] -= amount;
        accountTotalBalance[accountID] -= amount;
        supply[producer][verifier][creditType].donated += amount;
        totalSupply -= amount;
        totalDonatedSupply += amount;
        emit CreditsDonated(accountID, producer, verifier, creditType, amount);
        _creditsDonated = true;
    }

    function transferOwnership(
        address newOwner
    ) public onlyOwner returns (bool) {
        require(newOwner != address(0), "Invalid new owner address.");
        contractOwner = newOwner;
        emit OwnershipTransferred(contractOwner, newOwner);
        return true;
    }

    function _mintCertificate(
        string memory _accountID,
        string memory _producer,
        string memory _verifier,
        string memory _creditType,
        int256 amount,
        int256 price
    ) internal returns (bool) {
        string memory accountID = _toLowerCase(_accountID);
        string memory producer = _toLowerCase(_producer);
        string memory verifier = _toLowerCase(_verifier);
        string memory creditType = _toLowerCase(_creditType);
        totalCertificates++;
        Certificate storage cert = certificatesById[totalCertificates];
        cert.id = totalCertificates;
        cert.buyer = accountID;
        cert.producer = producer;
        cert.verifier = verifier;
        cert.creditType = creditType;
        cert.balance += amount;
        cert.price = price;
        cert.timestamp = block.timestamp;
        accountCertificates[accountID].push(cert.id);
        emit CertificateCreated(
            totalCertificates,
            accountID,
            producer,
            verifier,
            creditType,
            amount
        );
        return true;
    }

    function _toLowerCase(
        string memory _str
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        uint256 strLength = strBytes.length;

        for (uint256 i = 0; i < strLength; i++) {
            // Convert uppercase character to lowercase
            if ((uint8(strBytes[i]) >= 65) && (uint8(strBytes[i]) <= 90)) {
                strBytes[i] = bytes1(uint8(strBytes[i]) + 32);
            }
        }

        return string(strBytes);
    }

    function _compareStrings(
        string memory _str1,
        string memory _str2
    ) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(_str1)) ==
            keccak256(abi.encodePacked(_str2)));
    }
}
