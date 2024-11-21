// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DeployVinCask} from "../../script/DeployVinCask.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VinCask} from "../../src/VinCask.sol";
import {VinCaskX} from "../../src/VinCaskX.sol";
import {UsdcMock} from "../../src/mocks/UsdcMock.sol";
import {Handler} from "./Handler.t.sol";

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

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

    function invariant_TokenSupplyAndBalanceTrackingIsValid() external {
        uint256 maxSupply = vin.getMaxSupply();
        uint256 netNftsMinted = handler.nftsMinted() - handler.nftsBurned();
        uint256 totalMintedForCap = vin.getTotalMintedForCap();
        uint256 mintingCap = vin.getMintingCap();
        uint256 vinXMinted;
        uint256 totalUserBalance;

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            address user = users[i];

            uint256 numOfNfts = handler.nftsOwnedCount(user);
            vinXMinted += vinX.balanceOf(user);
            console.log("User:", user, "NFT balance:", numOfNfts);
        }

        assertLe(totalMintedForCap, mintingCap, "Total minted exceeds minting cap");
        assertEq(handler.nftsRedeemed(), vinXMinted, "NFTs redeemed does not match VIN-X balance");
        assertLe(handler.nftsMinted(), maxSupply, "Total minted exceeds max supply");

        uint256 contractTotalSupply = vin.totalSupply();
        uint256 handlerNetSupply = handler.nftsMinted() - handler.nftsBurned() - handler.nftsRedeemed();
        assertEq(contractTotalSupply, handlerNetSupply, "Supply tracking mismatched");

        for (uint256 i = 0; i < NUM_OF_USERS; ++i) {
            address user = users[i];
            totalUserBalance += handler.nftsOwnedCount(user);
        }

        assertEq(totalUserBalance, contractTotalSupply, "Sum of balances doesn't match total supply");

        console.log("\n");
        console.log("Total supply:                            ", maxSupply);
        console.log("Total minted through contract:           ", totalMintedForCap);
        console.log("Minting cap:                             ", mintingCap, "\n");

        console.log("Net NFTs minted:                         ", netNftsMinted);
        console.log("NFTs minted (includes offline sales):    ", handler.nftsMinted());
        console.log("NFTs burned (offline sales):             ", handler.nftsBurned());
        console.log("NFTs redeemed:                           ", handler.nftsRedeemed(), "\n");

        console.log("Contract supply:                         ", contractTotalSupply);
        console.log("Handler supply:                          ", handlerNetSupply, "\n");

        console.log("Total supply:                            ", totalUserBalance);
        console.log("Total user balance:                      ", totalUserBalance, "\n");

        console.log("Times mint called:                       ", handler.mintCalled());
        console.log("Times redeem called:                     ", handler.redeemCalled());
        console.log("Times admin mint & burn called:          ", handler.adminMintAndBurnCalled());
        console.log("Times increase minting cap called:       ", handler.adminIncreaseMintingCapCalled(), "\n");
    }
}
