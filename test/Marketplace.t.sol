// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

contract MarketplaceTest is Test {
    function constructSig(
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _price,
        uint256 _deadline,
        uint256 privKey
    ) public returns (bytes memory sig) {
        bytes32 mHash = keccak256(abi.encodePacked(_tokenAddress, _tokenId, _price, _deadline));

        mHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", mHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, mHash);
        sig = getSig(v, r, s);
    }

    function getSig(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bytes memory sig) {
        sig = bytes.concat(r, s, bytes1(v));
    }
    Counter public counter;

    function setUp() public {
        marketplace = new Marketplace();
        vm.prank(0xB5119738BB5Fe8BE39aB592539EaA66F03A77174);
        IERC721(0xD20e11e46b923a4dDE6BB44dE1913e1497Bd0E98).approve(address(counter), 2);
    }

    function test_CreateOrder() public {
        vm.startPrank(0x9d4eF81F5225107049ba08F69F598D97B31ea644);
        bytes memory _signature = constructSig(address(0xD20e11e46b923a4dDE6BB44dE1913e1497Bd0E98), 2, 0.0001 ether, block.timestamp + 1 hours, 0x9534d190ad6db1009e5bbbd5847befdeb837bf2c4d1b4ce4f0e708bf2f98da4a);
        counter.createListing(address(0xD20e11e46b923a4dDE6BB44dE1913e1497Bd0E98), 2, 0.0001 ether, block.timestamp + 1 hours, _signature);
        vm.stopPrank();
    }
}
