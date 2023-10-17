// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IVinCask {
    error VinCask__MaxSupplyExceeded();
    error VinCask__MustMintAtLeastOne();
    error VinCask__MustApproveAtLeastOne();
    error VinCask__PaymentFailed();
    error VinCask__CallerNotAuthorised();
    error VinCask__MustSetDifferentPrice();
    error VinCask__MustSetDifferentStableCoin();
    error VinCask__RedemptionNotOpen();
    error VinCask__AddressNotWhitelisted();
    error VinCask__QuantityExceedsWhitelistLimit();
    error VinCask__InvalidAddress();
    error VinCask__WhitelistAddressArrayOutOfBounds();
    error VinCask__CannotSetMintLimitLowerThanMintedAmount();

    event RedemptionOpened(address indexed account);
    event RedemptionClosed(address indexed account);

    function safeMultiMintWithStableCoin(uint256 _quantity) external;

    function safeMultiMintWithCreditCard(uint256 _quantity, address _to) external;

    function safeMultiMintForWhitelist(uint256 _quantity) external;

    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external;

    function multiRedeem(uint256[] calldata _tokenIds) external;

    function multiApprove(uint256[] calldata _tokenIds) external;

    function setMintPrice(uint256 _newMintPrice) external;

    function setStableCoin(address _newStableCoin) external;

    function setWhitelistAddress(address _address, uint256 _mintLimit) external;

    function removeWhitelistAddress(address _address) external;

    function openRedemption() external;

    function closeRedemption() external;

    function getTotalSupply() external view returns (uint256);

    function getLatestTokenId() external view returns (uint256);

    function getMintPrice() external view returns (uint256);

    function getStableCoin() external view returns (address);

    function getMultiSig() external view returns (address);

    function getWhitelistDetails(address _address) external view returns (bool, uint256, uint256);

    function getWhitelistAddresses() external view returns (address[] memory);

    function isRedemptionOpen() external view returns (bool);
}
