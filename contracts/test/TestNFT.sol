// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721 {

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint tokenId) public {
        _mint(to, tokenId);
    }
}