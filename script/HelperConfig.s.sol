// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 totalSupply;
        uint256 mintPrice;
        address usdc;
        address multiSig;
        uint96 royaltyFee;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 public constant TOTAL_SUPPLY = 125;
    uint256 public constant MINT_PRICE = 20_000 ether;
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

    function getMainnetConfig() public view returns (NetworkConfig memory) {}

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            usdc: 0xe0f8792e4521706ddEfdBFad1a4785257e83d17E,
            multiSig: msg.sender,
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getGoerliConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            usdc: 0x13Fb0f5445E75425dE69d974f5614a2EFc332eC3,
            multiSig: msg.sender,
            royaltyFee: ROYALTY_FEE,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.usdc != address(0)) {
            return activeNetworkConfig;
        }

        vm.broadcast();
        ERC20Mock usdcMock = new ERC20Mock();

        return NetworkConfig({
            totalSupply: TOTAL_SUPPLY,
            mintPrice: MINT_PRICE,
            usdc: address(usdcMock),
            multiSig: msg.sender,
            royaltyFee: ROYALTY_FEE,
            deployerKey: ANVIL_PRIVATE_KEY
        });
    }
}
