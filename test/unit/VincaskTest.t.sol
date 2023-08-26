// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DeployVincask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/Vincask.sol";
import "../../src/VincaskX.sol";
import "../../src/interface/IVincask.sol";
import "../../src/mocks/UsdcMock.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract VincaskTest is Test {
    using SafeMath for uint256;

    Vincask vin;
    VincaskX vinX;
    HelperConfig config;
    uint256 totalSupply;
    uint256 mintPrice;
    address usdcAddr;
    address multiSig;
    uint96 royaltyFee;
    UsdcMock public usdc;

    address public USER = makeAddr("user");

    function setUp() external {
        DeployVincask deployer = new DeployVincask();
        (vin, vinX, config) = deployer.run();
        (totalSupply, mintPrice, usdcAddr, multiSig, royaltyFee,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);

        usdc.mint(USER, 100_000e6);
    }

    function test_CanMintSingleNft() external {
        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        assertEq(vin.balanceOf(USER), 1);
        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.getLatestTokenId(), 1);
        assertEq(startingUsdcBalance, endingUsdcBalance + mintPrice);
        assertEq(usdc.balanceOf(multiSig), mintPrice);
    }

    function test_CanMintMultipleNfts() external {
        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * 3);
        vin.safeMultiMintWithStableCoin(3);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        assertEq(vin.balanceOf(USER), 3);
        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.ownerOf(2), USER);
        assertEq(vin.ownerOf(3), USER);
        assertEq(vin.getLatestTokenId(), 3);
        assertEq(startingUsdcBalance, endingUsdcBalance + (mintPrice * 3));
        assertEq(usdc.balanceOf(multiSig), mintPrice * 3);
    }

    function test_RevertsIfNothingToMint() external {
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);

        vm.expectRevert(IVincask.Vincask__MustMintAtLeastOne.selector);
        vin.safeMultiMintWithStableCoin(0);
        vm.stopPrank();
    }

    function test_CannotMintMoreThanTotalSupply() external {
        // We use the default total supply here instead of calling getTotalSupply as no NFTs have been burned, so it would return the same value
        uint256 numToMint = totalSupply + 1;

        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * numToMint);
        usdc.approve(address(vin), mintPrice * numToMint);

        vm.expectRevert(IVincask.Vincask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithStableCoin(numToMint);
        vm.stopPrank();
    }

    function test__CanMintUpToTotalSupply() external {
        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * totalSupply);
        usdc.approve(address(vin), mintPrice * totalSupply);

        vin.safeMultiMintWithStableCoin(totalSupply);
        vm.stopPrank();
    }

    function test_RevertsIfCantAffordToMint() external {
        uint256 userBalance = usdc.balanceOf(USER);
        uint256 affordToMint = userBalance.div(mintPrice);
        uint256 toMint = affordToMint + 1;

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * toMint);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vin.safeMultiMintWithStableCoin(toMint);
        vm.stopPrank();
    }
}
