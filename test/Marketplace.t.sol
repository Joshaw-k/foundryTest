// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Marketplace} from "../src/facets/MarketplaceFacet.sol";
import "../src/facets/AlexiaNftFacet.sol";
import "./helpers/Signatures.sol";

contract MarketPlaceTest is Helpers {
    //NFT contract instance
    Alexia alexia;

    //Marketplace contract instance
    Marketplace marketplace;

    //Listing Id intially starts at 0
    uint256 currentListingId;

    //public and private address of the users
    address publicAddress1;
    address publicAddress2;
    address publicAddress3;
    uint256 privateKey1;
    uint256 privateKey2;
    uint256 privateKey3;

    //Our Listing template struct
    Marketplace.Listing listing;

    //signature used to authorise creation of lisiting
    bytes signature;

    function setUp() public {
     
        //storing the key pairs from the addressPair function
        (publicAddress1, privateKey1) = addressPair("publicAddress1");
        (publicAddress2, privateKey2) = addressPair("publicAddress2");
        (publicAddress3, privateKey3) = addressPair("publicAddress3");
        vm.deal(publicAddress1, 100 ether);
        vm.deal(publicAddress2, 100 ether);
        vm.deal(publicAddress3, 100 ether);
        // Deploying the marketplace contract and storing it's returning object
        vm.startPrank(publicAddress2);
        marketplace = new Marketplace();
        vm.stopPrank();
        // Deploying the Alexia NFT contract and storing it's returning object
        alexia = new Alexia();

        //Default Listing object during setup
        listing = Marketplace.Listing({
            token: address(alexia),
            tokenId: 1,
            price: 1 ether,
            sig: bytes(""),
            deadline: 70 minutes,
            lister: publicAddress1,
            numOfShares:20,
        numOfShareSold:0,
        share: 0.05 ether,
            active: false
        });

        //storing the signature derived from the default listing
        signature = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.lister,
            privateKey1
        );

        listing.sig = signature;

        //minting to an address
        alexia.mint(publicAddress1, 1);
    }


    function testValidSig() public {
        switchSigner(publicAddress1);
        bytes memory sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.lister,
            privateKey1
        );

        assertEq(sig, signature);
    }

    function testMinPriceTooLow() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        listing.price = 0;
        vm.expectRevert(Marketplace.MinPriceTooLow.selector);
        marketplace.createListing(listing);
    }

    function testNotOwner() public {
        switchSigner(publicAddress2);
        alexia.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(Marketplace.NotOwner.selector);
        marketplace.createListing(listing);
    }

    function testNotApproved() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(0), true);
        vm.expectRevert(Marketplace.NotApproved.selector);
        marketplace.createListing(listing);
    }

    function testDeadlineTooSoon() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        listing.deadline = 0;
        vm.expectRevert(Marketplace.DeadlineTooSoon.selector);
        marketplace.createListing(listing);
    }

    function testMinDurationNotMet() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        listing.deadline = 15 minutes;
        vm.expectRevert(Marketplace.MinDurationNotMet.selector);
        marketplace.createListing(listing);
    }

    function testListingNotExistent() public {
        switchSigner(publicAddress1);
        vm.expectRevert(Marketplace.ListingNotExistent.selector);
        marketplace.executeListing(2);
    }

    function testListingExpired() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        vm.warp(listing.deadline + 10 minutes);
        vm.expectRevert(Marketplace.ListingExpired.selector);
        marketplace.executeListing{value:listing.price}(id);
    }

    function testListingNotActive() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        marketplace.editListing(id, false);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.executeListing{value:listing.price}(id);
    }

    function testEditingListingNotExistent() public {
        vm.expectRevert(Marketplace.ListingNotExistent.selector);
        marketplace.editListing(2, false);
    }

    function testEditingNotOwner() public {
        vm.startPrank(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        vm.stopPrank();
        vm.prank(publicAddress2);
        vm.expectRevert(Marketplace.NotOwner.selector);
        marketplace.editListing(id, true);
    }   

    function testExecuteListing() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        marketplace.executeListing{value:1 ether / 20}(id);
    }

    function testNoOfSharedSold() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        marketplace.executeListing{value:1 ether / 20}(id);
        Marketplace.Listing memory executedlisting = marketplace.getListing(id);
        assertEq(executedlisting.numOfShareSold, 1);
    }

    function testBalanceOf() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        marketplace.executeListing{value:1 ether / 20}(id);
        assertEq(marketplace.balanceOf(publicAddress1), 1 ether / 20);
    }

    function testEverySharesSold() public {
        vm.startPrank(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        vm.stopPrank();
        vm.startPrank(publicAddress3);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        marketplace.executeListing{value:1 ether / 20}(id);
        Marketplace.Listing memory executedlisting = marketplace.getListing(id);
        assertEq(executedlisting.active, false);
    }
}