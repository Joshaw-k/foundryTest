// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {SignUtils} from "../libraries/SignUtils.sol";
import {LibDiamond,Listing} from "../libraries/LibDiamond.sol";
import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract Marketplace is ERC20 {
    
    /* ERRORS */
    error NotOwner();
    error NotApproved();
    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error ListingNotExistent();
    error ListingNotActive();
    error PriceNotMet(int256 difference);
    error ListingExpired();
    error AllSharesSold();
    error PriceMismatch(uint256 originalPrice);

    /* EVENTS */
    event ListingCreated(uint256 indexed listingId, Listing);
    event ListingExecuted(uint256 indexed listingId, Listing);
    event ListingEdited(uint256 indexed listingId, Listing);

    constructor() ERC20("HOLA","HLA"){
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.admin = msg.sender;
    }

    function createListing(Listing calldata l) public returns (uint256 lId) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (ERC721(l.token).ownerOf(l.tokenId) != msg.sender) revert NotOwner();
        if (!ERC721(l.token).isApprovedForAll(msg.sender, address(this)))
            revert NotApproved();
        if (l.price < 0.01 ether) revert MinPriceTooLow();
        if (l.deadline < block.timestamp) revert DeadlineTooSoon();
        if (l.deadline - block.timestamp < 60 minutes)
            revert MinDurationNotMet();

        // Assert signature
        if (
            !SignUtils.isValid(
                SignUtils.constructMessageHash(
                    l.token,
                    l.tokenId,
                    l.price,
                    l.deadline,
                    l.lister
                ),
                l.sig,
                msg.sender
            )
        ) revert InvalidSignature();

        // append to Storage
        Listing storage li = ds.listings[ds.listingId];
        li.token = l.token;
        li.tokenId = l.tokenId;
        li.price = l.price;
        li.sig = l.sig;
        li.deadline = l.deadline;
        li.lister = msg.sender;
        li.numOfShares = l.numOfShares;
        li.numOfShareSold = l.numOfShareSold;
        li.share = l.share;
        li.active = true;

        // Emit event
        emit ListingCreated(ds.listingId, l);
        lId = ds.listingId;
        ds.listingId++;
        _mint(address(this),li.price);
        return lId;
    }

    function executeListing(uint256 _listingId) public payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_listingId >= ds.listingId) revert ListingNotExistent();
        Listing storage listing = ds.listings[_listingId];
        if (listing.numOfShareSold == listing.numOfShares) revert AllSharesSold();
        if (listing.deadline < block.timestamp) revert ListingExpired();
        if (!listing.active) revert ListingNotActive();
        if (listing.share < msg.value) revert PriceMismatch(listing.share);
        if (listing.share != msg.value)
            revert PriceNotMet(int256(listing.share) - int256(msg.value));
        _transfer(address(this), msg.sender, listing.share);
        // // Update state
        // listing.active = false;

        // // transfer
        // ERC721(listing.token).transferFrom(
        //     listing.lister,
        //     msg.sender,
        //     listing.tokenId
        // );

        // transfer eth
        uint contractOwnerFee = listing.share * 1 / 1000;
        uint listerFee = listing.share - contractOwnerFee;
        listing.numOfShareSold++;
        if (listing.numOfShareSold == listing.numOfShares) {
            listing.active = false;
        }
        payable(ds.admin).transfer(contractOwnerFee);
        payable(listing.lister).transfer(listerFee);

        // Update storage
        emit ListingExecuted(_listingId, listing);
    }

    function editListing(
        uint256 _listingId,
        bool _active
    ) public {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (_listingId >= ds.listingId) revert ListingNotExistent();
        Listing storage listing = ds.listings[_listingId];
        if (listing.lister != msg.sender) revert NotOwner();
        // listing.price = _newPrice;
        listing.active = _active;
        emit ListingEdited(_listingId, listing);
    }

    // add getter for listing
    function getListing(
        uint256 _listingId
    ) public view returns (Listing memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        // if (_listingId >= listingId)
        return ds.listings[_listingId];
    }
}