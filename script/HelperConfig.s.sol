// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/mocks/UsdcMock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 totalSupply;
        uint256 mintPrice;
        address stableCoin;
        address multiSig;
        uint96 royaltyFee;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 public constant TOTAL_SUPPLY = 125;
    uint256 public constant MINT_PRICE = 20_000e6; // 6 decimal places for USDC
    address public constant MULTI_SIG = address(0);
    uint96 public constant ROYALTY_FEE = 500; /* 500 = 5% */
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 1) {
            // Production Mainnet config
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            // Sepolia testnet config
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 5) {
            // Goerli testnet config
            activeNetworkConfig = getGoerliConfig();
        } else {
            // Local Anvil config
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            multiSig: MULTI_SIG,
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: 0xee3a254b0810FC5de2771057D97ed1DD0a6fD330,
            multiSig: msg.sender,
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getGoerliConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: 0x98339D8C260052B7ad81c28c16C0b98420f2B46a,
            multiSig: 0x9f7b64a21c3872331B94C04756643cBdaCaeAefb,
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
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            stableCoin: address(usdcMock),
            multiSig: msg.sender,
            royaltyFee: ROYALTY_FEE,
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
