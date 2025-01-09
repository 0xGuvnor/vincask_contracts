// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title IVinCask Interface
 * @author 0xGuvnor
 * @notice Interface for the VinCask NFT contract
 * @dev This interface defines the functions and events for minting, redeeming, and managing VinCask NFTs
 */
interface IVinCask {
    error VinCask__InvalidURI();
    error VinCask__InvalidAddress();
    error VinCask__RedemptionNotOpen();
    error VinCask__MaxSupplyExceeded();
    error VinCask__MustMintAtLeastOne();
    error VinCask__MintingCapExceeded();
    error VinCask__CallerNotAuthorised();
    error VinCask__MustRedeemAtLeastOne();
    error VinCask__AddressNotWhitelisted();
    error VinCask__MustSetDifferentPrice();
    error VinCask__WhitelistLimitExceeded();
    error VinCask__MustSetDifferentAddress();
    error VinCask__OnlyCanIncreaseMintingCap();
    error VinCask__MustSetDifferentStableCoin();
    error VinCask__MintingCapExceedsMaxSupply();
    error VinCask__QuantityExceedsWhitelistLimit();
    error VinCask__WhitelistAddressArrayOutOfBounds();
    error VinCask__CannotSetMintLimitLowerThanMintedAmount();
    /**
     * @notice Struct containing whitelist information for an address
     * @param isWhitelisted Whether the address is whitelisted
     * @param mintLimit Maximum number of tokens the address can mint
     * @param amountMinted Number of tokens already minted by this address
     */

    struct WhitelistDetails {
        bool isWhitelisted;
        uint256 mintLimit;
        uint256 amountMinted;
    }

    /**
     * @notice Enum representing different minting methods
     * @param STABLECOIN Minting with stablecoin payment
     * @param CREDIT_CARD Minting via credit card (Crossmint)
     * @param WHITELIST Minting through whitelist (free mint)
     */
    enum MintType {
        STABLECOIN,
        CREDIT_CARD,
        WHITELIST
    }

    event Minted(address account, uint256 indexed price, uint256 indexed quantity, MintType indexed mintType);
    event Redeemed(address indexed account, uint256 indexed quantity);
    event DirectSale(uint256 indexed quantity);
    event RedemptionOpened(address indexed account);
    event RedemptionClosed(address indexed account);
    event MintingCapIncreased(address indexed account, uint256 indexed oldCap, uint256 indexed newCap);
    event MintPriceUpdated(address indexed account, uint256 indexed oldPrice, uint256 indexed newPrice);
    event StableCoinUpdated(address indexed account, address indexed oldCoin, address indexed newCoin);
    event WhitelistAddressAdded(address indexed account, address indexed whitelistAddress, uint256 indexed mintLimit);
    event WhitelistAddressRemoved(address indexed account, address indexed whitelistAddress);
    event MultiSigUpdated(address indexed account, address indexed oldMultiSig, address indexed newMultiSig);
    event CrossmintAddressUpdated(address indexed account, address indexed oldAddress, address indexed newAddress);
    event RoyaltyUpdated(address indexed account, address indexed receiver, uint96 indexed feeNumerator);
    event BaseURIUpdated(address indexed account, string oldURI, string newURI);

    function safeMultiMintWithStableCoin(uint256 _quantity) external;

    function safeMultiMintWithCreditCard(uint256 _quantity, address _to) external;

    function safeMultiMintForWhitelist(uint256 _quantity) external;

    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external;

    function multiRedeem(uint256[] calldata _tokenIds) external;

    function increaseMintingCap(uint256 _newMintingCap) external;

    function setMintPrice(uint256 _newMintPrice) external;

    function setStableCoin(address _newStableCoin) external;

    function setWhitelistAddress(address _address, uint256 _mintLimit) external;

    function setMultiSig(address _newMultiSig) external;

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external;

    function setCrossmintAddress(address _newCrossmintAddress) external;

    function removeWhitelistAddress(address _address) external;

    function openRedemption() external;

    function closeRedemption() external;

    function getTotalMintedForCap() external view returns (uint256);

    function getMintingCap() external view returns (uint256);

    function getMaxSupply() external view returns (uint256);

    function getLatestTokenId() external view returns (uint256);

    function getMintPrice() external view returns (uint256);

    function getStableCoin() external view returns (address);

    function getStableCoinDecimals() external view returns (uint8);

    function getMultiSig() external view returns (address);

    function getWhitelistDetails(address _address) external view returns (bool, uint256, uint256);

    function getWhitelistAddresses() external view returns (address[] memory);

    function getCrossmintAddress() external view returns (address);

    function getVinCaskXAddress() external view returns (address);

    function isRedemptionOpen() external view returns (bool);

    function setBaseURI(string memory _newBaseURI) external;

    function getBaseURI() external view returns (string memory);

    function pause() external;

    function unpause() external;

    function totalSupply() external view returns (uint256);
}
