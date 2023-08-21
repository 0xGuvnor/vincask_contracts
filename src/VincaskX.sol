// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VincaskX is ERC721, Ownable {
    constructor() ERC721("Vincask-X", "VIN-X") {}

    function safeMint(address _to, uint256 _tokenId) external onlyOwner {
        _safeMint(_to, _tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://def/";
    }
}
