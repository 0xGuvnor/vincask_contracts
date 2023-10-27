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
    uint256 maxCirculatingSupply;
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
        (maxCirculatingSupply, totalSupply, mintPrice, usdcAddr, multiSig, royaltyFee,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);
        admin = vin.owner();

        if (vin.paused()) {
            vm.prank(admin);
            vin.unpause();
        }

        // We start off our test users with 100K of USDC
        usdc.mint(USER, 100_000e6);
        usdc.mint(USER2, 100_000e6);
        usdc.mint(CROSSMINT, 100_000e6);
    }

    function test_CanMintSingleNft() external {
        uint256 startingUserBalance = usdc.balanceOf(USER);
        uint256 startingMultisigBalance = usdc.balanceOf(multiSig);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * 1);
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        uint256 endingUserBalance = usdc.balanceOf(USER);
        uint256 endingMultisigBalance = usdc.balanceOf(multiSig);

        assertEq(vin.balanceOf(USER), 1);
        assertEq(vin.ownerOf(1), USER);
        assertEq(vin.getCirculatingSupply(), 1);
        assertEq(startingUserBalance, endingUserBalance + mintPrice);
        assertEq(startingMultisigBalance + mintPrice, endingMultisigBalance);

        assertEq(multiSig, vin.getMultiSig()); // Calling getMultiSig() here to get it included in test coverage results
    }

    function test_CanMintMultipleNfts(uint256 _quantity) external {
        _quantity = bound(_quantity, 2, vin.getMaxCirculatingSupply());
        // We mint additional USDC to be able to afford the NFT minting
        usdc.mint(USER, _quantity * mintPrice);

        uint256 startingUserBalance = usdc.balanceOf(USER);
        uint256 startingMultisigBalance = usdc.balanceOf(multiSig);

        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * _quantity);
        vin.safeMultiMintWithStableCoin(_quantity);
        vm.stopPrank();

        uint256 endingUserBalance = usdc.balanceOf(USER);
        uint256 endingMultisigBalance = usdc.balanceOf(multiSig);

        for (uint256 i = 1; i <= _quantity; ++i) {
            assertEq(vin.ownerOf(i), USER);
        }
        assertEq(vin.balanceOf(USER), _quantity);
        assertEq(vin.getCirculatingSupply(), _quantity);
        assertEq(startingUserBalance, endingUserBalance + (mintPrice * _quantity));
        assertEq(startingMultisigBalance + (mintPrice * _quantity), endingMultisigBalance);
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

    function test_CanMintUpToTotalSupply() external {
        vm.prank(admin);
        vin.increaseCirculatingSupply(totalSupply);

        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * totalSupply);
        usdc.approve(address(vin), mintPrice * totalSupply);

        vin.safeMultiMintWithStableCoin(totalSupply);
        vm.stopPrank();

        assertEq(vin.getCirculatingSupply(), vin.getTotalSupply());
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
        _quantity = bound(_quantity, 1, vin.getMaxCirculatingSupply());
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
        assertEq(vin.getCirculatingSupply(), _quantity);
        // Mint price of 10 USDC used for Crossmint dev environment
        assertEq(startingMultiSigBalance + (10e6 * _quantity), endingMultiSigBalance);
    }

    function test_AdminMintAndBurnReducesSupply(uint256 _quantity) external {
        uint256 initialTokenId = vin.getLatestTokenId();
        uint256 initialTotalSupply = vin.getTotalSupply();

        _quantity = bound(_quantity, 1, vin.getMaxCirculatingSupply());

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

        // NFTs minted in userMint modifier belong to USER, so we use USER2 to test as another user
        vm.startPrank(USER2);
        vm.expectRevert("ERC721: approve caller is not token owner or approved for all");
        vin.multiApprove(tokenIdArray);

        vm.expectRevert(IVinCask.VinCask__CallerNotAuthorised.selector);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();
    }

    function test_RedeemedNftHasSameTokenId() external userMint(4) {
        vm.prank(admin);
        vin.openRedemption();

        // Users who redeem a VIN NFT will receive a VIN-X NFT in return

        // User has 4 NFTs, but we redeem only token IDs 2 & 4 to prove
        // that newly minted VIN-X token IDs are based on which VIN
        // token ID was redeemed from, instead of incrementing sequentially.
        uint256[] memory tokenIdArray = new uint256[](2);
        tokenIdArray[0] = 2;
        tokenIdArray[1] = 4;

        vm.startPrank(USER);
        vin.multiApprove(tokenIdArray);
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        assertEq(vinX.ownerOf(2), USER);
        assertEq(vinX.ownerOf(4), USER);

        vm.expectRevert("ERC721: invalid token ID"); // VIN #2 NFT has been successfully burned
        vin.ownerOf(2);
        vm.expectRevert("ERC721: invalid token ID"); // VIN #4 NFT has been successfully burned
        vin.ownerOf(4);

        vm.expectRevert("ERC721: invalid token ID"); // Check that VIN-X token ID 1 has not been minted
        vinX.ownerOf(1);
        vm.expectRevert("ERC721: invalid token ID"); // Check that VIN-X token ID 3 has not been minted
        vinX.ownerOf(3);
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

    function test_OnlyAdminCanIncreaseCirculatingSupply() external {
        uint256 startingMaxCirculatingSupply = vin.getMaxCirculatingSupply();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        vin.increaseCirculatingSupply(startingMaxCirculatingSupply + 1);

        vm.prank(admin);
        vin.increaseCirculatingSupply(startingMaxCirculatingSupply + 1);

        uint256 endingMaxCirculatingSupply = vin.getMaxCirculatingSupply();

        assertEq(startingMaxCirculatingSupply + 1, endingMaxCirculatingSupply);
    }

    function test_CannotReduceCirculatingSupply() external {
        uint256 currentMaxCirculatingSupply = vin.getMaxCirculatingSupply();

        vm.expectRevert(IVinCask.VinCask__OnlyCanIncreaseCirculatingSupply.selector);
        vm.prank(admin);
        vin.increaseCirculatingSupply(currentMaxCirculatingSupply - 1);
    }

    function test_CirculatingSupplyCannnotExceedTotalSupply() external {
        vm.expectRevert(IVinCask.VinCask__CirculatingSupplyExceedsTotalSupply.selector);
        vm.prank(admin);
        vin.increaseCirculatingSupply(totalSupply + 1);
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

    function test_CanOnlySetValidWhiteListAddress() external {
        vm.startPrank(admin);
        vm.expectRevert(IVinCask.VinCask__InvalidAddress.selector);
        vin.setWhitelistAddress(address(0), 1);

        vm.expectRevert(IVinCask.VinCask__MustMintAtLeastOne.selector);
        vin.setWhitelistAddress(USER, 0);
        vm.stopPrank();
    }

    function test_OnlyWhitelistedAddressCanMintForFree() external {
        vm.prank(USER);
        vm.expectRevert(IVinCask.VinCask__AddressNotWhitelisted.selector);
        vin.safeMultiMintForWhitelist(1);

        vm.prank(admin);
        vin.setWhitelistAddress(USER2, 2);

        uint256 startingBalance = usdc.balanceOf(USER2);
        vm.prank(USER2);
        vin.safeMultiMintForWhitelist(2);
        uint256 endingBalance = usdc.balanceOf(USER2);

        (bool isWhitelisted, uint256 mintLimit, uint256 amountMinted) = vin.getWhitelistDetails(USER2);

        assertEq(isWhitelisted, true);
        assertEq(mintLimit, 2);
        assertEq(amountMinted, 2);
        assertEq(vin.getWhitelistAddresses()[0], USER2);
        assertEq(startingBalance, endingBalance);
        assertEq(vin.balanceOf(USER2), 2);
    }

    function test_WhitelistedAddressesCannotMintMoreThanLimit() external {
        vm.prank(admin);
        vin.setWhitelistAddress(USER, 1);

        vm.prank(USER);
        vm.expectRevert(IVinCask.VinCask__QuantityExceedsWhitelistLimit.selector);
        vin.safeMultiMintForWhitelist(2);
    }

    function test_CannotSetWhitelistMintLimitLowerThanAmountMinted() external {
        vm.prank(admin);
        vin.setWhitelistAddress(USER, 3);

        vm.prank(USER);
        vin.safeMultiMintForWhitelist(2);

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__CannotSetMintLimitLowerThanMintedAmount.selector);
        vin.setWhitelistAddress(USER, 1);
    }

    function test_OnlyRemovesValidWhitelistedAddress() external {
        vm.startPrank(admin);

        vm.expectRevert(IVinCask.VinCask__InvalidAddress.selector);
        vin.removeWhitelistAddress(address(0));

        vm.expectRevert(IVinCask.VinCask__AddressNotWhitelisted.selector);
        vin.removeWhitelistAddress(USER);

        vm.stopPrank();
    }

    function test_SuccessfullyRemovesWhitelistAddress() external {
        vm.startPrank(admin);

        vin.setWhitelistAddress(USER, 1);
        vin.removeWhitelistAddress(USER);
        vin.setWhitelistAddress(USER2, 2);

        vm.stopPrank();

        (bool isWhitelisted, uint256 mintLimit, uint256 amountMinted) = vin.getWhitelistDetails(USER);

        assertEq(isWhitelisted, false);
        assertEq(mintLimit, 0);
        assertEq(amountMinted, 0);
        assertEq(vin.getWhitelistAddresses()[0], USER2);
        assertNotEq(vin.getWhitelistAddresses()[0], USER);
    }
}
