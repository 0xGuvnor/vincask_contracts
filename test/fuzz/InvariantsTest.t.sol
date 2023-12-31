// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/StdInvariant.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../script/DeployVinCask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/VinCask.sol";
import "../../src/VinCaskX.sol";
import "../../src/mocks/UsdcMock.sol";
import "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    using Strings for uint256;

    DeployVinCask deployer;
    VinCask vin;
    VinCaskX vinX;
    HelperConfig config;
    address usdcAddr;
    UsdcMock usdc;
    Handler handler;

    uint256 public constant NUM_OF_USERS = 10;

    address[] public users;

    function setUp() external {
        deployer = new DeployVinCask();
        (vin, vinX, config) = deployer.run();

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            // create random test users
            users.push(makeAddr(i.toString()));
        }

        handler = new Handler(vin, vinX, users);
        targetContract(address(handler));
    }

    function invariant_SumOfAllMintsIsLessThanOrEqualToTotalSupply() external {
        uint256 totalSupply = vin.getTotalSupply();
        uint256 netNftsMinted = handler.nftsMinted() - handler.nftsBurned();
        uint256 circulatingSupply = vin.getCirculatingSupply();
        uint256 maxCirculatingSupply = vin.getMaxCirculatingSupply();
        uint256 vinXMinted;

        console.log("Total supply:                            ", totalSupply);
        console.log("Circulating supply:                      ", circulatingSupply);
        console.log("Max circulating supply:                  ", maxCirculatingSupply, "\n");

        console.log("Net NFTs minted:                         ", netNftsMinted);
        console.log("NFTs minted:                             ", handler.nftsMinted());
        console.log("NFTs burned:                             ", handler.nftsBurned());
        console.log("NFTs redeemed:                           ", handler.nftsRedeemed(), "\n");

        console.log("Times mint called:                       ", handler.mintCalled());
        console.log("Times redeem called:                     ", handler.redeemCalled());
        console.log("Times admin mint & burn called:          ", handler.adminMintAndBurnCalled());
        console.log("Times increase circulating supply called:", handler.adminIncreaseCirculatingSupplyCalled(), "\n");

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            address user = users[i];

            uint256 numOfNfts = handler.nftsOwnedCount(user);
            vinXMinted += vinX.balanceOf(user);
            console.log("User:", user, "NFT balance:", numOfNfts);
        }

        assertEq(handler.nftsRedeemed(), vinXMinted);
        assertLe(netNftsMinted, totalSupply);
    }
}
