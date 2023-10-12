// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721Facet} from "./ERC721Facet.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import "openzeppelin/token/ERC721/ERC721.sol";


contract Alexia is ERC721 {
    constructor() ERC721("HOLA","HLX"){
    }
    function tokenURI(
        uint256 id
    ) public view virtual override returns (string memory) {
        return "Scam";
    }

    function mint(address recipient, uint256 tokenId) public payable {
        _mint(recipient, tokenId);
    }

    function burn(uint256 tokenId) public payable {
        _burn(tokenId);
    }
}
