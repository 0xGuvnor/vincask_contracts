// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interface/IVinCask.sol";
import "./VinCaskX.sol";

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
 * @title VinCask NFT
 * @author 0xGuvnor
 * @dev This contract allows users to mint VinCask NFTs using either stablecoin (USDC at time of deployment) or
 *      fiat via credit card (using Crossmint).
 *
 *      Each NFT entitles its owner to redeem it for a bottle of VinCask whisky at a later date.
 *
 *      When a VinCask NFT is redeemed, the NFT will be transferred to the VinCask MultiSig, and the user
 *      will receive a VinCask-X NFT in its place for commemorative purposes and as proof that the NFT has been redeemed.
 *
 *      For redemptions to be eligible, they MUST be initiated through the website UI as users have to complete a
 *      form with their redemption details.
 */
contract VinCask is IVinCask, ERC721, ERC721Royalty, ERC721Burnable, Pausable, Ownable {
    uint256 private tokenCounter;
    uint256 private tokensBurned;

    uint256 private mintPrice;
    IERC20 private stableCoin;
    uint256 private totalSupply;
    bool private redemptionOpen;

    address private immutable MULTI_SIG;
    VinCaskX private immutable VIN_X;

    constructor(
        uint256 _mintPrice,
        address _stableCoin,
        uint256 _totalSupply,
        address _multiSig,
        VinCaskX _VIN_X,
        uint96 _royaltyFee /* Expressed in basis points i.e. 500 = 5% */
    ) ERC721("VinCask", "VIN") {
        mintPrice = _mintPrice;
        stableCoin = IERC20(_stableCoin);
        totalSupply = _totalSupply;
        MULTI_SIG = _multiSig;
        VIN_X = _VIN_X;

        _setDefaultRoyalty(_multiSig, _royaltyFee);

        redemptionOpen = false;
    }

    /**
     * @dev Used to ensure the max token supply is enforced, and the user must mint at least 1 NFT.
     * @param _quantity The number of NFTs to mint.
     */
    modifier mintCompliance(uint256 _quantity) {
        if ((tokenCounter - tokensBurned) + _quantity > totalSupply) revert VinCask__MaxSupplyExceeded();
        if (_quantity == 0) revert VinCask__MustMintAtLeastOne();
        _;
    }

    /**
     * @dev Serves as a second Pause function for redemption, i.e. when the contract is unpaused, users can mint
     *  but can't redeem until isRedemptionOpen() return true.
     */
    modifier whenRedemptionIsOpen() {
        if (!isRedemptionOpen()) revert VinCask__RedemptionNotOpen();
        _;
    }

    /**
     * @dev Users will call this function to mint the NFT if they are paying from their wallet.
     * @param _quantity The number of NFTs to mint.
     */
    function safeMultiMintWithStableCoin(uint256 _quantity) external mintCompliance(_quantity) whenNotPaused {
        _safeMultiMint(_quantity, msg.sender, mintPrice);
    }

    /**
     * @dev For users who want to pay with their credit card to mint. This function is called by Crossmint.
     * @param _quantity The number of NFTs to mint.
     * @param _to The recipient of the NFT(s), required by Crossmint.
     */
    function safeMultiMintWithCreditCard(uint256 _quantity, address _to)
        external
        mintCompliance(_quantity)
        whenNotPaused
    {
        _safeMultiMint(_quantity, _to, 10e6);
    }

    /**
     * @notice Allows the admin to mint and burn NFTs at no cost.
     * Intended to be used for physical sales that do not want the NFT.
     * @param _quantity The number of NFTs to mint and burn.
     */
    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external mintCompliance(_quantity) onlyOwner {
        unchecked {
            // Underflow not possible as you can't burn more than you mint
            totalSupply -= _quantity;
            tokensBurned += _quantity;
        }

        for (uint256 i = 0; i < _quantity; ++i) {
            unchecked {
                // Overflow not possible as it is capped by totalSupply (in mintCompliance modifier)
                // Token ID is incremented first so that token ID starts at 1
                tokenCounter++;
            }
            uint256 tokenId = tokenCounter;

            _safeMint(msg.sender, tokenId);
            _burn(tokenId);
        }
    }

    /**
     * @dev When redemption is open, allows the user to choose which of their NFTs to redeem.
     * @param _tokenIds An array of token IDs that are owned by the caller.
     */
    function multiRedeem(uint256[] calldata _tokenIds) external whenNotPaused whenRedemptionIsOpen {
        uint256 numberOfTokens = _tokenIds.length;

        for (uint256 i = 0; i < numberOfTokens; ++i) {
            if (_isApprovedOrOwner(address(this), _tokenIds[i]) == false) revert VinCask__CallerNotAuthorised();

            uint256 tokenId = _tokenIds[i];
            transferFrom(msg.sender, MULTI_SIG, tokenId);
            VIN_X.safeMint(msg.sender, tokenId);
        }
    }

    /**
     * @dev Using this function to set approvals for individual NFTs instead of setApprovalForAll
     * to avoid scaring users with the MetaMask warning.
     * @param _tokenIds Array of token IDs to approve
     */
    function multiApprove(uint256[] calldata _tokenIds) external {
        uint256 numOfTokens = _tokenIds.length;
        if (numOfTokens == 0) revert VinCask__MustApproveAtLeastOne();

        for (uint256 i = 0; i < numOfTokens; ++i) {
            approve(address(this), _tokenIds[i]);
        }
    }

    /**
     * @dev To be used by the admin to burn NFTs that have been redeemed
     * and physical whisky has been sent out to customers.
     * @param _tokenId The token ID of the NFT to burn.
     */
    function burn(uint256 _tokenId) public override onlyOwner {
        super.burn(_tokenId);
    }

    /**
     * @dev To be used instead of burn() if there is more than 1 NFT to burn.
     * @param _tokenIds Array of token IDs to burn.
     */
    function multiBurn(uint256[] calldata _tokenIds) external onlyOwner {
        uint256 numOfTokens = _tokenIds.length;

        for (uint256 i = 0; i < numOfTokens; ++i) {
            burn(_tokenIds[i]);
        }
    }

    /**
     * @dev Setter function to update the mint price per NFT.
     * @param _newMintPrice The new mint price.
     */
    function setMintPrice(uint256 _newMintPrice) external onlyOwner {
        if (mintPrice == _newMintPrice) revert VinCask__MustSetDifferentPrice();

        mintPrice = _newMintPrice;
    }

    /**
     * @dev Setter function to change the stablecoin used for payment.
     * @param _newStableCoin The new stablecoin address to be used.
     */
    function setStableCoin(address _newStableCoin) external onlyOwner {
        if (stableCoin == IERC20(_newStableCoin)) revert VinCask__MustSetDifferentStableCoin();

        stableCoin = IERC20(_newStableCoin);
    }

    /**
     * @dev Returns the total supply.
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    /**
     * @dev Returns the latest token ID that has been minted.
     */
    function getLatestTokenId() external view returns (uint256) {
        return tokenCounter;
    }

    /**
     * @dev Returns the mint price for each NFT.
     */
    function getMintPrice() external view returns (uint256) {
        return mintPrice;
    }

    /**
     * @dev Returns the address for the stablecoin used for payment.
     */
    function getStableCoin() external view returns (address) {
        return address(stableCoin);
    }

    /**
     * @dev Returns the address of the VinCask MultiSig.
     */
    function getMultiSig() external view returns (address) {
        return MULTI_SIG;
    }

    function isRedemptionOpen() public view returns (bool) {
        return redemptionOpen;
    }

    /**
     * @dev Only the admin can pause the contract. When paused, users can't mint NFTs.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Only the admin can unpause the contract. When unpaused, users can mint NFTs.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Only the admin can open the redemption process. Users can then redeem their NFT(s)
     * for VinCask whisky.
     */
    function openRedemption() external onlyOwner {
        redemptionOpen = true;
        emit RedemptionOpened(msg.sender);
    }

    /**
     * @dev Only the admin can close the redemption process. Users cannot redeem their NFT(s)
     * unil redemption is open.
     */
    function closeRedemption() external onlyOwner {
        redemptionOpen = false;
        emit RedemptionClosed(msg.sender);
    }

    /**
     * @dev Allows a user to mint multiple NFTs in one transaction.
     * @param _quantity The number of NFTs to mint
     * @param _to The recipient of the NFT(s)
     * @param _mintPrice The price of each NFT
     */
    function _safeMultiMint(uint256 _quantity, address _to, uint256 _mintPrice) internal {
        uint256 totalPrice = _quantity * _mintPrice;

        bool success = stableCoin.transferFrom(msg.sender, MULTI_SIG, totalPrice);
        /**
         * @note Remove this check? It will never return false.
         */
        if (!success) revert VinCask__PaymentFailed();

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

    /**
     * @dev See {ERC721-_baseURI}.
     */
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

    /**
     * @dev See {ERC721Royalty-_burn}.
     * @param _tokenId Token ID to burn.
     */
    function _burn(uint256 _tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(_tokenId);
    }
}
