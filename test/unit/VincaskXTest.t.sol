// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DeployVinCask} from "../../script/DeployVinCask.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VinCask} from "../../src/VinCask.sol";
import {VinCaskX} from "../../src/VinCaskX.sol";
import {UsdcMock} from "../../src/mocks/UsdcMock.sol";

import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract VinCaskXTest is Test {
    using Strings for uint256;

    VinCask vin;
    VinCaskX vinX;
    HelperConfig config;
    uint256 mintPrice;
    address usdcAddr;
    address multiSig;
    UsdcMock usdc;

    address public USER = makeAddr("user");

    function setUp() external {
        DeployVinCask deployer = new DeployVinCask();
        (vin, vinX, config) = deployer.run();
        (,, mintPrice, usdcAddr, multiSig,,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);

        if (vin.paused()) {
            vm.prank(vin.owner());
            vin.unpause();
        }

        usdc.mint(USER, 100_000 * (10 ** usdc.decimals()));
    }

    function test_InitialState() external {
        assertEq(vinX.name(), "VinCask-X", "VinCaskX name should be 'VinCask-X'");
        assertEq(vinX.symbol(), "VIN-X", "VinCaskX symbol should be 'VIN-X'");

        assertTrue(vinX.hasRole(vinX.DEFAULT_ADMIN_ROLE(), multiSig), "MultiSig should have admin role");
        assertTrue(vinX.hasRole(vinX.MINTER_ROLE(), address(vin)), "VinCask should have minter role");
        assertFalse(
            vinX.hasRole(vinX.DEFAULT_ADMIN_ROLE(), vm.envAddress("DEPLOYER_ADDRESS")),
            "Deployer should not have admin role"
        );
    }

    function test_VinXTokenUriReturnsCorrectString() external {
        vm.prank(vin.owner());
        vin.openRedemption();

        // Simulating a user minting and redeeming an NFT
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithStableCoin(1);

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        uint256 tokenId = vin.getLatestTokenId();

        assertEq(
            abi.encodePacked(vinX.tokenURI(1)),
            abi.encodePacked("ipfs://def/", tokenId.toString()),
            "TokenURI should match expected format"
        );
    }

    function test_OnlyMinterCanMint() external {
        vm.prank(USER);
        vm.expectRevert();
        vinX.safeMint(USER, 1);
    }

    function test_MintingIncrementsBalance() external {
        vm.prank(vin.owner());
        vin.openRedemption();

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithStableCoin(1);

        assertEq(vinX.balanceOf(USER), 0, "Initial balance should be 0");

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;
        vin.multiRedeem(tokenIdArray);

        assertEq(vinX.balanceOf(USER), 1, "Balance should be 1 after minting");
        vm.stopPrank();
    }

    function test_OwnerOfMintedToken() external {
        vm.prank(vin.owner());
        vin.openRedemption();

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithStableCoin(1);

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        assertEq(vinX.ownerOf(1), USER, "USER should be the owner of token ID 1");
    }

    function test_SupportsExpectedInterfaces() external {
        assertTrue(vinX.supportsInterface(type(IERC721).interfaceId), "Contract should support IERC721 interface");
        assertTrue(
            vinX.supportsInterface(type(IAccessControl).interfaceId), "Contract should support IAccessControl interface"
        );
    }
}
