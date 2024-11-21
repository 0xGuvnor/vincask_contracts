// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {VinCask} from "../src/VinCask.sol";
import {VinCaskX} from "../src/VinCaskX.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {Script} from "forge-std/Script.sol";

contract DeployVinCask is Script {
    function run() external returns (VinCask, VinCaskX, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (
            uint256 mintingCap,
            uint256 maxSupply,
            uint256 mintPrice,
            address stableCoin,
            address multiSig,
            uint96 royaltyFee,
            uint256 deployerKey
        ) = config.activeNetworkConfig();

        /**
         * @dev Use this line when deploying using a private key from .env file.
         *      WARNING: This should only be used for testing and development.
         *      For production deployments, use a hardware wallet instead.
         */
        // vm.startBroadcast(deployerKey);

        /**
         * @dev Use this line when deploying with a hardware wallet like Ledger/Trezor.
         *      The DEPLOYER_ADDRESS should be set to your hardware wallet's address in .env
         */
        vm.startBroadcast(vm.envAddress("DEPLOYER_ADDRESS"));

        VinCaskX vinX = new VinCaskX();
        VinCask vin = new VinCask(mintPrice, stableCoin, mintingCap, maxSupply, multiSig, vinX, royaltyFee);

        vin.pause(); // Admin is to unpause the contract when minting is ready to go live
        vin.transferOwnership(multiSig);

        vinX.grantRole(vinX.MINTER_ROLE(), address(vin));
        vinX.grantRole(vinX.DEFAULT_ADMIN_ROLE(), multiSig);

        // Only renounce after ensuring multiSig has admin role
        if (vinX.hasRole(vinX.DEFAULT_ADMIN_ROLE(), multiSig)) {
            vinX.renounceRole(vinX.DEFAULT_ADMIN_ROLE(), vm.envAddress("DEPLOYER_ADDRESS")); // Comment this out if deploying with a private key from .env file
        } else {
            revert("Failed to grant admin role to multiSig");
        }

        vm.stopBroadcast();

        return (vin, vinX, config);
    }
}
