// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../script/DeployVinCask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/VinCask.sol";
import "../../src/VinCaskX.sol";
import "../../src/mocks/UsdcMock.sol";

contract VinCaskXTest is Test {
    using Strings for uint256;

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

        if (vin.paused()) {
            vm.prank(vin.owner());
            vin.unpause();
        }

        usdc.mint(USER, 100_000e6);
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

        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        uint256 tokenId = vin.getLatestTokenId();

        assertEq(abi.encodePacked(vinX.tokenURI(1)), abi.encodePacked("ipfs://def/", tokenId.toString()));
    }
}
