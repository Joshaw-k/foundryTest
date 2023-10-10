// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721Facet} from "./ERC721Facet.sol";

contract Alexia is ERC721Facet {
    function tokenURI(
        uint256 id
    ) public view virtual override returns (string memory) {
        return "Scam";
    }

    function mint(address recipient, uint256 tokenId) public payable {
        _mint(recipient, tokenId);
    }
}
