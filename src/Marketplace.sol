// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import {SignUtils} from "./libraries/SignUtils.sol";

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

    address public admin;
    

    constructor() {
        admin = msg.sender;
    }

    modifier onlyseller(uint256 listingId) {
        require(msg.sender == _listings[listingId].seller, "Not the token owner");
        _;
    }

    event OrderCreated(uint256 orderId, address seller, address token, uint256 tokenId, uint256 price, uint256 deadline);
    event OrderCancelled(uint256 orderId);
    event OrderFulfilled(uint256 orderId, address buyer);

    function createListing(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        bytes memory _signature
    ) external {
        require(_price > 0, "Price must be greater than zero");
        require(_deadline > block.timestamp, "Deadline must be in the future");

        bytes32 orderHash = keccak256(abi.encodePacked(_token, _tokenId, _price, msg.sender, _deadline));
        bytes32 ethSignedOrderHash = orderHash.toEthSignedMessageHash();
        require(ethSignedOrderHash.recover(_signature) == msg.sender, "Invalid signature");

        IERC721 nft = IERC721(_token);

        require(nft.ownerOf(_tokenId) == msg.sender, "You do not own this nft");

        require(nft.isApprovedForAll(msg.sender, address(this)), "Permission not granted to spent this token");

        _listings[listingIdCounter.current()] = Listing({
            seller: msg.sender,
            token: _token,
            tokenId: _tokenId,
            price: _price,
            status: ListingStatus.Active,
            deadline: _deadline,
            signature: _signature
        });

        emit OrderCreated(
            listingIdCounter.current(),
            msg.sender,
            _token,
            _tokenId,
            _price,
            _deadline
        );

        listingIdCounter.increment();
    }

    function cancelListing(uint256 listingId) external onlyseller(listingId) {
        _listings[listingId].status = ListingStatus.Inactive;
        emit OrderCancelled(listingId);
    }

    function fulfillListing(uint256 listingId) external payable {
        require(_listings[listingId].deadline > block.timestamp,"Listing Expired");
        require(_listings[listingId].status == ListingStatus.Active,"Listing not active");
        require(msg.value == _listings[listingId].price, "Incorrect payment amount");
         _listings[listingId].status = ListingStatus.Inactive;

        IERC721(_listings[listingId].token).transferFrom(_listings[listingId].seller, msg.sender, _listings[listingId].tokenId);

        payable(_listings[listingId].seller).transfer(msg.value);

        emit OrderFulfilled(listingId, msg.sender);
    }

    function getListing(uint256 listingId) external view returns (Listing memory _listing) {
        _listing = _listings[listingId];
    }
}