// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IVinCask} from "./interface/IVinCask.sol";
import {IVinCaskX} from "./interface/IVinCaskX.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
contract VinCask is ERC721, ERC721Royalty, Pausable, Ownable, ReentrancyGuard, IVinCask {
    using SafeERC20 for IERC20;

    string private baseURI;
    bool private redemptionOpen;
    uint256 private mintPrice;
    IERC20 private stableCoin;
    uint8 private stableCoinDecimals;
    uint256 private mintingCap;
    uint256 private maxSupply;

    mapping(address => WhitelistDetails) private whitelist;
    address[] private whitelistAddresses;
    address private crossmintAddress;
    address private multiSig;
    uint256 private totalMintedCount;
    /**
     * @dev Tracks tokens burned by admin for physical sales only.
     * Does NOT include tokens burned through redemption, as redeemed tokens
     * should still count towards minting cap.
     */
    uint256 private adminBurnedCount;
    uint256 private redemptionBurnedCount;

    IVinCaskX private immutable VIN_X;

    constructor(
        uint256 _mintPrice, /* Price is in 18 decimals */
        address _stableCoin,
        uint256 _mintingCap,
        uint256 _maxSupply,
        address _multiSig,
        IVinCaskX _VIN_X,
        uint96 _royaltyFee /* Expressed in basis points (e.g. 500 = 5%) */
    ) ERC721("VinCask", "VIN") {
        mintPrice = _mintPrice;
        stableCoin = IERC20(_stableCoin);
        stableCoinDecimals = IERC20Metadata(_stableCoin).decimals();
        mintingCap = _mintingCap;
        maxSupply = _maxSupply;
        multiSig = _multiSig;
        VIN_X = _VIN_X;

        _setDefaultRoyalty(_multiSig, _royaltyFee);
    }

    /**
     * @dev Used to ensure the max token supply is enforced, and the user must mint at least 1 NFT.
     * @param _quantity The number of NFTs to mint.
     */
    modifier mintCompliance(uint256 _quantity) {
        // Check against absolute maximum supply using total mints
        if (totalMintedCount + _quantity > maxSupply) revert VinCask__MaxSupplyExceeded();

        // Check against minting cap using only onchain sales
        uint256 onlineMintedCount = getTotalMintedForCap();
        if (onlineMintedCount + _quantity > mintingCap) revert VinCask__MintingCapExceeded();

        if (_quantity == 0) revert VinCask__MustMintAtLeastOne();
        _;
    }

    /**
     * @dev Serves as a second Pause function for redemption, i.e. when the contract is unpaused, users can mint
     *  but can't redeem until isRedemptionOpen() returns true.
     */
    modifier canRedeem() {
        if (!isRedemptionOpen()) revert VinCask__RedemptionNotOpen();
        _;
    }

    /**
     * @dev Users will call this function to mint the NFT if they are paying from their wallet.
     * @param _quantity The number of NFTs to mint.
     */
    function safeMultiMintWithStableCoin(uint256 _quantity)
        external
        mintCompliance(_quantity)
        whenNotPaused
        nonReentrant
    {
        _safeMultiMint(_quantity, msg.sender, mintPrice, MintType.STABLECOIN);
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
        nonReentrant
    {
        if (msg.sender != crossmintAddress) revert VinCask__CallerNotAuthorised();

        _safeMultiMint(_quantity, _to, 0, MintType.CREDIT_CARD);
    }

    /**
     * @dev Allows whitelisted VinCask team addresses to mint at no cost.
     * @param _quantity Quantity to mint.
     */
    function safeMultiMintForWhitelist(uint256 _quantity)
        external
        mintCompliance(_quantity)
        whenNotPaused
        nonReentrant
    {
        WhitelistDetails storage whitelistDetails = whitelist[msg.sender];

        if (!whitelistDetails.isWhitelisted) revert VinCask__AddressNotWhitelisted();

        uint256 mintsLeft = whitelistDetails.mintLimit - whitelistDetails.amountMinted;
        if (_quantity > mintsLeft) revert VinCask__QuantityExceedsWhitelistLimit();

        whitelistDetails.amountMinted += _quantity;
        _safeMultiMint(_quantity, msg.sender, 0, MintType.WHITELIST);
    }

    /**
     * @dev Allows the admin to mint and burn NFTs at no cost. Intended to be used for
     *  physical sales where the customer does not want the NFT.
     * @param _quantity The number of NFTs to mint and burn.
     */
    function safeMultiMintAndBurnForAdmin(uint256 _quantity)
        external
        mintCompliance(_quantity)
        onlyOwner
        whenNotPaused
    {
        unchecked {
            totalMintedCount += _quantity;
            adminBurnedCount += _quantity;
        }

        emit DirectSale(_quantity);
    }

    /**
     * @dev When redemption is open, allows the user to choose which of their NFTs to redeem. Redeemed NFTs
     * are then burned and the user is minted a corresponding VIN-X NFT.
     * @param _tokenIds An array of token IDs that are owned by the caller.
     */
    function multiRedeem(uint256[] calldata _tokenIds) external whenNotPaused canRedeem nonReentrant {
        uint256 numberOfTokens = _tokenIds.length;
        if (numberOfTokens == 0) revert VinCask__MustRedeemAtLeastOne();

        for (uint256 i = 0; i < numberOfTokens; ++i) {
            if (!_isApprovedOrOwner(msg.sender, _tokenIds[i])) revert VinCask__CallerNotAuthorised();

            uint256 tokenId = _tokenIds[i];
            _burn(tokenId);
            VIN_X.safeMint(msg.sender, tokenId);
        }

        unchecked {
            redemptionBurnedCount += numberOfTokens;
        }

        emit Redeemed(msg.sender, numberOfTokens);
    }

    function increaseMintingCap(uint256 _newMintingCap) external onlyOwner {
        if (_newMintingCap <= mintingCap) revert VinCask__OnlyCanIncreaseMintingCap();
        if (_newMintingCap > maxSupply) revert VinCask__MintingCapExceedsMaxSupply();

        uint256 oldCap = mintingCap;
        mintingCap = _newMintingCap;

        emit MintingCapIncreased(msg.sender, oldCap, _newMintingCap);
    }

    /**
     * @dev Setter function to update the mint price per NFT.
     * @param _newMintPrice The new mint price in 18 decimals.
     */
    function setMintPrice(uint256 _newMintPrice) external onlyOwner {
        if (mintPrice == _newMintPrice) revert VinCask__MustSetDifferentPrice();

        uint256 oldPrice = mintPrice;
        mintPrice = _newMintPrice;

        emit MintPriceUpdated(msg.sender, oldPrice, _newMintPrice);
    }

    /**
     * @dev Setter function to change the stablecoin used for payment.
     * Relies on admin setting a proper stablecoin address, as there are
     * no checks to make sure the address is a contract and ERC20 compliant.
     * @param _newStableCoin The new stablecoin address to be used.
     */
    function setStableCoin(address _newStableCoin) external onlyOwner {
        if (stableCoin == IERC20(_newStableCoin)) revert VinCask__MustSetDifferentStableCoin();

        address oldCoin = address(stableCoin);
        stableCoin = IERC20(_newStableCoin);
        stableCoinDecimals = IERC20Metadata(_newStableCoin).decimals();

        emit StableCoinUpdated(msg.sender, oldCoin, _newStableCoin);
    }

    /**
     * @dev Setter function to allow approved addresses from the team to mint the NFT for free
     * @param _address Address to whitelist
     * @param _mintLimit The maximum quantity _address is allowed to mint for free
     */
    function setWhitelistAddress(address _address, uint256 _mintLimit) external onlyOwner {
        if (_address == address(0)) revert VinCask__InvalidAddress();
        if (_mintLimit == 0) revert VinCask__MustMintAtLeastOne();
        if (whitelistAddresses.length >= 10) revert VinCask__WhitelistLimitExceeded();

        WhitelistDetails storage whitelistDetails = whitelist[_address];

        if (_mintLimit < whitelistDetails.amountMinted) revert VinCask__CannotSetMintLimitLowerThanMintedAmount();

        if (!whitelistDetails.isWhitelisted) {
            whitelistAddresses.push(_address);
        }

        whitelistDetails.isWhitelisted = true;
        whitelistDetails.mintLimit = _mintLimit;

        emit WhitelistAddressAdded(msg.sender, _address, _mintLimit);
    }

    /**
     * @dev Setter function to update the multiSig address.
     * @param _newMultiSig The new multiSig address.
     */
    function setMultiSig(address _newMultiSig) external onlyOwner {
        if (_newMultiSig == address(0)) revert VinCask__InvalidAddress();
        if (_newMultiSig == multiSig) revert VinCask__MustSetDifferentAddress();

        address oldMultiSig = multiSig;
        multiSig = _newMultiSig;

        emit MultiSigUpdated(msg.sender, oldMultiSig, _newMultiSig);
    }

    /**
     * @dev Setter function to update the base URI.
     * @param _newBaseURI The new base URI.
     */
    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        if (bytes(_newBaseURI).length == 0) revert VinCask__InvalidURI();

        string memory oldURI = baseURI;
        baseURI = _newBaseURI;

        emit BaseURIUpdated(msg.sender, oldURI, _newBaseURI);
    }

    /**
     * @dev Setter function to update the royalty receiver and fee.
     * @param _receiver The new address to receive royalties
     * @param _feeNumerator The new royalty fee in basis points (e.g., 500 = 5%)
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
        if (_receiver == address(0)) revert VinCask__InvalidAddress();

        _setDefaultRoyalty(_receiver, _feeNumerator);

        emit RoyaltyUpdated(msg.sender, _receiver, _feeNumerator);
    }

    /**
     * @dev Setter function to update the crossmint address.
     * @param _newCrossmintAddress The new crossmint address.
     */
    function setCrossmintAddress(address _newCrossmintAddress) external onlyOwner {
        if (_newCrossmintAddress == address(0)) revert VinCask__InvalidAddress();
        if (_newCrossmintAddress == crossmintAddress) revert VinCask__MustSetDifferentAddress();

        address oldAddress = crossmintAddress;
        crossmintAddress = _newCrossmintAddress;

        emit CrossmintAddressUpdated(msg.sender, oldAddress, _newCrossmintAddress);
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

        emit WhitelistAddressRemoved(msg.sender, _address);
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
     * @dev Returns the maximum possible supply of tokens.
     */
    function getMaxSupply() external view returns (uint256) {
        return maxSupply;
    }

    /**
     * @dev Returns the latest token ID that has been minted.
     */
    function getLatestTokenId() external view returns (uint256) {
        return totalMintedCount;
    }

    /**
     * @dev Returns the total supply of tokens currently in circulation.
     * This is calculated as the total number of tokens minted minus the tokens burned by admin
     * and the tokens burned through redemption.
     */
    function totalSupply() public view returns (uint256) {
        return totalMintedCount - adminBurnedCount - redemptionBurnedCount;
    }

    /**
     * @dev Returns the total number of tokens minted for the minting cap calculation.
     * This is the net tokens minted, calculated as (total minted - total burned by admin).
     */
    function getTotalMintedForCap() public view returns (uint256) {
        return totalMintedCount - adminBurnedCount;
    }

    /**
     * @dev Returns the minting cap for the contract.
     */
    function getMintingCap() external view returns (uint256) {
        return mintingCap;
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
     * @dev Returns the number of decimals used by the stablecoin.
     */
    function getStableCoinDecimals() external view returns (uint8) {
        return stableCoinDecimals;
    }

    /**
     * @dev Returns the address of the VinCask MultiSig.
     */
    function getMultiSig() external view returns (address) {
        return multiSig;
    }

    /**
     * @dev Returns the address of the Crossmint contract.
     */
    function getCrossmintAddress() external view returns (address) {
        return crossmintAddress;
    }

    /**
     * @dev Returns the address of the VinCask-X contract.
     * VinCask NFTs that are redeemed are given VinCask-X NFTs in return.
     */
    function getVinCaskXAddress() external view returns (address) {
        return address(VIN_X);
    }

    /**
     * @dev Getter function to view the current base URI.
     * @return The current base URI.
     */
    function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

    /**
     * @dev Returns whether the redemption process is currently open.
     */
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
     * @param _mintPrice The price of each NFT (assumes price is in 18 decimals)
     */
    function _safeMultiMint(uint256 _quantity, address _to, uint256 _mintPrice, MintType _mintType) internal {
        uint256 totalPrice = _quantity * _mintPrice;

        if (totalPrice > 0) {
            // Convert price to stablecoin's decimals from default 18 decimals
            uint256 adjustedPrice = totalPrice * (10 ** stableCoinDecimals) / 1e18;

            stableCoin.safeTransferFrom(msg.sender, multiSig, adjustedPrice);
        }

        for (uint256 i = 0; i < _quantity; ++i) {
            unchecked {
                // Overflow not possible as it is capped by totalSupply (in mintCompliance)
                // Token ID is incremented first so that token ID starts at 1
                totalMintedCount++;
            }

            _safeMint(_to, totalMintedCount);
        }

        emit Minted(_to, _mintPrice, _quantity, _mintType);
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
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
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
