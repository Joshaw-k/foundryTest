// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";

contract Marketplace {
    using ECDSA for bytes32;
    using Counters for Counters.Counter;

    enum ListingStatus { Inactive, Active }

    struct Listing {
        address seller;
        address token;
        uint256 tokenId;
        uint256 price;
        ListingStatus status;
        uint256 deadline;
        bytes signature;
    }

    mapping(uint256 => Listing) public _listings;

    Counters.Counter private listingIdCounter;

    modifier onlyTokenOwner(uint256 listingId) {
        require(msg.sender == _listings[listingId].tokenOwner, "Not the token owner");
        _;
    }

    modifier onlyActiveOrder(uint256 listingId) {
        require(_listings[listingId].status == ListingStatus.Active, "Order is not active");
        _;
    }

    modifier onlyBeforeDeadline(uint256 listingId) {
        require(block.timestamp <= _listings[listingId].deadline, "Order has expired");
        _;
    }

    event OrderCreated(uint256 orderId, address tokenOwner, address tokenAddress, uint256 tokenId, uint256 price, uint256 deadline);
    event OrderCancelled(uint256 orderId);
    event OrderFulfilled(uint256 orderId, address buyer);

    function createListing(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes memory _signature
    ) external {
        require(_price > 0, "Price must be greater than zero");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        bytes32 orderHash = keccak256(abi.encodePacked(_tokenAddress, _tokenId, _price, msg.sender, _deadline));
        require(orderHash.recover(_signature) == msg.sender, "Invalid signature");

        _listings[orderIdCounter.current()] = Listing({
            tokenOwner: msg.sender,
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            price: _price,
            status: ListingStatus.Active,
            deadline: _deadline,
            signature: _signature
        });

        emit OrderCreated(
            orderIdCounter.current(),
            msg.sender,
            _tokenAddress,
            _tokenId,
            _price,
            _deadline
        );

        orderIdCounter.increment();
    }

    function cancelListing(uint256 listingId) external onlyTokenOwner(listingId) onlyActiveOrder(listingId) {
        _listings[listingId].status = ListingStatus.Inactive;
        emit OrderCancelled(listingId);
    }

    function fulfillListing(uint256 listingId) external payable onlyActiveOrder(listingId) onlyBeforeDeadline(listingId) {
        require(msg.value == _listings[listingId].price, "Incorrect payment amount");

        // Transfer the token to the buyer
        IERC721(_listings[listingId].tokenAddress).transferFrom(_listings[listingId].tokenOwner, msg.sender, _listings[listingId].tokenId);

        // Transfer the payment to the seller
        payable(_listings[listingId].tokenOwner).transfer(msg.value);

        // Mark the order as fulfilled
        _listings[listingId].status = ListingStatus.Inactive;

        emit OrderFulfilled(listingId, msg.sender);
    }
}