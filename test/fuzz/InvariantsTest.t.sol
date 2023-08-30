// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/StdInvariant.sol";
import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../script/DeployVincask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/Vincask.sol";
import "../../src/VincaskX.sol";
import "../../src/mocks/UsdcMock.sol";
import "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    using Strings for uint256;

    DeployVincask deployer;
    Vincask vin;
    VincaskX vinX;
    HelperConfig config;
    address usdcAddr;
    UsdcMock usdc;
    Handler handler;

    uint256 public constant NUM_OF_USERS = 10;

    address[] public users;

    function setUp() external {
        deployer = new DeployVincask();
        (vin, vinX, config) = deployer.run();

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            users.push(makeAddr(i.toString()));
        }

        handler = new Handler(vin, vinX, users);
        targetContract(address(handler));
    }

    function invariant_SumOfAllMintsIsLessThanOrEqualToTotalSupply() external {
        uint256 totalSupply = vin.getTotalSupply();
        uint256 netNftsMinted = handler.nftsMinted() - handler.nftsBurned();

        console.log("Total supply:                  ", totalSupply);
        console.log("Net NFTs minted:               ", netNftsMinted);
        console.log("NFTs minted:                   ", handler.nftsMinted());
        console.log("NFTs burned:                   ", handler.nftsBurned());
        console.log("NFTs redeemed:                 ", handler.nftsRedeemed());

        console.log("Times mint called:             ", handler.mintCalled());
        console.log("Times redeem called:           ", handler.redeemCalled());
        console.log("Times admin mint & burn called:", handler.adminMintAndBurnCalled());

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            uint256 numOfNfts = handler.nftsOwnedCount(users[i]);
            console.log("User:", users[i], "NFT balance:", numOfNfts);
        }

        assertLe(netNftsMinted, totalSupply);
    }
}
