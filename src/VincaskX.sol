// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IVinCaskX} from "./interface/IVinCaskX.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

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
contract VinCaskX is IVinCaskX, ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Initializes the contract and grants DEFAULT_ADMIN_ROLE to the deployer.
     * Note: Post-deployment, the following roles will be set up:
     * - MINTER_ROLE will be granted to the VinCask contract
     * - DEFAULT_ADMIN_ROLE will be transferred to the multisig wallet
     * See DeployVinCask.s.sol for deployment configuration
     */
    constructor() ERC721("VinCask-X", "VIN-X") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints a new VIN-X NFT to the specified address. This function is intended to be called by the VinCask contract
     * when a VIN NFT is redeemed by the user. The newly minted VIN-X NFT serves as a commemorative token and proof of redemption.
     * @param _to Address of the recipient.
     * @param _tokenId Token ID to be used.
     */
    function safeMint(address _to, uint256 _tokenId) external onlyRole(MINTER_ROLE) {
        _safeMint(_to, _tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        // Placeholder URI
        return "ipfs://def/";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
