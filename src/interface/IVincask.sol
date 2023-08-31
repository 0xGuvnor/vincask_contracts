// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IVincask {
    error Vincask__MaxSupplyExceeded();
    error Vincask__MustMintAtLeastOne();
    error Vincask__MustApproveAtLeastOne();
    error Vincask__PaymentFailed();
    error Vincask__CallerNotAuthorised();
    error Vincask__MustSetDifferentPrice();
    error Vincask__MustSetDifferentStableCoin();

    function safeMultiMintWithStableCoin(uint256 _quantity) external;

    function safeMultiMintWithCreditCard(uint256 _quantity, address _to) external;

    function safeMultiMintAndBurnForAdmin(uint256 _quantity) external;

    function multiRedeem(uint256[] calldata _tokenIds) external;

    function multiApprove(uint256[] calldata _tokenIds) external;

    function multiBurn(uint256[] calldata _tokenIds) external;

    function setMintPrice(uint256 _newMintPrice) external;

    function setStableCoin(address _newStableCoin) external;

    function getTotalSupply() external view returns (uint256);

    function getLatestTokenId() external view returns (uint256);

    function getMintPrice() external view returns (uint256);

    function getStableCoin() external view returns (address);

    function getMultiSig() external view returns (address);
}
