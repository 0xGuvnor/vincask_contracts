// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IVinCask} from "./interface/IVinCask.sol";
import {VinCaskX} from "./VinCaskX.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
 *      When a VinCask NFT is redeemed, the NFT will be burned, and the user will receive a VinCask-X NFT
 *       in its place for commemorative purposes and as proof that the NFT has been redeemed.
 *
 *      For redemptions to be eligible, they MUST be initiated through the website UI as users have to complete a
 *      form with their redemption details.
 */
contract VinCask is ERC721, ERC721Royalty, Pausable, Ownable, IVinCask {
    struct WhitelistDetails {
        bool isWhitelisted;
        uint256 mintLimit;
        uint256 amountMinted;
    }

    bool private redemptionOpen;
    uint256 private mintPrice;
    IERC20 private stableCoin;
    uint256 private maxCirculatingSupply;
    uint256 private totalSupply;

    mapping(address => WhitelistDetails) private whitelist;
    address[] private whitelistAddresses;

    uint256 private tokenCounter;
    uint256 private tokensBurned;

    address private immutable MULTI_SIG;
    VinCaskX private immutable VIN_X;

    constructor(
        uint256 _mintPrice,
        address _stableCoin,
        uint256 _maxCirculatingSupply,
        uint256 _totalSupply,
        address _multiSig,
        VinCaskX _VIN_X,
        uint96 _royaltyFee /* Expressed in basis points i.e. 500 = 5% */
    ) ERC721("VinCask", "VIN") {
        mintPrice = _mintPrice;
        stableCoin = IERC20(_stableCoin);
        maxCirculatingSupply = _maxCirculatingSupply;
        totalSupply = _totalSupply;
        MULTI_SIG = _multiSig;
        VIN_X = _VIN_X;

        _setDefaultRoyalty(_multiSig, _royaltyFee);

        tokenCounter = 0;
        redemptionOpen = false;
    }

    /**
     * @dev Used to ensure the max token supply is enforced, and the user must mint at least 1 NFT.
     * @param _quantity The number of NFTs to mint.
     */
    modifier mintCompliance(uint256 _quantity) {
        if (getCirculatingSupply() + _quantity > totalSupply) revert VinCask__MaxSupplyExceeded();
        if (getCirculatingSupply() + _quantity > maxCirculatingSupply) revert VinCask__MaxCirculatingSupplyExceeded();
        if (_quantity == 0) revert VinCask__MustMintAtLeastOne();
        _;
    }

    /**
     * @dev Serves as a second Pause function for redemption, i.e. when the contract is unpaused, users can mint
     *  but can't redeem until isRedemptionOpen() returns true.
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
     * @dev Allows whitelisted VinCask team addresses to mint at no cost.
     * @param _quantity Quantity to mint.
     */
    function safeMultiMintForWhitelist(uint256 _quantity) external mintCompliance(_quantity) {
        WhitelistDetails storage whitelistDetails = whitelist[msg.sender];

        if (!whitelistDetails.isWhitelisted) revert VinCask__AddressNotWhitelisted();

        uint256 mintsLeft = whitelistDetails.mintLimit - whitelistDetails.amountMinted;
        if (_quantity > mintsLeft) revert VinCask__QuantityExceedsWhitelistLimit();

        whitelistDetails.amountMinted += _quantity;
        _safeMultiMint(_quantity, msg.sender, 0);
    }

    /**
     * @dev Allows the admin to mint and burn NFTs at no cost. Intended to be used for
     *  physical sales where the customer does not want the NFT.
     * @param _quantity The number of NFTs to mint and burn.
     */
    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external mintCompliance(_quantity) onlyOwner {
        unchecked {
            // Underflow not possible as you can't burn more than you mint
            maxCirculatingSupply -= _quantity;
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
     * @dev When redemption is open, allows the user to choose which of their NFTs to redeem. Redeemed NFTs
     * are then burned and the user is minted a corresponding VIN-X NFT.
     * @param _tokenIds An array of token IDs that are owned by the caller.
     */
    function multiRedeem(uint256[] calldata _tokenIds) external whenNotPaused whenRedemptionIsOpen {
        uint256 numberOfTokens = _tokenIds.length;

        for (uint256 i = 0; i < numberOfTokens; ++i) {
            if (_isApprovedOrOwner(msg.sender, _tokenIds[i]) == false) revert VinCask__CallerNotAuthorised();

            uint256 tokenId = _tokenIds[i];
            _burn(tokenId);
            VIN_X.safeMint(msg.sender, tokenId);
        }
    }

    /**
     * @dev Using this function to set approvals for individual NFTs instead of setApprovalForAll
     * to avoid alarming users with the MetaMask warning.
     * @param _tokenIds Array of token IDs to approve
     */
    function multiApprove(uint256[] calldata _tokenIds) external {
        uint256 numOfTokens = _tokenIds.length;
        if (numOfTokens == 0) revert VinCask__MustApproveAtLeastOne();

        for (uint256 i = 0; i < numOfTokens; ++i) {
            approve(address(this), _tokenIds[i]);
        }
    }

    function increaseCirculatingSupply(uint256 _newCirculatingSupply) external onlyOwner {
        if (_newCirculatingSupply <= maxCirculatingSupply) revert VinCask__OnlyCanIncreaseCirculatingSupply();
        if (_newCirculatingSupply > totalSupply) revert VinCask__CirculatingSupplyExceedsTotalSupply();

        maxCirculatingSupply = _newCirculatingSupply;
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
     * Relies on admin setting a proper stablecoin address, as there are
     * no checks to make sure the address is a contract and ERC20 compliant.
     * @param _newStableCoin The new stablecoin address to be used.
     */
    function setStableCoin(address _newStableCoin) external onlyOwner {
        if (stableCoin == IERC20(_newStableCoin)) revert VinCask__MustSetDifferentStableCoin();

        stableCoin = IERC20(_newStableCoin);
    }

    /**
     * @dev Setter function to allow approved addresses from the team to mint the NFT for free
     * @param _address Address to whitelist
     * @param _mintLimit The maximum quantity _address is allowed to mint for free
     */
    function setWhitelistAddress(address _address, uint256 _mintLimit) external onlyOwner {
        if (_address == address(0)) revert VinCask__InvalidAddress();
        if (_mintLimit <= 0) revert VinCask__MustMintAtLeastOne();

        WhitelistDetails storage whitelistDetails = whitelist[_address];

        // If the address has already minted before, the function will
        // revert if the admin is wants to set a mint limit less than what
        // the address has already minted
        if (_mintLimit < whitelistDetails.amountMinted) revert VinCask__CannotSetMintLimitLowerThanMintedAmount();

        // Adds the address to the whitelist addresses array,
        // won't add multiple instances if admin is updating the mint limit
        if (!whitelistDetails.isWhitelisted) {
            whitelistAddresses.push(_address);
        }

        whitelistDetails.isWhitelisted = true;
        whitelistDetails.mintLimit = _mintLimit;
    }

    /**
     * @dev Setter function to remove whitelisted addresses
     * @param _address Address to remove.
     */
    function removeWhitelistAddress(address _address) external onlyOwner {
        if (_address == address(0)) revert VinCask__InvalidAddress();

        WhitelistDetails storage whitelistDetails = whitelist[_address];

        if (!whitelistDetails.isWhitelisted) revert VinCask__AddressNotWhitelisted();

        whitelistDetails.isWhitelisted = false;
        whitelistDetails.mintLimit = 0;

        uint256 whitelistAddressIndex = _findIndex(_address);
        _removeAddressFromWhitelistArray(whitelistAddressIndex);
    }

    /**
     *
     * @param _address Address to query for whitelist details
     * @return A tuple containing two values: a boolean value indicating if the address
     * is in the whitelist, and a uint256 value indicating
     */
    function getWhitelistDetails(address _address) external view returns (bool, uint256, uint256) {
        WhitelistDetails memory whitelistDetails = whitelist[_address];

        return (whitelistDetails.isWhitelisted, whitelistDetails.mintLimit, whitelistDetails.amountMinted);
    }

    /**
     * @dev Returns the list of whitelisted addresses allowed to mint for free.
     * We use an array instead of a merkle tree for simplicity because we don't expect
     * this array to be greater than 5.
     */
    function getWhitelistAddresses() external view returns (address[] memory) {
        return whitelistAddresses;
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
     * @dev Returns the circulating supply of tokens, i.e. net tokens minted (Total minted - total burned).
     */
    function getCirculatingSupply() public view returns (uint256) {
        return tokenCounter - tokensBurned;
    }

    function getMaxCirculatingSupply() external view returns (uint256) {
        return maxCirculatingSupply;
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

        if (totalPrice > 0) {
            // We skip this external call for whitelist mints, i.e. when totalPrice == 0
            bool success = stableCoin.transferFrom(msg.sender, MULTI_SIG, totalPrice);
            /**
             * @note Remove this check? It will never return false based on OZ's implenentation.
             */
            if (!success) revert VinCask__PaymentFailed();
        }

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
     * @dev Util function for removeWhitelistAddress() to find the index of an
     * address in an address array.
     * @param _address Address to find the index of in the array.
     */
    function _findIndex(address _address) internal view returns (uint256) {
        uint256 arrLength = whitelistAddresses.length;

        for (uint256 i = 0; i < arrLength; ++i) {
            if (whitelistAddresses[i] == _address) {
                return i;
            }
        }

        /**
         * @note if _address is not found within the array, return an out of bound index
         *
         * Unlikely to happen as removeWhitelistAddress() checks if
         * _address is already whitelisted, and reverts if not, thus
         * _address should always be found in the array
         */
        return arrLength;
    }

    /**
     * @dev Util function for removeWhitelistAddress() to remove an index from an array.
     * @param _index Index of the array to remove.
     */
    function _removeAddressFromWhitelistArray(uint256 _index) internal {
        uint256 arrLength = whitelistAddresses.length;

        /**
         * @note Unlikely for this error to hit as removeWhitelistAddress()
         * checks that an address is already whitelisted, which means
         * _findIndex() should not return an out of bounds index
         */
        if (_index > arrLength - 1) revert VinCask__WhitelistAddressArrayOutOfBounds();

        // Move the last element into the place to delete
        whitelistAddresses[_index] = whitelistAddresses[arrLength - 1];
        // Remove the last element
        whitelistAddresses.pop();
    }

    /**
     * @dev See {ERC721-_baseURI}.
     */
    function _baseURI() internal pure override returns (string memory) {
        // Placeholder URI
        return "ipfs://abc/";
    }

    /**
     * @notice Remove this function? OZ includes this in their contract wizard, but this contract does not use this hook.
     */
    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId, uint256 _batchSize) internal override {
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
