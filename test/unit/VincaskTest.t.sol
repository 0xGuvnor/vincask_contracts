// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DeployVinCask} from "../../script/DeployVinCask.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VinCask} from "../../src/VinCask.sol";
import {VinCaskX} from "../../src/VinCaskX.sol";
import {IVinCask} from "../../src/interface/IVinCask.sol";
import {UsdcMock} from "../../src/mocks/UsdcMock.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract VinCaskTest is Test {
    using SafeMath for uint256;
    using Strings for uint256;

    event Minted(address account, uint256 indexed price, uint256 indexed quantity, IVinCask.MintType indexed mintType);
    event Redeemed(address indexed account, uint256 indexed quantity);
    event DirectSale(uint256 indexed quantity);
    event RedemptionOpened(address indexed account);
    event RedemptionClosed(address indexed account);
    event MintingCapIncreased(address indexed account, uint256 indexed oldCap, uint256 indexed newCap);
    event MintPriceUpdated(address indexed account, uint256 indexed oldPrice, uint256 indexed newPrice);
    event StableCoinUpdated(address indexed account, address indexed oldCoin, address indexed newCoin);
    event WhitelistAddressAdded(address indexed account, address indexed whitelistAddress, uint256 indexed mintLimit);
    event WhitelistAddressRemoved(address indexed account, address indexed whitelistAddress);
    event MultiSigUpdated(address indexed account, address indexed oldMultiSig, address indexed newMultiSig);
    event CrossmintAddressUpdated(address indexed account, address indexed oldAddress, address indexed newAddress);
    event RoyaltyUpdated(address indexed account, address indexed receiver, uint96 indexed feeNumerator);
    event BaseURIUpdated(address indexed account, string oldURI, string newURI);

    VinCask vin;
    VinCaskX vinX;
    HelperConfig config;
    uint256 mintingCap;
    uint256 maxSupply;
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
        (mintingCap, maxSupply, mintPrice, usdcAddr, multiSig, royaltyFee,) = config.activeNetworkConfig();
        usdc = UsdcMock(usdcAddr);
        admin = vin.owner();

        if (vin.paused()) {
            // We start our testing with having the minting state unpaused

            // As we are using OZ's Pausable implementation only for
            // safeMultiMintWithStableCoin, safeMultiMintWithCreditCard and multiRedeem,
            // we can rely on the whenNotPaused modifier to work as intended.
            vm.prank(admin);
            vin.unpause();
        }

        // Set the Crossmint address to the predefined CROSSMINT address
        vm.prank(admin);
        vin.setCrossmintAddress(CROSSMINT);

        // We start off our test users with 100K of USDC
        usdc.mint(USER, 100_000e6);
        usdc.mint(USER2, 100_000e6);
    }

    function test_CanMintSingleNft() external {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        uint256 startingUserBalance = usdc.balanceOf(USER);
        uint256 startingMultisigBalance = usdc.balanceOf(multiSig);

        vm.startPrank(USER);

        usdc.approve(address(vin), adjustedPrice);

        vm.expectEmit(true, true, true, true, address(vin));
        emit Minted(USER, mintPrice, 1, IVinCask.MintType.STABLECOIN);
        vin.safeMultiMintWithStableCoin(1);

        vm.stopPrank();

        uint256 endingUserBalance = usdc.balanceOf(USER);
        uint256 endingMultisigBalance = usdc.balanceOf(multiSig);

        assertEq(vin.balanceOf(USER), 1, "User should own exactly 1 NFT");
        assertEq(vin.ownerOf(1), USER, "User should be the owner of token ID 1");
        assertEq(vin.getTotalMintedForCap(), 1, "Total minted count should be 1");
        assertEq(startingUserBalance, endingUserBalance + adjustedPrice, "User balance should be reduced by mint price");
        assertEq(startingMultisigBalance + adjustedPrice, endingMultisigBalance, "MultiSig should receive mint payment");
    }

    function test_CanMintMultipleNfts(uint256 _quantity) external {
        _quantity = bound(_quantity, 2, vin.getMintingCap());

        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));
        // We mint additional USDC to be able to afford the NFT minting
        usdc.mint(USER, _quantity * adjustedPrice);

        uint256 startingUserBalance = usdc.balanceOf(USER);
        uint256 startingMultisigBalance = usdc.balanceOf(multiSig);

        vm.startPrank(USER);

        usdc.approve(address(vin), adjustedPrice * _quantity);

        vm.expectEmit(true, true, true, true, address(vin));
        emit Minted(USER, mintPrice, _quantity, IVinCask.MintType.STABLECOIN);
        vin.safeMultiMintWithStableCoin(_quantity);

        vm.stopPrank();

        uint256 endingUserBalance = usdc.balanceOf(USER);
        uint256 endingMultisigBalance = usdc.balanceOf(multiSig);

        for (uint256 i = 1; i <= _quantity; ++i) {
            assertEq(vin.ownerOf(i), USER, string.concat("User should own token ID ", i.toString()));
        }
        assertEq(vin.balanceOf(USER), _quantity, "User's balance should match minted quantity");
        assertEq(vin.getTotalMintedForCap(), _quantity, "Total minted count should match quantity");
        assertEq(
            startingUserBalance,
            endingUserBalance + (adjustedPrice * _quantity),
            "User balance should be reduced by total mint cost"
        );
        assertEq(
            startingMultisigBalance + (adjustedPrice * _quantity),
            endingMultisigBalance,
            "MultiSig should receive total mint payment"
        );
    }

    function test_RevertsIfNothingToMint() external {
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice);

        vm.expectRevert(IVinCask.VinCask__MustMintAtLeastOne.selector);
        vin.safeMultiMintWithStableCoin(0);
        vm.stopPrank();
    }

    function test_CannotMintMoreThanMaxSupply() external {
        uint256 numToMint = maxSupply + 1;

        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        vm.startPrank(USER);
        usdc.mint(USER, adjustedPrice * numToMint);
        usdc.approve(address(vin), adjustedPrice * numToMint);

        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithStableCoin(numToMint);
        vm.stopPrank();
    }

    function test_CanMintUpToTotalSupply() external {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        vm.expectEmit(true, true, true, true, address(vin));
        emit MintingCapIncreased(admin, mintingCap, maxSupply);
        vm.prank(admin);
        vin.increaseMintingCap(maxSupply);

        vm.startPrank(USER);
        // Mint enough USDC to the user
        usdc.mint(USER, adjustedPrice * maxSupply);
        // Approve the adjusted amount
        usdc.approve(address(vin), adjustedPrice * maxSupply);

        vm.expectEmit(true, true, true, true, address(vin));
        emit Minted(USER, mintPrice, maxSupply, IVinCask.MintType.STABLECOIN);
        vin.safeMultiMintWithStableCoin(maxSupply);
        vm.stopPrank();

        assertEq(vin.getTotalMintedForCap(), vin.getMaxSupply(), "Total minted should equal max supply");
        assertEq(vin.balanceOf(USER), vin.getMaxSupply(), "User should own all tokens");
    }

    function test_RevertsIfCannotAffordToMint() external {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        uint256 userBalance = usdc.balanceOf(USER);
        uint256 affordToMint = userBalance / adjustedPrice;
        uint256 toMint = affordToMint + 1;

        vm.startPrank(USER);
        usdc.approve(address(vin), adjustedPrice * toMint);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vin.safeMultiMintWithStableCoin(toMint);
        vm.stopPrank();
    }

    function test_CanUpdateCrossmintAddress() external {
        address newCrossmintAddress = address(20);

        vm.expectEmit(true, true, true, true, address(vin));
        emit CrossmintAddressUpdated(admin, CROSSMINT, newCrossmintAddress);

        vm.prank(admin);
        vin.setCrossmintAddress(newCrossmintAddress);

        assertEq(vin.getCrossmintAddress(), newCrossmintAddress, "Crossmint address should be updated");
    }

    function test_CannotSetInvalidCrossmintAddress() external {
        vm.startPrank(admin);

        vm.expectRevert(IVinCask.VinCask__InvalidAddress.selector);
        vin.setCrossmintAddress(address(0));

        vm.expectRevert(IVinCask.VinCask__MustSetDifferentAddress.selector);
        vin.setCrossmintAddress(CROSSMINT);

        vm.stopPrank();
    }

    function test_CanMintWithCrossmint(uint256 _quantity) external {
        _quantity = bound(_quantity, 1, vin.getMintingCap());

        // Check initial state
        assertEq(vin.balanceOf(USER2), 0, "Initial balance should be zero");
        assertEq(vin.getTotalMintedForCap(), 0, "Initial total minted should be zero");

        // Expect the Minted event with correct parameters
        vm.expectEmit(true, true, true, true, address(vin));
        emit Minted(USER2, 0, _quantity, IVinCask.MintType.CREDIT_CARD);

        // Perform mint
        vm.prank(CROSSMINT);
        vin.safeMultiMintWithCreditCard(_quantity, USER2);

        // Verify final state
        assertEq(vin.balanceOf(USER2), _quantity, "Recipient should receive correct number of tokens");
        for (uint256 i = 1; i <= _quantity; ++i) {
            assertEq(vin.ownerOf(i), USER2, string.concat("Recipient should own token ID ", i.toString()));
        }
        assertEq(vin.getTotalMintedForCap(), _quantity, "Total minted should match quantity");
    }

    modifier userMint(uint256 _quantity) {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        vm.startPrank(USER);

        usdc.mint(USER, adjustedPrice * _quantity);
        usdc.approve(address(vin), adjustedPrice * _quantity);
        vin.safeMultiMintWithStableCoin(_quantity);

        vm.stopPrank();
        _;
    }

    function test_RedemptionIsClosedByDefault() external {
        assertEq(vin.isRedemptionOpen(), false, "Redemption should be closed by default");
    }

    function test_OnlyAdminCanOpenOrCloseRedemption() external {
        vm.startPrank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.openRedemption();

        vm.expectRevert("Ownable: caller is not the owner");
        vin.closeRedemption();
        vm.stopPrank();

        vm.startPrank(admin);
        assertEq(vin.isRedemptionOpen(), false, "Redemption should initially be closed");

        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionOpened(admin);
        vin.openRedemption();
        assertEq(vin.isRedemptionOpen(), true, "Redemption should be open after admin opens it");

        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionClosed(admin);
        vin.closeRedemption();
        assertEq(vin.isRedemptionOpen(), false, "Redemption should be closed after admin closes it");
        vm.stopPrank();
    }

    function test_CanOnlyRedeemNftsYouOwn() external userMint(1) {
        // Setup
        vm.prank(admin);
        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionOpened(admin);
        vin.openRedemption();

        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        // Test 1: Direct redemption attempt by non-owner
        vm.prank(USER2);
        vm.expectRevert(IVinCask.VinCask__CallerNotAuthorised.selector);
        vin.multiRedeem(tokenIdArray);

        // Test 2: Verify original owner can redeem
        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(vin));
        emit Redeemed(USER, 1);
        vin.multiRedeem(tokenIdArray);

        // Verify final state
        assertEq(vin.totalSupply(), 0, "NFT should be burned after redemption");
        vm.expectRevert("ERC721: invalid token ID");
        vin.ownerOf(1);
        assertEq(vinX.ownerOf(1), USER, "Original owner should receive VIN-X token");
    }

    function test_CannotRedeemWhileRedemptionIsClosed() external userMint(1) {
        uint256[] memory tokenIdArray = new uint256[](1);
        tokenIdArray[0] = 1;

        vm.startPrank(USER);

        vm.expectRevert(IVinCask.VinCask__RedemptionNotOpen.selector);
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
        vin.multiRedeem(tokenIdArray);
        vm.stopPrank();

        assertEq(vinX.ownerOf(2), USER, "User should own VIN-X token ID 2");
        assertEq(vinX.ownerOf(4), USER, "User should own VIN-X token ID 4");

        vm.expectRevert("ERC721: invalid token ID"); // VIN #2 NFT has been successfully burned
        vin.ownerOf(2);
        vm.expectRevert("ERC721: invalid token ID"); // VIN #4 NFT has been successfully burned
        vin.ownerOf(4);

        vm.expectRevert("ERC721: invalid token ID"); // Check that VIN-X token ID 1 has not been minted
        vinX.ownerOf(1);
        vm.expectRevert("ERC721: invalid token ID"); // Check that VIN-X token ID 3 has not been minted
        vinX.ownerOf(3);
    }

    function test_OnlyAdminCanIncreaseMintingCap() external {
        uint256 startingMaxCirculatingSupply = vin.getMintingCap();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        vin.increaseMintingCap(startingMaxCirculatingSupply + 1);

        vm.prank(admin);
        vin.increaseMintingCap(startingMaxCirculatingSupply + 1);

        uint256 endingMaxCirculatingSupply = vin.getMintingCap();

        assertEq(startingMaxCirculatingSupply + 1, endingMaxCirculatingSupply, "Minting cap should increase by 1");
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

        vm.expectEmit(true, true, true, true, address(vin));
        emit MintPriceUpdated(admin, startingMintPrice, newMintPrice);

        vm.prank(admin);
        vin.setMintPrice(newMintPrice);

        uint256 endingMintPrice = vin.getMintPrice();

        assertNotEq(startingMintPrice, endingMintPrice, "Mint price should be different");
        assertEq(endingMintPrice, newMintPrice, "Mint price should match new price");
    }

    function test_AdminCannotSetSameStableCoin() external {
        address currentStableCoin = vin.getStableCoin();

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MustSetDifferentStableCoin.selector);
        vin.setStableCoin(currentStableCoin);
    }

    function test_AdminCanSetNewStableCoin() external {
        address startingStableCoin = vin.getStableCoin();
        ERC20 newStableCoin = new ERC20("RND", "Random Token");

        vm.expectEmit(true, true, true, true, address(vin));
        emit StableCoinUpdated(admin, startingStableCoin, address(newStableCoin));

        vm.prank(admin);
        vin.setStableCoin(address(newStableCoin));

        address endingStableCoin = vin.getStableCoin();

        assertNotEq(startingStableCoin, endingStableCoin, "Stablecoin address should be different");
        assertEq(address(newStableCoin), endingStableCoin, "Stablecoin should match new address");
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

        assertEq(vin.ownerOf(1), USER, "User should own token ID 1");
        assertEq(vin.balanceOf(USER), 1, "User should own exactly 1 NFT");
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

        vm.expectEmit(true, true, true, true, address(vin));
        emit WhitelistAddressAdded(admin, USER2, 2);
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

    function test_CanIncreaseWhitelistMintLimit() external {
        vm.startPrank(admin);
        // Add event check
        vm.expectEmit(true, true, true, true, address(vin));
        emit WhitelistAddressAdded(admin, USER, 3);
        vin.setWhitelistAddress(USER, 3);
        (, uint256 oldAmount,) = vin.getWhitelistDetails(USER);

        // Add event check
        vm.expectEmit(true, true, true, true, address(vin));
        emit WhitelistAddressAdded(admin, USER, 5);
        vin.setWhitelistAddress(USER, 5);
        (, uint256 newAmount,) = vin.getWhitelistDetails(USER);
        vm.stopPrank();

        assertEq(oldAmount, 3);
        assertEq(newAmount, 5);
    }

    function test_WhitelistAddressesArrayDoesNotHaveDuplicates() external {
        vm.startPrank(admin);
        vin.setWhitelistAddress(USER, 1);
        vin.setWhitelistAddress(USER, 2);

        vin.setWhitelistAddress(USER2, 1);
        vin.setWhitelistAddress(USER2, 2);
        vm.stopPrank();

        // Checks that updating a whitelisted address' mint limit doesn't push multiple
        // instances of its address into the array
        assertEq(vin.getWhitelistAddresses().length, 2);
        assertEq(vin.getWhitelistAddresses()[0], USER);
        assertEq(vin.getWhitelistAddresses()[1], USER2);
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

        vm.expectEmit(true, true, false, false, address(vin));
        emit WhitelistAddressRemoved(admin, USER);

        vin.removeWhitelistAddress(USER);
        vin.setWhitelistAddress(USER2, 2);

        vm.stopPrank();

        (bool isWhitelisted, uint256 mintLimit, uint256 amountMinted) = vin.getWhitelistDetails(USER);

        assertEq(isWhitelisted, false, "Address should no longer be whitelisted");
        assertEq(mintLimit, 0, "Mint limit should be reset to 0");
        assertEq(amountMinted, 0, "Amount minted should be reset to 0");
        assertEq(vin.getWhitelistAddresses()[0], USER2, "First whitelist address should be USER2");
        assertNotEq(vin.getWhitelistAddresses()[0], USER, "First whitelist address should not be USER");
    }

    function test_CannotMintMoreThanMintingCap() external {
        uint256 numToMint = mintingCap + 1;

        vm.startPrank(USER);
        usdc.mint(USER, mintPrice * numToMint);
        usdc.approve(address(vin), mintPrice * numToMint);

        vm.expectRevert(IVinCask.VinCask__MintingCapExceeded.selector);
        vin.safeMultiMintWithStableCoin(numToMint);
        vm.stopPrank();
    }

    function test_AdminCanIncreaseMintingCap() external {
        uint256 newMintingCap = mintingCap + 5;

        vm.expectEmit(true, true, true, true, address(vin));
        emit MintingCapIncreased(admin, mintingCap, newMintingCap);
        vm.prank(admin);
        vin.increaseMintingCap(newMintingCap);

        assertEq(vin.getMintingCap(), newMintingCap);
    }

    function test_CannotReduceMintingCap() external {
        uint256 newMintingCap = mintingCap - 1;

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__OnlyCanIncreaseMintingCap.selector);
        vin.increaseMintingCap(newMintingCap);
    }

    function test_MintingCapCannotExceedMaxSupply() external {
        uint256 newMintingCap = maxSupply + 1;

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MintingCapExceedsMaxSupply.selector);
        vin.increaseMintingCap(newMintingCap);
    }

    function test_TotalSupplyTracksCorrectly() external {
        // Mint some tokens
        vm.startPrank(USER);
        usdc.approve(address(vin), mintPrice * 2);
        vin.safeMultiMintWithStableCoin(2);
        vm.stopPrank();

        // Admin burns some tokens
        vm.prank(admin);
        vin.safeMultiMintAndBurnForAdmin(1);

        // User redeems a token
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(admin);
        vin.openRedemption();

        vm.prank(USER);
        vin.multiRedeem(tokenIds);

        // Check supply calculations
        assertEq(vin.getTotalMintedForCap(), 2, "Total minted for cap should be 2");
        assertEq(vin.totalSupply(), 1, "Total supply should be 1 after burns and redemptions");
    }

    function test_WhitelistLimitExceeded() external {
        // Add 11 addresses to exceed limit of 10
        for (uint256 i = 1; i <= 11; i++) {
            address whitelistAddr = address(uint160(i));

            if (i <= 10) {
                vm.prank(admin);
                vin.setWhitelistAddress(whitelistAddr, 1);
            } else {
                vm.prank(admin);
                vm.expectRevert(IVinCask.VinCask__WhitelistLimitExceeded.selector);
                vin.setWhitelistAddress(whitelistAddr, 1);
            }
        }
    }

    function test_CanMintUpToMaxSupply() external {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        vm.prank(admin);
        vin.increaseMintingCap(maxSupply);

        vm.startPrank(USER);
        usdc.mint(USER, adjustedPrice * maxSupply);
        usdc.approve(address(vin), adjustedPrice * maxSupply);

        vin.safeMultiMintWithStableCoin(maxSupply);
        vm.stopPrank();

        assertEq(vin.getTotalMintedForCap(), maxSupply, "Total minted should equal max supply");
        assertEq(vin.balanceOf(USER), maxSupply, "User should own all tokens");
    }

    function test_CanUpdateMultiSig() external {
        address newMultiSig = address(20);

        vm.startPrank(admin);
        vin.setMultiSig(newMultiSig);
        vm.stopPrank();

        assertEq(vin.getMultiSig(), newMultiSig);
    }

    function test_CannotSetInvalidMultiSig() external {
        vm.startPrank(admin);

        vm.expectRevert(IVinCask.VinCask__InvalidAddress.selector);
        vin.setMultiSig(address(0));

        vm.expectRevert(IVinCask.VinCask__MustSetDifferentAddress.selector);
        vin.setMultiSig(multiSig);

        vm.stopPrank();
    }

    function test_AdminMintAndBurnTracksSupplyCorrectly() external {
        // Initial state checks
        assertEq(vin.getTotalMintedForCap(), 0);
        assertEq(vin.totalSupply(), 0);

        uint256 burnAmount = 5;

        // Only admin can mint and burn
        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.safeMultiMintAndBurnForAdmin(burnAmount);

        // Admin mints and burns tokens
        vm.expectEmit(true, false, false, false, address(vin));
        emit DirectSale(burnAmount);
        vm.prank(admin);
        vin.safeMultiMintAndBurnForAdmin(burnAmount);

        // Verify supply tracking
        assertEq(vin.getTotalMintedForCap(), 0, "Total minted for cap should not include admin burns");
        assertEq(vin.totalSupply(), 0, "Total supply should be zero after admin burn");

        // Try to query a burned token
        vm.expectRevert("ERC721: invalid token ID");
        vin.ownerOf(1);

        // Verify minting cap compliance
        uint256 exceedingAmount = vin.getMintingCap() + 1;
        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MintingCapExceeded.selector);
        vin.safeMultiMintAndBurnForAdmin(exceedingAmount);
    }

    function test_RevertIfNonCrossmintCallsMint() external {
        vm.prank(USER);
        vm.expectRevert(IVinCask.VinCask__CallerNotAuthorised.selector);
        vin.safeMultiMintWithCreditCard(1, USER2);
    }

    function test_CanMintWithCrossmintToAnyAddress() external {
        address randomUser = makeAddr("random");

        vm.prank(CROSSMINT);
        vin.safeMultiMintWithCreditCard(1, randomUser);

        assertEq(vin.balanceOf(randomUser), 1);
        assertEq(vin.ownerOf(1), randomUser);
    }

    function test_CanSetDefaultRoyalty() external {
        address newReceiver = address(20);
        uint96 newFeeNumerator = 1000; // 10%

        vm.expectEmit(true, true, true, true, address(vin));
        emit RoyaltyUpdated(admin, newReceiver, newFeeNumerator);
        vm.prank(admin);
        vin.setDefaultRoyalty(newReceiver, newFeeNumerator);

        // Verify royalty info
        (address receiver, uint256 royaltyAmount) = vin.royaltyInfo(1, 10000);
        assertEq(receiver, newReceiver);
        assertEq(royaltyAmount, 1000);
    }

    function test_DecimalNormalization() external {
        // Get the number of decimals used by the USDC token
        uint256 usdcDecimals = usdc.decimals();
        // Adjust the mint price (18 decimals) to match the USDC token's decimals
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        uint256 startingBalance = usdc.balanceOf(USER);
        require(startingBalance >= adjustedPrice, "Insufficient USDC for test");

        vm.startPrank(USER);
        usdc.approve(address(vin), adjustedPrice);
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        uint256 endingBalance = usdc.balanceOf(USER);
        uint256 actualPricePaid = startingBalance - endingBalance;

        // Verify the exact amount of USDC spent matches our adjusted calculation
        assertEq(actualPricePaid, adjustedPrice, "Incorrect USDC amount spent");

        // Verify the adjustment math
        assertEq(adjustedPrice * (10 ** (18 - usdcDecimals)), mintPrice, "Decimal adjustment calculation incorrect");
    }

    function test_GetStableCoinDecimals() external {
        // Get decimals directly from the USDC contract
        uint8 usdcDecimals = usdc.decimals();

        // Get decimals through VinCask's getter
        uint8 vinDecimals = vin.getStableCoinDecimals();

        // Verify they match
        assertEq(vinDecimals, usdcDecimals, "Stablecoin decimals should match USDC decimals");
        assertEq(vinDecimals, 6, "USDC should have 6 decimals");

        // Test that decimals update when stablecoin is changed
        ERC20 newStableCoin = new ERC20("TEST", "Test Token"); // Default 18 decimals

        vm.prank(admin);
        vin.setStableCoin(address(newStableCoin));

        assertEq(vin.getStableCoinDecimals(), 18, "Decimals should update with new stablecoin");
    }

    function test_GetVinCaskXAddress() external {
        // Get the VinCaskX address from the contract
        address vinXAddress = vin.getVinCaskXAddress();

        // Verify it matches the deployed VinCaskX contract
        assertEq(vinXAddress, address(vinX), "VinCaskX address should match deployed contract");
        assertNotEq(vinXAddress, address(0), "VinCaskX address should not be zero");
    }

    function test_BatchRedemptionWithInvalidTokenIds() external userMint(3) {
        // Open redemption
        vm.prank(admin);
        vm.expectEmit(true, false, false, false, address(vin));
        emit RedemptionOpened(admin);
        vin.openRedemption();

        // Test 1: Duplicate token IDs
        uint256[] memory duplicateTokenIds = new uint256[](2);
        duplicateTokenIds[0] = 1;
        duplicateTokenIds[1] = 1;

        vm.prank(USER);
        vm.expectRevert("ERC721: invalid token ID"); // Second burn attempt will fail
        vin.multiRedeem(duplicateTokenIds);

        // Test 2: Non-existent token IDs
        uint256[] memory nonExistentTokenIds = new uint256[](2);
        nonExistentTokenIds[0] = 999;
        nonExistentTokenIds[1] = 1000;

        vm.prank(USER);
        vm.expectRevert("ERC721: invalid token ID");
        vin.multiRedeem(nonExistentTokenIds);

        // Test 3: Mixed valid and invalid token IDs
        uint256[] memory mixedTokenIds = new uint256[](4);
        mixedTokenIds[0] = 1; // valid
        mixedTokenIds[1] = 999; // invalid
        mixedTokenIds[2] = 2; // valid
        mixedTokenIds[3] = 1; // duplicate

        vm.prank(USER);
        vm.expectRevert("ERC721: invalid token ID");
        vin.multiRedeem(mixedTokenIds);

        // Test 4: Empty array
        uint256[] memory emptyArray = new uint256[](0);

        vm.prank(USER);
        vm.expectRevert(IVinCask.VinCask__MustRedeemAtLeastOne.selector);
        vin.multiRedeem(emptyArray);

        // Test 5: Valid redemption after failed attempts
        uint256[] memory validTokenIds = new uint256[](2);
        validTokenIds[0] = 1;
        validTokenIds[1] = 2;

        vm.prank(USER);
        vm.expectEmit(true, true, false, false, address(vin));
        emit Redeemed(USER, 2);
        vin.multiRedeem(validTokenIds);

        // Verify final state
        assertEq(vinX.ownerOf(1), USER, "User should own VIN-X token ID 1");
        assertEq(vinX.ownerOf(2), USER, "User should own VIN-X token ID 2");
        vm.expectRevert("ERC721: invalid token ID");
        vin.ownerOf(1);
        vm.expectRevert("ERC721: invalid token ID");
        vin.ownerOf(2);
        assertEq(vin.ownerOf(3), USER, "User should still own unredeemed token ID 3");
    }

    function test_MaxSupplyEnforcedAcrossAllMintTypes() external {
        // First increase minting cap to allow for more online mints
        vm.prank(admin);
        vin.increaseMintingCap(maxSupply);

        // Get the number of decimals used by the USDC token and adjust price
        uint256 usdcDecimals = usdc.decimals();
        uint256 adjustedPrice = mintPrice / (10 ** (18 - usdcDecimals));

        // Setup test quantities
        uint256 regularMints = 50;
        uint256 adminMints = 50;
        uint256 remainingToMax = maxSupply - (regularMints + adminMints);

        // Regular mints through stablecoin
        vm.startPrank(USER);
        usdc.mint(USER, adjustedPrice * regularMints);
        usdc.approve(address(vin), adjustedPrice * regularMints);
        vin.safeMultiMintWithStableCoin(regularMints);
        vm.stopPrank();

        // Admin mints and burns
        vm.prank(admin);
        vin.safeMultiMintAndBurnForAdmin(adminMints);

        // Attempt to mint more than remaining supply (should fail)
        vm.startPrank(USER);
        usdc.mint(USER, adjustedPrice * (remainingToMax + 1));
        usdc.approve(address(vin), adjustedPrice * (remainingToMax + 1));
        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithStableCoin(remainingToMax + 1);
        vm.stopPrank();

        // Mint exactly up to max supply
        vm.startPrank(USER);
        usdc.approve(address(vin), adjustedPrice * remainingToMax);
        vin.safeMultiMintWithStableCoin(remainingToMax);
        vm.stopPrank();

        // Verify final state
        assertEq(vin.getLatestTokenId(), maxSupply, "Total minted should equal max supply");

        // Verify no more mints possible through any method
        vm.startPrank(USER);
        usdc.mint(USER, adjustedPrice);
        usdc.approve(address(vin), adjustedPrice);
        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithStableCoin(1);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintAndBurnForAdmin(1);

        vm.prank(CROSSMINT);
        vm.expectRevert(IVinCask.VinCask__MaxSupplyExceeded.selector);
        vin.safeMultiMintWithCreditCard(1, USER);
    }

    function test_CanSetAndGetBaseURI() external {
        string memory newBaseURI = "ipfs://newuri/";
        string memory oldURI = vin.getBaseURI();

        vm.expectEmit(true, false, false, false, address(vin));
        emit BaseURIUpdated(admin, oldURI, newBaseURI);

        vm.prank(admin);
        vin.setBaseURI(newBaseURI);

        assertEq(vin.getBaseURI(), newBaseURI, "Base URI should be updated");
    }

    function test_OnlyOwnerCanSetBaseURI() external {
        string memory newBaseURI = "ipfs://newuri/";

        vm.prank(USER);
        vm.expectRevert("Ownable: caller is not the owner");
        vin.setBaseURI(newBaseURI);
    }

    function test_CannotSetEmptyBaseURI() external {
        vm.prank(admin);
        vm.expectRevert(IVinCask.VinCask__InvalidURI.selector);
        vin.setBaseURI("");
    }

    function test_TokenUriUpdatesWithNewBaseUri() external userMint(1) {
        string memory newBaseURI = "ipfs://newuri/";
        uint256 tokenId = vin.getLatestTokenId();

        vm.prank(admin);
        vin.setBaseURI(newBaseURI);

        assertEq(
            vin.tokenURI(tokenId), string.concat(newBaseURI, tokenId.toString()), "Token URI should use new base URI"
        );
    }
}
