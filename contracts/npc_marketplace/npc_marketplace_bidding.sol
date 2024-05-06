// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./npc_marketplace_core.sol";

contract MarketplaceBidding is MarketplaceCore {
    struct Bid {
        address bidder;
        uint256 amount;
    }

    // Mapping from listing ID to the highest bid
    mapping(uint256 => Bid) public highestBids;

    event BidPlaced(uint256 indexed listingId, address indexed bidder, uint256 amount);
    event BidWithdrawn(uint256 indexed listingId, address indexed bidder, uint256 amount);
    event BidAccepted(uint256 indexed listingId, address indexed seller, address indexed bidder, uint256 amount);

    function placeBid(uint256 listingId) public payable virtual nonReentrant {
        Listing memory listing = listings[listingId];
        require(listing.price > 0, "Listing not active");
        require(msg.value > highestBids[listingId].amount, "Bid too low");

        // Refund the previous highest bidder
        if (highestBids[listingId].amount > 0) {
            payable(highestBids[listingId].bidder).transfer(highestBids[listingId].amount);
        }

        highestBids[listingId] = Bid(msg.sender, msg.value);
        emit BidPlaced(listingId, msg.sender, msg.value);
    }

    function acceptBid(uint256 listingId) public virtual nonReentrant {
        Listing memory listing = listings[listingId];
        Bid memory bid = highestBids[listingId];
        require(listing.seller == msg.sender, "Caller is not the seller");
        require(listing.price > 0, "Listing not active");
        require(bid.amount > 0, "No bid to accept");

        delete listings[listingId];
        delete highestBids[listingId];

        IERC721(listing.tokenAddress).transferFrom(address(this), bid.bidder, listing.tokenId);
        payable(listing.seller).transfer(bid.amount);

        emit BidAccepted(listingId, msg.sender, bid.bidder, bid.amount);
        emit Sale(listingId, msg.sender, listing.tokenAddress, listing.tokenId, listing.price);

    }

    // Additional functions and modifications can be added as required
}