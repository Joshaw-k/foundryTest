// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Marketplace} from "../src/facets/MarketplaceFacet.sol";
import "../src/facets/AlexiaNftFacet.sol";
import "./helpers/Signatures.sol";
import "../src/interfaces/IDiamondCut.sol";
import "../src/facets/DiamondCutFacet.sol";
import "../src/facets/DiamondLoupeFacet.sol";
import "../src/Diamond.sol";
import {Listing} from "../src/libraries/LibDiamond.sol";
import "./helpers/DiamondUtils.sol";

contract MarketPlaceTest is DiamondUtils, IDiamondCut,Helpers {
    //NFT contract instance
    Alexia alexia;

    //Marketplace contract instance
    Marketplace marketplace;

    //Listing Id intially starts at 0
    uint256 currentListingId;

    //public and private address of the users
    address publicAddress1;
    address publicAddress2;
    uint256 privateKey1;
    uint256 privateKey2;

    //Our Listing template struct
    Listing listing;

    //signature used to authorise creation of lisiting
    bytes signature;

     Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;

    function setUp() public {
    //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet),"ALEXIA","ALX");
        dLoupe = new DiamondLoupeFacet();
     
        // Deploying the marketplace contract and storing it's returning object
        marketplace = new Marketplace();

        // Deploying the Alexia NFT contract and storing it's returning object
        alexia = new Alexia();

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(alexia),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("Alexia")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(marketplace),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("Marketplace")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        //storing the key pairs from the addressPair function
        (publicAddress1, privateKey1) = addressPair("publicAddress1");
        (publicAddress2, privateKey2) = addressPair("publicAddress2");

        //Default Listing object during setup
        listing = Listing({
            token: address(alexia),
            tokenId: 1,
            price: 1 ether,
            sig: bytes(""),
            deadline: 70 minutes,
            lister: publicAddress1,
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

    function testTokenName() public {
        assertEq(Alexia(address(diamond)).name(), "ALEXIA");
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
        marketplace.executeListing(id);
    }

    function testListingNotActive() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        marketplace.editListing(id, listing.price, false);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.executeListing{value:listing.price}(id);
    }

    function testEditingListingNotExistent() public {
        vm.expectRevert(Marketplace.ListingNotExistent.selector);
        marketplace.editListing(2, listing.price, false);
    }

    function testEditingNotOwner() public {
        vm.startPrank(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        uint id = marketplace.createListing(listing);
        vm.stopPrank();
        vm.prank(publicAddress2);
        vm.expectRevert(Marketplace.NotOwner.selector);
        marketplace.editListing(id, listing.price, true);
    }   

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {} 
}