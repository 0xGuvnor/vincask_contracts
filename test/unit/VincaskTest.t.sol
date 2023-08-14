// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DeployVincask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/Vincask.sol";
import "../../src/VincaskX.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract VincaskTest is Test {
    Vincask vin;
    VincaskX vinX;
    HelperConfig config;
    uint256 totalSupply;
    uint256 mintPrice;
    address usdcAddr;
    address multiSig;
    uint96 royaltyFee;
    ERC20Mock public usdc;

    address public USER = makeAddr("user");

    function setUp() external {
        DeployVincask deployer = new DeployVincask();
        (vin, vinX, config) = deployer.run();
        (totalSupply, mintPrice, usdcAddr, multiSig, royaltyFee,) = config.activeNetworkConfig();
        usdc = ERC20Mock(usdcAddr);

        usdc.mint(USER, 100_000 ether);
    }

    function test_CanMintSingleNft() external {
        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithUsdc(1);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        assertEq(vin.balanceOf(USER), 1);
        assertEq(vin.ownerOf(1), USER);
        assertEq(startingUsdcBalance, endingUsdcBalance + mintPrice);
    }

    function test_CanMintMultipleNfts() external {
        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * 3);
        vin.safeMultiMintWithUsdc(3);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        assertEq(vin.balanceOf(USER), 3);
        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.ownerOf(2), USER);
        assertEq(vin.ownerOf(3), USER);
        assertEq(startingUsdcBalance, endingUsdcBalance + (mintPrice * 3));
    }
}
