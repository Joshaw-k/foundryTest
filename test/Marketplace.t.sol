// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Marketplace} from "../src/Marketplace.sol";
import "../src/AlexiaToken.sol";
import "./Signatures.sol";

contract MarketPlaceTest is Helpers {
    Alexia alexia;

    uint256 currentListingId;

    address publicAddress1;
    address publicAddress2;

    uint256 privateKey1;
    uint256 privateKey2;

    Marketplace marketplace;

    Marketplace.Listing listing;

    function setUp() public {
        marketplace = new Marketplace();
        alexia = new Alexia();

        (publicAddress1, privateKey1) = mkaddr("publicAddress1");
        (publicAddress2, privateKey2) = mkaddr("publicAddress2");

        listing = Marketplace.Listing({
            token: address(alexia),
            tokenId: 1,
            price: 1 ether,
            signature: bytes(""),
            deadline: 0,
            seller: address(0),
            status: listing.status
        });

        alexia.mint(publicAddress1, 1);
    }

    function testValidSig() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
        listing.deadline = block.timestamp + 120 minutes;
        listing.signature = constructSig(
            listing.token,
            listing.tokenId,
            listing.price,
            listing.deadline,
            listing.seller,
            privKeyB
        );
        vm.expectRevert("Not Owner");
        marketplace.createListing(listing.token,listing.tokenId,listing.price,59 minutes,listing.signature);
    }

    function testNonValidListing() public {
        switchSigner(publicAddress1);
        vm.expectRevert("Not Valid Listing");
        marketplace.fulfillListing(1);
    }

    function testExpiredListing() public {
        switchSigner(publicAddress1);
        alexia.setApprovalForAll(address(marketplace), true);
    }

     function testExecute() public {
        switchSigner(publicAddress1);
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
        switchSigner(publicAddress2);(publicAddress1, privateKey1) = mkaddr("publicAddress1");
        (publicAddress2, privateKey2) = mkaddr("publicAddress2");
        uint256 publicAddress1BalanceBefore = publicAddress1.balance;

        mPlace.executeListing{value: listing.price}(lId);

        uint256 publicAddress1BalanceAfter = publicAddress1.balance;

        Marketplace.Listing memory t = mPlace.getListing(lId);
        assertEq(t.price, 1 ether);
        assertEq(t.active, false);

        assertEq(t.active, false);
        assertEq(ERC721(listing.token).ownerOf(listing.tokenId), publicAddress2);
        assertEq(publicAddress1BalanceAfter, publicAddress1BalanceBefore + listing.price);
    }

    
}