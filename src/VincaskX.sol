// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/*
 ___      ___ ___  ________   ________  ________  ________  ___  __                   ___    ___ 
|\  \    /  /|\  \|\   ___  \|\   ____\|\   __  \|\   ____\|\  \|\  \                |\  \  /  /|
\ \  \  /  / | \  \ \  \\ \  \ \  \___|\ \  \|\  \ \  \___|\ \  \/  /|_  ____________\ \  \/  / /
 \ \  \/  / / \ \  \ \  \\ \  \ \  \    \ \   __  \ \_____  \ \   ___  \|\____________\ \    / / 
  \ \    / /   \ \  \ \  \\ \  \ \  \____\ \  \ \  \|____|\  \ \  \\ \  \|____________|/     \/  
   \ \__/ /     \ \__\ \__\\ \__\ \_______\ \__\ \__\____\_\  \ \__\\ \__\            /  /\   \  
    \|__|/       \|__|\|__| \|__|\|_______|\|__|\|__|\_________\|__| \|__|           /__/ /\ __\ 
                                                    \|_________|                     |__|/ \|__| 
*/

/**
 * @title VinCask-X NFT
 * @author 0xGuvnor
 * @dev This contract is used in conjuntion with the VinCask contract, where VinCask is the owner of this contract.
 *      When VinCask NFTs (VIN) are redeemed by the user, a corresponding VinCask-X NFT (VIN-X) is minted and sent
 *      to the user as a commemorative NFT and as proof that the VIN token ID has been redeemed.
 */
contract VinCaskX is ERC721, Ownable {
    constructor() ERC721("VinCask-X", "VIN-X") {}

    /**
     * @dev To be called by VinCask when a VIN NFT is being redeemed.
     * @param _to Address of the recipient.
     * @param _tokenId Token ID to be used.
     */
    function safeMint(address _to, uint256 _tokenId) external onlyOwner {
        _safeMint(_to, _tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        // Placeholder URI
        return "ipfs://def/";
    }
}
