// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DeployVinCask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/VinCask.sol";
import "../../src/VinCaskX.sol";
import "../../src/mocks/UsdcMock.sol";

contract VinCaskXTest is Test {
    VinCask vin;
    VinCaskX vinX;
    HelperConfig config;
    uint256 mintPrice;
    address usdcAddr;
    UsdcMock usdc;

    address public USER = makeAddr("user");

    function setUp() external {
        DeployVinCask deployer = new DeployVinCask();
        (vin, vinX, config) = deployer.run();
        (, mintPrice, usdcAddr,,,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);

        usdc.mint(USER, 100_000e6);
    }

    function test_VinXTokenUriReturnsCorrectString() external {
        // Simulating a user minting and redeeming an NFT
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);
        vin.safeMultiMintWithStableCoin(1);

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;
        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        assertEq(abi.encodePacked(vinX.tokenURI(1)), abi.encodePacked("ipfs://def/1"));
    }
}
