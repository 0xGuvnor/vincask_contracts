// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title IVinCask-X Interface
 * @author 0xGuvnor
 * @notice Interface for VinCask-X NFT contract
 */
interface IVinCaskX {
    /**
     * @dev Returns the role that allows minting of VIN-X tokens.
     */
    function MINTER_ROLE() external view returns (bytes32);

    /**
     * @dev To be called by VinCask when a VIN NFT is being redeemed.
     * @param _to Address of the recipient.
     * @param _tokenId Token ID to be used.
     */
    function safeMint(address _to, uint256 _tokenId) external;
}
