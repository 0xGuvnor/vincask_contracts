// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {UsdcMock} from "../src/mocks/UsdcMock.sol";

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 mintingCap; // Max # of tokens that can be minted at a given time
        uint256 maxSupply; // Max supply of tokens
        uint256 mintPrice; // Price is in 18 decimals
        address stableCoin; // Address of the stablecoin contract
        address multiSig; // Address of the multi-sig wallet
        uint96 royaltyFee; // Royalty fee expressed in basis points i.e. 500 = 5%
        uint256 deployerKey; // Private key of the deployer (used for testing only!)
    }

    NetworkConfig public activeNetworkConfig;

    address public TEST_MULTI_SIG = makeAddr("testMultiSig");

    uint256 public constant MINTING_CAP = 10;
    uint256 public constant MAX_SUPPLY = 125;
    uint256 public constant MINT_PRICE = 20_000e18; /* Price is in 18 decimals */
    address public constant MULTI_SIG = address(10); // ⚠️ Placeholder address, to update before Mainnet deployment ⚠️
    uint96 public constant ROYALTY_FEE = 500; /* Expressed in basis points i.e. 500 = 5% */
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        require(ROYALTY_FEE <= 10000, "Royalty fee cannot exceed 100%");
        require(MINT_PRICE > 0, "Mint price must be greater than 0");
        require(MAX_SUPPLY > 0, "Max supply must be greater than 0");
        require(MINTING_CAP <= MAX_SUPPLY, "Minting cap cannot exceed max supply");

        if (block.chainid == 1) {
            // Production Mainnet config
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            // Sepolia testnet config
            activeNetworkConfig = getSepoliaConfig();
        } else {
            // Local Anvil config
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            mintingCap: MINTING_CAP,
            maxSupply: MAX_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // Actual USDC address
            multiSig: MULTI_SIG,
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            mintingCap: MINTING_CAP,
            maxSupply: MAX_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: 0xa4Eb0D6f240F6F7BA3561Fc2a118B27C4438F7ed, // Deployed UsdcMock from src/mocks/UsdcMock.sol
            multiSig: 0xe8dD2e445646DB4a94Ad298BD0CdA43f64BeD151, /* Deployer testing (EOA) wallet */
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.stableCoin != address(0)) {
            return activeNetworkConfig;
        }

        vm.broadcast();
        UsdcMock usdcMock = new UsdcMock();

        return NetworkConfig({
            mintingCap: MINTING_CAP,
            maxSupply: MAX_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: address(usdcMock),
            multiSig: TEST_MULTI_SIG,
            royaltyFee: ROYALTY_FEE,
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
