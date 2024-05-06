// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MarketplaceCore is ReentrancyGuard, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _listingIds;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    struct Listing {
        address seller;
        address tokenAddress;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingFee = 0.01 ether;

    event Listed(uint256 indexed listingId, address indexed seller, address indexed tokenAddress, uint256 tokenId, uint256 price);
    event Sale(uint256 indexed listingId, address indexed buyer, address indexed tokenAddress, uint256 tokenId, uint256 price);
    event ListingCancelled(uint256 indexed listingId);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    function setListingFee(uint256 fee) external onlyAdmin {
        listingFee = fee;
    }

    function listNFT(address tokenAddress, uint256 tokenId, uint256 price) external payable nonReentrant {
        require(msg.value == listingFee, "Incorrect listing fee");
        require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(price > 0, "Price must be greater than zero");

        IERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId);

        _listingIds.increment();
        uint256 listingId = _listingIds.current();
        listings[listingId] = Listing(msg.sender, tokenAddress, tokenId, price);

        emit Listed(listingId, msg.sender, tokenAddress, tokenId, price);
    }

    function buyNFT(uint256 listingId) public payable virtual nonReentrant {
        _fulfilSale(listingId, msg.sender, msg.value );
    }



    function cancelListing(uint256 listingId) external nonReentrant {
        Listing memory listing = listings[listingId];
        require(listing.seller == msg.sender, "Caller is not the seller");

        delete listings[listingId];
        IERC721(listing.tokenAddress).transferFrom(address(this), listing.seller, listing.tokenId);

        emit ListingCancelled(listingId);
    }

    // Additional utility functions and administrative controls can be added as needed
function _fulfilSale(uint256 listingId, address buyer, uint256 amount) internal nonReentrant {
        Listing memory listing = listings[listingId];
        require(listing.price > 0, "Listing not active");
        require(buyer == listing.seller, "Cannot sell to yourself");
        require(amount == listing.price, "Incorrect amount");

        delete listings[listingId];
        IERC721(listing.tokenAddress).transferFrom(address(this), buyer, listing.tokenId);
        payable(listing.seller).transfer(listing.price);

        emit Sale(listingId, msg.sender, listing.tokenAddress, listing.tokenId, listing.price);
    }
}
