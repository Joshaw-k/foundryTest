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

    //public and private address of the users
    address publicAddress1;
    address publicAddress2;
    uint256 privateKey1;
    uint256 privateKey2;

     Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;

    function setUp() public {
    //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet),"ALEXIA","ALX");
        dLoupe = new DiamondLoupeFacet();

        // Deploying the Alexia NFT contract and storing it's returning object
        alexia = new Alexia();

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](2);

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

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        //storing the key pairs from the addressPair function
        (publicAddress1, privateKey1) = addressPair("publicAddress1");
        (publicAddress2, privateKey2) = addressPair("publicAddress2");

        //minting to an address
        alexia.mint(publicAddress1, 1);
    }

    function testTokenName() public {
        assertEq(Alexia(address(diamond)).name(), "ALEXIA");
    }

    function testTokenSymbol() public {
        assertEq(Alexia(address(diamond)).symbol(), "ALX");
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {} 
}