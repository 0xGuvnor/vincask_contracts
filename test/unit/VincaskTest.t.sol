// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../../script/DeployVinCask.s.sol";
import "../../script/HelperConfig.s.sol";
import "../../src/VinCask.sol";
import "../../src/VinCaskX.sol";
import "../../src/interface/IVinCask.sol";
import "../../src/mocks/UsdcMock.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VinCaskTest is Test {
    using SafeMath for uint256;
    using Strings for uint256;

    event RedemptionOpened(address indexed account);
    event RedemptionClosed(address indexed account);

    VinCask vin;
    VinCaskX vinX;
    HelperConfig config;
    uint256 totalSupply;
    uint256 mintPrice;
    address usdcAddr;
    address multiSig;
    uint96 royaltyFee;
    UsdcMock usdc;
    address admin;

    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");
    address public CROSSMINT = makeAddr("crossmint");

    function setUp() external {
        DeployVinCask deployer = new DeployVinCask();
        (vin, vinX, config) = deployer.run();
        (totalSupply, mintPrice, usdcAddr, multiSig, royaltyFee,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);
        admin = vin.owner();

        // We start off our test users with 100K of USDC
        usdc.mint(USER, 100_000e6);
        usdc.mint(USER2, 100_000e6);
        usdc.mint(CROSSMINT, 100_000e6);
    }

    function test_CanMintSingleNft() external {
        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * 1);
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        assertEq(vin.balanceOf(USER), 1);
        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.getLatestTokenId(), 1);
        assertEq(startingUsdcBalance, endingUsdcBalance + mintPrice);
        assertEq(usdc.balanceOf(vin.getMultiSig()), mintPrice);
    }

    function test_CanMintMultipleNfts(uint256 _quantity) external {
        _quantity = bound(_quantity, 2, totalSupply);
        // We mint additional USDC to be able to afford the NFT minting
        usdc.mint(USER, _quantity * mintPrice);

        uint256 startingUsdcBalance = usdc.balanceOf(USER);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * _quantity);
        vin.safeMultiMintWithStableCoin(_quantity);
        vm.stopPrank();

        uint256 endingUsdcBalance = usdc.balanceOf(USER);

        for (uint256 i = 1; i <= _quantity; ++i) {
            assertEq(vin.ownerOf(i), USER);
        }
        assertEq(vin.balanceOf(USER), _quantity);
        assertEq(vin.getLatestTokenId(), _quantity);
        assertEq(startingUsdcBalance, endingUsdcBalance + (mintPrice * _quantity));
        assertEq(usdc.balanceOf(multiSig), mintPrice * _quantity);
    }

    function test_RevertsIfNothingToMint() external {
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);

        vm.expectRevert(IVinCask.VinCask__MustMintAtLeastOne.selector);
        vin.safeMultiMintWithStableCoin(0);
        vm.stopPrank();
    }

    function test_CannotMintMoreThanTotalSupply() external {
        // We use the default total supply here instead of calling getTotalSupply() as no NFTs have been burned, so it would return the same value
        uint256 numToMint = totalSupply + 1;

        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * numToMint);
        usdc.approve(address(vin), mintPrice * numToMint);

        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithStableCoin(numToMint);
        vm.stopPrank();
    }

    function test__CanMintUpToTotalSupply() external {
        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * totalSupply);
        usdc.approve(address(vin), mintPrice * totalSupply);

        vin.safeMultiMintWithStableCoin(totalSupply);
        vm.stopPrank();

        assertEq(vin.getLatestTokenId(), vin.getTotalSupply());
        assertEq(vin.balanceOf(USER), vin.getTotalSupply());
    }

    function test_RevertsIfCannotAffordToMint() external {
        uint256 userBalance = usdc.balanceOf(USER);
        uint256 affordToMint = userBalance.div(mintPrice);
        uint256 toMint = affordToMint + 1;

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * toMint);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vin.safeMultiMintWithStableCoin(toMint);
        vm.stopPrank();
    }

    function test_CanMintWithCrossmint(uint256 _quantity) external {
        _quantity = bound(_quantity, 1, totalSupply);
        uint256 startingMultiSigBalance = usdc.balanceOf(multiSig);

        vm.startPrank(CROSSMINT);
        /* We give unlimited approval here as Crossmint initiates the approval on their end */
        usdc.approve(address(vin), UINT256_MAX);
        vin.safeMultiMintWithCreditCard(_quantity, CROSSMINT);
        vm.stopPrank();

        uint256 endingMultiSigBalance = usdc.balanceOf(multiSig);

        assertEq(vin.balanceOf(CROSSMINT), _quantity);
        for (uint256 i = 0; i < _quantity; ++i) {
            // NFT token ID starts at 1
            assertEq(vin.ownerOf(i + 1), CROSSMINT);
        }
        assertEq(vin.getLatestTokenId(), _quantity);
        // Mint price of 10 USDC used for Crossmint dev environment
        assertEq(startingMultiSigBalance + (10e6 * _quantity), endingMultiSigBalance);
    }

    function test_AdminMintAndBurnReducesSupply(uint256 _quantity) external {
        uint256 initialTokenId = vin.getLatestTokenId();
        uint256 initialTotalSupply = vin.getTotalSupply();

        _quantity = bound(_quantity, 1, initialTotalSupply);

        vm.prank(admin);
        vin.safeMultiMintAndBurnForAdmin(_quantity);

        uint256 endingTokenId = vin.getLatestTokenId();
        uint256 endingTotalSupply = vin.getTotalSupply();

        assertEq(initialTokenId + _quantity, endingTokenId);
        assertEq(initialTotalSupply - _quantity, endingTotalSupply);
    }

    modifier userMint(uint256 _quantity) {
        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * _quantity);
        usdc.approve(address(vin), mintPrice * _quantity);
        vin.safeMultiMintWithStableCoin(_quantity);
        vm.stopPrank();
        _;
    }

    function test_RedemptionIsClosedByDefault() external {
        assertEq(vin.isRedemptionOpen(), false);
    }

    function test_OnlyAdminCanOpenOrCloseRedemption() external {
        vm.startPrank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.openRedemption();

        vm.expectRevert("Ownable: caller is not the owner");
        vin.closeRedemption();
        vm.stopPrank();

        vm.startPrank(admin);
        assertEq(vin.isRedemptionOpen(), false);

        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionOpened(admin);
        vin.openRedemption();
        assertEq(vin.isRedemptionOpen(), true);

        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionClosed(admin);
        vin.closeRedemption();
        assertEq(vin.isRedemptionOpen(), false);
        vm.stopPrank();
    }

    function test_CanOnlyRedeemNftsYouOwn() external userMint(1) {
        vm.prank(admin);
        vin.openRedemption();

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        // NFTs minted in userMint modifier belong to USER, so we use USER2 to test the revert
        vm.startPrank(USER2);
        vm.expectRevert("ERC721: approve caller is not token owner or approved for all");
        vin.multiApprove(tokenIdArray);

        vm.expectRevert(IVinCask.VinCask__CallerNotAuthorised.selector);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();
    }

    function test_RedeemedNftHasSameTokenId() external userMint(3) {
        vm.prank(admin);
        vin.openRedemption();

        // Users who redeem a VIN NFT will receive a VIN-X NFT in return

        // User has 3 NFTs, but we redeem only token ID 2 to prove
        // that newly minted VIN-X token IDs are based on which VIN
        // token ID was redeemed from, instead of incremeting sequentially.
        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 2;

        vm.startPrank(USER);
        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        assertEq(vinX.ownerOf(2), USER);
        assertNotEq(vin.ownerOf(2), USER);
        assertEq(vin.ownerOf(2), multiSig);
    }

    function test_CannotApproveZero() external userMint(1) {
        uint256[] memory tokenIdArray = new uint256[](0);

        vm.prank(USER);
        vm.expectRevert(IVinCask.VinCask__MustApproveAtLeastOne.selector);
        vin.multiApprove(tokenIdArray);
    }

    function test_OnlyNftOwnerCanApprove() external userMint(1) {
        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        vm.prank(USER2);
        vm.expectRevert("ERC721: approve caller is not token owner or approved for all");
        vin.multiApprove(tokenIdArray);
    }

    function test_AdminCannotSetSameMintPrice() external {
        uint256 currentMintPrice = vin.getMintPrice();

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MustSetDifferentPrice.selector);
        vin.setMintPrice(currentMintPrice);
    }

    function test_AdminCanSetNewMintPrice() external {
        uint256 startingMintPrice = vin.getMintPrice();
        uint256 newMintPrice = startingMintPrice * 2;

        vm.prank(admin);
        vin.setMintPrice(newMintPrice);

        uint256 endingMintPrice = vin.getMintPrice();

        assertNotEq(startingMintPrice, endingMintPrice);
        assertEq(endingMintPrice, newMintPrice);
    }

    function test_AdminCannotSetSameStableCoin() external {
        address currentStableCoin = vin.getStableCoin();

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MustSetDifferentStableCoin.selector);
        vin.setStableCoin(currentStableCoin);
    }

    function test_AdminCanSetNewStableCoin() external {
        address startingStableCoin = vin.getStableCoin();
        // Arbitrary address
        address newStableCoin = address(10);

        vm.prank(admin);
        vin.setStableCoin(newStableCoin);

        address endingStableCoin = vin.getStableCoin();

        assertNotEq(startingStableCoin, endingStableCoin);
        assertEq(newStableCoin, endingStableCoin);
    }

    function test_TokenUriReturnsCorrectString() external userMint(1) {
        uint256 tokenId = vin.getLatestTokenId();

        assertEq(abi.encodePacked(vin.tokenURI(1)), abi.encodePacked("ipfs://abc/", tokenId.toString()));
    }

    function test_OwnerCanPauseAndUnpauseMinting() external {
        // Pausing mint
        vm.prank(admin);
        vin.pause();

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);

        vm.expectRevert("Pausable: paused");
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        // Unpausing mint
        vm.prank(admin);
        vin.unpause();

        vm.prank(USER);
        vin.safeMultiMintWithStableCoin(1);

        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.balanceOf(USER), 1);
    }

    function test_OnlyOwnerCanCallBurn() external userMint(1) {
        vm.prank(admin);
        vin.openRedemption();

        vm.startPrank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.burn(1);

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        // NFT gets transferred to MultiSig (admin) wallet when redeemed
        vm.prank(admin);
        vin.burn(1);

        vm.expectRevert("ERC721: invalid token ID");
        vin.ownerOf(1);
    }

    function test_OnlyOwnerCanCallMultiBurn() external userMint(4) {
        vm.prank(admin);
        vin.openRedemption();

        uint256[] memory tokenIdArray = new uint256[](4);
        for (uint256 i = 0; i < 4; ++i) {
            tokenIdArray[i] = i + 1;
        }

        vm.startPrank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.multiBurn(tokenIdArray);

        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        vm.prank(admin);
        vin.multiBurn(tokenIdArray);

        for (uint256 i = 0; i < 4; ++i) {
            vm.expectRevert("ERC721: invalid token ID");
            vin.ownerOf(i + 1);
        }
    }
}
