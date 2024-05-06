# Solidity API

## CreditContract

### Contract
CreditContract : contracts/npc_credits/npc_credits.sol

 --- 
### Modifiers:
### onlyOwner

```solidity
modifier onlyOwner()
```

 --- 
### Functions:
### constructor

```solidity
constructor() public
```

### getOwner

```solidity
function getOwner() public view returns (address _owner)
```

### getTotalSupply

```solidity
function getTotalSupply() public view returns (int256 _totalSupply)
```

### getTotalDonatedSupply

```solidity
function getTotalDonatedSupply() public view returns (int256 _totalDonatedSupply)
```

### getTotalCertificates

```solidity
function getTotalCertificates() public view returns (int256 _totalCertificates)
```

### getCertificateById

```solidity
function getCertificateById(int256 certificateId) public view returns (struct CreditContract.Certificate _certificate)
```

### getProducers

```solidity
function getProducers() public view returns (string[] _producers)
```

### getProducerVerifiers

```solidity
function getProducerVerifiers(string producer) public view returns (string[] _producerVerifiers)
```

### isCreditRegistered

```solidity
function isCreditRegistered(string creditType) public view returns (bool _creditRegistered)
```

### getCreditTypes

```solidity
function getCreditTypes() public view returns (string[] _creditTypes)
```

### getSupply

```solidity
function getSupply(string producer, string verifier, string creditType) public view returns (struct CreditContract.Supply _supply)
```

### getTotalSold

```solidity
function getTotalSold() public view returns (int256 _totalSold)
```

### getAccountBalance

```solidity
function getAccountBalance(string accountID, string producer, string verifier, string creditType) public view returns (int256 _accountBalance)
```

### getAccountTotalBalance

```solidity
function getAccountTotalBalance(string accountID) public view returns (int256 _accountTotalBalance)
```

### getAccountCertificates

```solidity
function getAccountCertificates(string accountID) public view returns (int256[] _accountCertificates)
```

### isProducerRegistered

```solidity
function isProducerRegistered(string producer) public view returns (bool _producerRegistered)
```

### isProducerVerified

```solidity
function isProducerVerified(string producer, string verifier) public view returns (bool _producerVerified)
```

### issueCredits

```solidity
function issueCredits(string _producer, string _verifier, string _creditType, int256 amount) public returns (bool _issued)
```

### buyCredits

```solidity
function buyCredits(string _accountID, string _producer, string _verifier, string _creditType, int256 amount, int256 price) public returns (bool _creditsBought)
```

### transferCredits

```solidity
function transferCredits(string senderAccountID, string receiverAccountID, string _producer, string _verifier, string _creditType, int256 amount, int256 price) public returns (bool _creditsTransferred)
```

### donateCredits

```solidity
function donateCredits(string _accountID, string _producer, string _verifier, string _creditType, int256 amount) public returns (bool _creditsDonated)
```

### transferOwnership

```solidity
function transferOwnership(address newOwner) public returns (bool)
```

### _mintCertificate

```solidity
function _mintCertificate(string _accountID, string _producer, string _verifier, string _creditType, int256 amount, int256 price) internal returns (bool)
```

### _toLowerCase

```solidity
function _toLowerCase(string _str) internal pure returns (string)
```

### _compareStrings

```solidity
function _compareStrings(string _str1, string _str2) internal pure returns (bool)
```

 --- 
### Events:
### CreditsIssued

```solidity
event CreditsIssued(string producer, string verifier, string creditType, int256 amount)
```

### CreditsBought

```solidity
event CreditsBought(string accountID, string producer, string verifier, string creditType, int256 amount, int256 price)
```

### CreditsTransferred

```solidity
event CreditsTransferred(string senderAccountID, string receiverAccountID, string producer, string verifier, string creditType, int256 amount, int256 price)
```

### CreditsDonated

```solidity
event CreditsDonated(string accountID, string producer, string verifier, string creditType, int256 amount)
```

### CertificateCreated

```solidity
event CertificateCreated(int256 certificateId, string accountID, string producer, string verifier, string creditType, int256 balance)
```

### OwnershipTransferred

```solidity
event OwnershipTransferred(address previousOwner, address newOwner)
```

