// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./interface/IVincask.sol";
import "./VincaskX.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Vincask NFT contract
 * @author 0xGuvnor
 * @notice X
 */
contract Vincask is IVincask, ERC721, ERC721Royalty, Pausable, Ownable {
    uint256 private tokenCounter;
    uint256 private mintPrice;
    IERC20 private stableCoin;

    uint256 private immutable TOTAL_SUPPLY;
    address private immutable MULTI_SIG;
    VincaskX private immutable VIN_X;

    constructor(
        uint256 _mintPrice,
        address _stableCoin,
        uint256 _totalSupply,
        address _multiSig,
        uint96 _royaltyFee, /* Expressed in basis points i.e. 500 = 5% */
        VincaskX _VIN_X
    ) ERC721("Vincask", "VIN") {
        tokenCounter = 0;

        mintPrice = _mintPrice;
        stableCoin = IERC20(_stableCoin);
        TOTAL_SUPPLY = _totalSupply;
        MULTI_SIG = _multiSig;
        _setDefaultRoyalty(_multiSig, _royaltyFee);
        VIN_X = _VIN_X;
    }

    /**
     * @notice This function allows a customer to mint multiple NFTs in one transaction
     * @param _quantity The number of NFTs to mint
     */
    function safeMultiMintWithUsdc(uint256 _quantity) external whenNotPaused {
        if (tokenCounter + _quantity > TOTAL_SUPPLY) revert Vincask__MaxSupplyExceeded();
        if (_quantity == 0) revert Vincask__MustMintAtLeastOne();

        uint256 totalPrice = _quantity * mintPrice;

        for (uint256 i = 0; i < _quantity; ++i) {
            // Token ID is incremented first so that token ID starts at 1
            tokenCounter++;
            uint256 tokenId = tokenCounter;

            _safeMint(msg.sender, tokenId);
        }

        bool success = stableCoin.transferFrom(msg.sender, MULTI_SIG, totalPrice);
        if (!success) revert Vincask__PaymentFailed();
    }

    function safeMultiMintWithCreditCard(uint256 _quantity, address _to) external whenNotPaused {
        if (tokenCounter + _quantity > TOTAL_SUPPLY) revert Vincask__MaxSupplyExceeded();
        if (_quantity == 0) revert Vincask__MustMintAtLeastOne();

        uint256 totalPrice = _quantity * 25_000e6; // 6 decimal places for USDC

        for (uint256 i = 0; i < _quantity; ++i) {
            // Token ID is incremented first so that token ID starts at 1
            tokenCounter++;
            uint256 tokenId = tokenCounter;

            _safeMint(_to, tokenId);
        }

        bool success = stableCoin.transferFrom(msg.sender, MULTI_SIG, totalPrice);
        if (!success) revert Vincask__PaymentFailed();
    }

    function safeMultiMintForAdmin(uint256 _quantity) external onlyOwner {
        if (tokenCounter + _quantity > TOTAL_SUPPLY) revert Vincask__MaxSupplyExceeded();
        if (_quantity == 0) revert Vincask__MustMintAtLeastOne();

        for (uint256 i = 0; i < _quantity; ++i) {
            // Token ID is incremented first so that token ID starts at 1
            tokenCounter++;
            uint256 tokenId = tokenCounter;

            _safeMint(msg.sender, tokenId);
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

    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
    }

    function setStableCoin(address _newStableCoin) external onlyOwner {
        stableCoin = IERC20(_newStableCoin);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://abc/";
    }

    function getTotalSupply() external view returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function getLatestTokenId() external view returns (uint256) {
        return tokenCounter;
    }

    function getMintPrice() external view returns (uint256) {
        return mintPrice;
    }

    function getStableCoin() external view returns (address) {
        return address(stableCoin);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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
