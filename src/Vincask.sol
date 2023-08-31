// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interface/IVincask.sol";
import "./VincaskX.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
      ___                       ___           ___           ___           ___           ___     
     /\__\          ___        /\__\         /\  \         /\  \         /\  \         /\__\    
    /:/  /         /\  \      /::|  |       /::\  \       /::\  \       /::\  \       /:/  /    
   /:/  /          \:\  \    /:|:|  |      /:/\:\  \     /:/\:\  \     /:/\ \  \     /:/__/     
  /:/__/  ___      /::\__\  /:/|:|  |__   /:/  \:\  \   /::\~\:\  \   _\:\~\ \  \   /::\__\____ 
  |:|  | /\__\  __/:/\/__/ /:/ |:| /\__\ /:/__/ \:\__\ /:/\:\ \:\__\ /\ \:\ \ \__\ /:/\:::::\__\
  |:|  |/:/  / /\/:/  /    \/__|:|/:/  / \:\  \  \/__/ \/__\:\/:/  / \:\ \:\ \/__/ \/_|:|~~|~   
  |:|__/:/  /  \::/__/         |:/:/  /   \:\  \            \::/  /   \:\ \:\__\      |:|  |    
   \::::/__/    \:\__\         |::/  /     \:\  \           /:/  /     \:\/:/  /      |:|  |    
    ~~~~         \/__/         /:/  /       \:\__\         /:/  /       \::/  /       |:|  |    
                               \/__/         \/__/         \/__/         \/__/         \|__|    
*/

/**
 * @title Vincask NFT contract
 * @author 0xGuvnor
 * @notice X
 */
contract Vincask is IVincask, ERC721, ERC721Royalty, ERC721Burnable, Pausable, Ownable {
    uint256 private tokenCounter;
    uint256 private tokensBurned;

    uint256 private mintPrice;
    IERC20 private stableCoin;
    uint256 private totalSupply;

    address private immutable MULTI_SIG;
    VincaskX private immutable VIN_X;

    constructor(
        uint256 _mintPrice,
        address _stableCoin,
        uint256 _totalSupply,
        address _multiSig,
        VincaskX _VIN_X,
        uint96 _royaltyFee /* Expressed in basis points i.e. 500 = 5% */
    ) ERC721("Vincask", "VIN") {
        mintPrice = _mintPrice;
        stableCoin = IERC20(_stableCoin);
        totalSupply = _totalSupply;
        MULTI_SIG = _multiSig;
        VIN_X = _VIN_X;

        _setDefaultRoyalty(_multiSig, _royaltyFee);
    }

    modifier mintCompliance(uint256 _quantity) {
        if ((tokenCounter - tokensBurned) + _quantity > totalSupply) revert Vincask__MaxSupplyExceeded();
        if (_quantity == 0) revert Vincask__MustMintAtLeastOne();
        _;
    }

    /**
     * @notice This function allows a customer to mint multiple NFTs in one transaction
     * @param _quantity The number of NFTs to mint
     */
    function safeMultiMintWithStableCoin(uint256 _quantity) external mintCompliance(_quantity) whenNotPaused {
        _safeMultiMint(_quantity, msg.sender, mintPrice);
    }

    function safeMultiMintWithCreditCard(uint256 _quantity, address _to)
        external
        mintCompliance(_quantity)
        whenNotPaused
    {
        _safeMultiMint(_quantity, _to, 10e6);
    }

    /**
     * @notice Allows the owner to mint and burn NFTs at no cost.
     * Intended to be used for physical sales that do not want the NFT.
     * @param _quantity The number of NFTs to mint and burn
     */
    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external mintCompliance(_quantity) onlyOwner {
        unchecked {
            // Underflow not possible as you can't burn more than you mint
            totalSupply -= _quantity;
            tokensBurned += _quantity;
        }

        for (uint256 i = 0; i < _quantity; ++i) {
            unchecked {
                // Overflow not possible as it is capped by totalSupply (in mintCompliance)
                // Token ID is incremented first so that token ID starts at 1
                tokenCounter++;
            }
            uint256 tokenId = tokenCounter;

            _safeMint(msg.sender, tokenId);
            _burn(tokenId);
        }
    }

    function multiRedeem(uint256[] calldata _tokenIds) external whenNotPaused {
        uint256 numberOfTokens = _tokenIds.length;

        for (uint256 i = 0; i < numberOfTokens; ++i) {
            if (_isApprovedOrOwner(address(this), _tokenIds[i]) == false) revert Vincask__CallerNotAuthorised();

            uint256 tokenId = _tokenIds[i];
            transferFrom(msg.sender, MULTI_SIG, tokenId);
            VIN_X.safeMint(msg.sender, tokenId);
        }
    }

    /**
     * @dev Using this function to set approvals instead of setApprovalForAll
     * to avoid scaring users with the MetaMask warning
     * @param _tokenIds Tokens to approve
     */
    function multiApprove(uint256[] calldata _tokenIds) external {
        uint256 numOfTokens = _tokenIds.length;
        if (numOfTokens == 0) revert Vincask__MustApproveAtLeastOne();

        for (uint256 i = 0; i < numOfTokens; ++i) {
            approve(address(this), _tokenIds[i]);
        }
    }

    function burn(uint256 _tokenId) public override onlyOwner {
        super.burn(_tokenId);
    }

    function multiBurn(uint256[] calldata _tokenIds) external onlyOwner {
        uint256 numOfTokens = _tokenIds.length;

        for (uint256 i = 0; i < numOfTokens; ++i) {
            burn(_tokenIds[i]);
        }
    }

    function setMintPrice(uint256 _newMintPrice) external onlyOwner {
        if (mintPrice == _newMintPrice) revert Vincask__MustSetDifferentPrice();

        mintPrice = _newMintPrice;
    }

    function setStableCoin(address _newStableCoin) external onlyOwner {
        if (stableCoin == IERC20(_newStableCoin)) revert Vincask__MustSetDifferentStableCoin();

        stableCoin = IERC20(_newStableCoin);
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function getLatestTokenId() external view returns (uint256) {
        return tokenCounter;
    }

    function getMintPrice() external view returns (uint256) {
        return mintPrice;
    }

    /**
     * @notice Returns the address for the stable coin used for payment
     */
    function getStableCoin() external view returns (address) {
        return address(stableCoin);
    }

    function getMultiSig() external view returns (address) {
        return MULTI_SIG;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _safeMultiMint(uint256 _quantity, address _to, uint256 _mintPrice) internal {
        uint256 totalPrice = _quantity * _mintPrice;

        bool success = stableCoin.transferFrom(msg.sender, MULTI_SIG, totalPrice);
        /**
         * @note Remove this check? It will never return false.
         */
        if (!success) revert Vincask__PaymentFailed();

        for (uint256 i = 0; i < _quantity; ++i) {
            unchecked {
                // Overflow not possible as it is capped by totalSupply (in mintCompliance)
                // Token ID is incremented first so that token ID starts at 1
                tokenCounter++;
            }
            uint256 tokenId = tokenCounter;

            _safeMint(_to, tokenId);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://abc/";
    }

    /**
     * @notice Remove this function? OZ includes this in their contract wizard, but this contract does not use this hook.
     */
    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId, uint256 _batchSize)
        internal
        override
        whenNotPaused
    {
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721Royalty) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }

    function _burn(uint256 _tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(_tokenId);
    }
}
