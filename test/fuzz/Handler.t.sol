// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {VinCask} from "../../src/VinCask.sol";
import {VinCaskX} from "../../src/VinCaskX.sol";
import {UsdcMock} from "../../src/mocks/UsdcMock.sol";

import {Test} from "forge-std/Test.sol";

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
    uint256 public adminIncreaseMintingCapCalled;

    constructor(VinCask _vin, VinCaskX _vinX, address[] memory _users) {
        vin = _vin;
        vinX = _vinX;
        users = _users;

        usdc = UsdcMock(vin.getStableCoin());

        vm.startPrank(vin.owner());
        if (vin.paused()) {
            vin.unpause();
        }
        vin.openRedemption();
        // vin.increaseMintingCap(vin.getMaxSupply());
        vm.stopPrank();
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

        // We set a limit on the quantity to mint per tx so that more function
        // calls can happen before total supply is reached.
        // This helps distribute testing across more transactions rather than
        // using up all available supply in a few large mints.
        _quantity = bound(
            _quantity,
            1, // Minimum mint amount
            vin.getMintingCap() - vin.getTotalMintedForCap() > 10
                ? 10 // If more than 10 tokens available, cap at 10 to allow for more test transactions
                : vin.getMintingCap() - vin.getTotalMintedForCap() > 0
                    ? vin.getMintingCap() - vin.getTotalMintedForCap() // If less than 10 available, use remaining amount
                    : 1 // Return 1 instead of 0 to prevent bound() function from reverting
                // bound() requires min <= max, so we can't return 0 as the max
        );

        // All NFTs have been minted
        if (nftsMinted == vin.getMaxSupply()) return;

        // NFT(s) to mint will exceed total supply
        if (nftsMinted + _quantity > vin.getMaxSupply()) return;

        // NFT(s) to mint will exceed the minting cap
        if ((nftsMinted - nftsBurned) + _quantity > vin.getMintingCap()) return;

        // Get the mint price in 18 decimals from the contract
        uint256 mintPrice = vin.getMintPrice();
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Convert mint price from 18 decimals to USDC decimals (6)
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));
        // Calculate total cost in USDC decimals for all NFTs being minted
        uint256 totalCost = adjustedPrice * _quantity;

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

        vin.multiRedeem(nftsToRedeem);

        // Reset the values as all NFTs owned by the user are redeemed
        nftsOwned[currentUser] = new uint256[](0);
        nftsOwnedCount[currentUser] = 0;

        nftsRedeemed += nftsToRedeem.length;
    }

    function adminMintAndBurn(uint256 _quantity) external {
        adminMintAndBurnCalled++;

        // We set a limit on the quantity to mint per tx as we expect the majority
        // of the sales to come through the contract.
        _quantity = bound(_quantity, 1, 3);

        if (nftsMinted == vin.getMaxSupply()) return;

        if (nftsMinted + _quantity > vin.getMaxSupply()) return;

        if ((nftsMinted - nftsBurned) + _quantity > vin.getMintingCap()) return;

        vm.prank(vin.owner());
        vin.safeMultiMintAndBurnForAdmin(_quantity);

        nftsMinted += _quantity;
        nftsBurned += _quantity;
    }

    function adminIncreaseMintingCap(uint256 _quantity) external {
        adminIncreaseMintingCapCalled++;

        uint256 currentMintingCap = vin.getMintingCap();
        uint256 currentMaxSupply = vin.getMaxSupply();

        if (currentMintingCap >= currentMaxSupply) return;

        _quantity = bound(_quantity, currentMintingCap + 1, currentMaxSupply);

        vm.prank(vin.owner());
        vin.increaseMintingCap(_quantity);
    }
}
