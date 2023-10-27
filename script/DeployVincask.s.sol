// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/VinCask.sol";
import "../src/VinCaskX.sol";
import "./HelperConfig.s.sol";

contract DeployVinCask is Script {
    function run() external returns (VinCask, VinCaskX, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (
            uint256 maxCirculatingSupply,
            uint256 totalSupply,
            uint256 mintPrice,
            address stableCoin,
            address multiSig,
            uint96 royaltyFee,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        VinCaskX vinX = new VinCaskX();
        VinCask vin = new VinCask(mintPrice, stableCoin, maxCirculatingSupply, totalSupply, multiSig, vinX, royaltyFee);

        vin.pause(); // Admin is to unpause the contract when minting is ready to go live
        vin.transferOwnership(multiSig);
        vinX.transferOwnership(address(vin));
        vm.stopBroadcast();

        return (vin, vinX, config);
    }
}
