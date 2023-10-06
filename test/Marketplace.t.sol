// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Marketplace} from "../src/Marketplace.sol";
import "../src/AlexiaToken.sol";
import "./Helpers.sol";

contract MarketPlaceTest is Helpers {
    Marketplace mPlace;
    Alexia alexia;

    uint256 currentListingId;

    address userA;
    address userB;

    uint256 privKeyA;
    uint256 privKeyB;

    Marketplace.Listing listing;

    function setUp() public {
        mPlace = new Marketplace();
        alexia = new Alexia();

        (userA, privKeyA) = mkaddr("USERA");
        (userB, privKeyB) = mkaddr("USERB");

        listing = Marketplace.Listing({
            token: address(alexia),
            tokenId: 1,
            price: 1 ether,
            signature: bytes(""),
            deadline: 0,
            seller: address(0),
            status: listing.status
        });

        alexia.mint(userA, 1);
    }

    function testOwnerCannotCreateListing() public {
        listing.seller = userB;
        switchSigner(userB);

        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.createListing(listing);
    }

    function testNonApprovedNFT() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.NotApproved.selector);
        mPlace.createListing(listing);
    }

    function testMinPriceTooLow() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.price = 0;
        vm.expectRevert(Marketplace.MinPriceTooLow.selector);
        mPlace.createListing(listing);
    }

    function testMinDeadline() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        vm.expectRevert(Marketplace.DeadlineTooSoon.selector);
        mPlace.createListing(listing);
    }

    function testMinDuration() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 59 minutes);
        vm.expectRevert(Marketplace.MinDurationNotMet.selector);
        mPlace.createListing(listing);
    }

    function testValidSig() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyB
        );
        vm.expectRevert(Marketplace.InvalidSignature.selector);
        mPlace.createListing(listing);
    }

    // EDIT LISTING
    function testEditNonValidListing() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.ListingNotExistent.selector);
        mPlace.editListing(1, 0, false);
    }

    function testEditListingNotOwner() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        // vm.expectRevert(Marketplace.ListingNotExistent.selector);
        uint256 lId = mPlace.createListing(listing);

        switchSigner(userB);
        vm.expectRevert(Marketplace.NotOwner.selector);
        mPlace.editListing(lId, 0, false);
    }

    function testEditListing() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        uint256 lId = mPlace.createListing(listing);
        mPlace.editListing(lId, 0.01 ether, false);

        Marketplace.Listing memory t = mPlace.getListing(lId);
        assertEq(t.price, 0.01 ether);
        assertEq(t.active, false);
    }

    // EXECUTE LISTING
    function testExecuteNonValidListing() public {
        switchSigner(userA);
        vm.expectRevert(Marketplace.ListingNotExistent.selector);
        mPlace.executeListing(1);
    }

    function testExecuteExpiredListing() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
    }

    function testExecuteListingNotActive() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        uint256 lId = mPlace.createListing(listing);
        mPlace.editListing(lId, 0.01 ether, false);
        switchSigner(userB);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        mPlace.executeListing(lId);
    }

    function testExecutePriceNotMet() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        uint256 lId = mPlace.createListing(listing);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceNotMet.selector,
                listing.price - 0.9 ether
            )
        );
        mPlace.executeListing{value: 0.9 ether}(lId);
    }

    function testExecutePriceMismatch() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        uint256 lId = mPlace.createListing(listing);
        switchSigner(userB);
        vm.expectRevert(
            abi.encodeWithSelector(Marketplace.PriceMismatch.selector, listing.price)
        );
        mPlace.executeListing{value: 1.1 ether}(lId);
    }

    function testExecute() public {
        switchSigner(userA);
        alexia.setApprovalForAll(address(mPlace), true);
        listing.deadline = uint88(block.timestamp + 120 minutes);
        // listing.price = 1 ether;
        listing.sig = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyA
        );
        uint256 lId = mPlace.createListing(listing);
        switchSigner(userB);
        uint256 userABalanceBefore = userA.balance;

        mPlace.executeListing{value: listing.price}(lId);

        uint256 userABalanceAfter = userA.balance;

        Marketplace.Listing memory t = mPlace.getListing(lId);
        assertEq(t.price, 1 ether);
        assertEq(t.active, false);

        assertEq(t.active, false);
        assertEq(ERC721(listing.token).ownerOf(listing.tokenId), userB);
        assertEq(userABalanceAfter, userABalanceBefore + listing.price);
    }
}

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";