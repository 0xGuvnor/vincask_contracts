// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/Vincask.sol";
import "../src/VincaskX.sol";
import "./HelperConfig.s.sol";

contract DeployVincask is Script {
    function run() external returns (Vincask, VincaskX, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (uint256 totalSupply, uint256 mintPrice, address usdc, address multiSig, uint96 royaltyFee, uint256 deployerKey)
        = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        VincaskX vinX = new VincaskX();
        Vincask vin = new Vincask(mintPrice, usdc, totalSupply, multiSig, royaltyFee, vinX);

        // vin.pause();
        // vin.transferOwnership(multiSig);
        // vinX.transferOwnership(address(vin));
        vm.stopBroadcast();

        return (vin, vinX, config);
    }
}
