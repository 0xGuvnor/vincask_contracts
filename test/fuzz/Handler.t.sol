// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../src/VinCask.sol";
import "../../src/VinCaskX.sol";
import "../../src/mocks/UsdcMock.sol";

contract Handler is Test {
    VinCask vin;
    VinCaskX vinX;
    UsdcMock usdc;

    // Ghost variables
    address[] public users;
    address public currentUser;
    uint256 public nftsMinted;
    uint256 public nftsRedeemed;
    uint256 public nftsBurned;
    mapping(address owner => uint256[] tokenIds) public nftsOwned;
    mapping(address owner => uint256 tokenCount) public nftsOwnedCount;
    uint256 public mintCalled;
    uint256 public redeemCalled;
    uint256 public adminMintAndBurnCalled;

    constructor(VinCask _vin, VinCaskX _vinX, address[] memory _users) {
        vin = _vin;
        vinX = _vinX;
        users = _users;

        usdc = UsdcMock(vin.getStableCoin());

        vm.prank(vin.owner());
        vin.openRedemption();
    }

    modifier useUser(uint256 _userIndexSeed) {
        currentUser = users[bound(_userIndexSeed, 0, users.length - 1)];

        deal(currentUser, 1 ether);
        vm.startPrank(currentUser);
        _;
        vm.stopPrank();
    }

    function mintNft(uint256 _quantity, uint256 _userIndexSeed) external useUser(_userIndexSeed) {
        mintCalled++;

        // We set a limit on the limit to mint per tx so that more function
        // calls can happen before total supply is reached.
        _quantity = bound(_quantity, 1, 10);

        // All NFTs have been minted
        if (vin.getTotalSupply() == (nftsMinted - nftsBurned)) return;

        // NFT(s) to mint will exceed total supply
        if ((nftsMinted - nftsBurned) + _quantity > vin.getTotalSupply()) return;

        uint256 mintPrice = vin.getMintPrice();
        uint256 totalCost = mintPrice * _quantity;

        usdc.mint(currentUser, totalCost);
        usdc.approve(address(vin), totalCost);

        uint256 startingTokenId = vin.getLatestTokenId();
        vin.safeMultiMintWithStableCoin(_quantity);

        // We add the token IDs of the NFTs minted to an array so that
        // we can pass it into the redeem function below
        for (uint256 i = 0; i < _quantity; ++i) {
            // i + 1 as token IDs start at 1
            nftsOwned[currentUser].push(startingTokenId + i + 1);
        }

        // Extra ghost variables for logging
        nftsOwnedCount[currentUser] += _quantity;
        nftsMinted += _quantity;
    }

    function redeemNft(uint256 _userIndexSeed) external useUser(_userIndexSeed) {
        redeemCalled++;

        // Nothing to redeem
        if (vin.balanceOf(currentUser) == 0) return;

        uint256[] memory nftsToRedeem = nftsOwned[currentUser];

        vin.multiApprove(nftsToRedeem);
        vin.multiRedeem(nftsToRedeem);

        // Reset the values as all NFTs owned by the user are redeemed
        nftsOwned[currentUser] = new uint256[](0);
        nftsOwnedCount[currentUser] = 0;

        nftsRedeemed += nftsToRedeem.length;
    }

    function adminMintAndBurn(uint256 _quantity) external {
        adminMintAndBurnCalled++;

        _quantity = bound(_quantity, 1, 3);

        if (vin.getTotalSupply() == (nftsMinted - nftsBurned)) return;

        if ((nftsMinted - nftsBurned) + _quantity > vin.getTotalSupply()) return;

        address admin = vin.getMultiSig();

        vm.prank(admin);
        vin.safeMultiMintAndBurnForAdmin(_quantity);

        nftsMinted += _quantity;
        nftsBurned += _quantity;
    }
}
