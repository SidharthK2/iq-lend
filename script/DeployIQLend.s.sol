//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { AdaptiveCurveIrm } from "@morpho-blue-irm/adaptive-curve-irm/AdaptiveCurveIrm.sol";
import { Constants } from "../src/Constants.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployIQLend is Script {
    function run() external returns (address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        IQLend iqLend = new IQLend(deployer);

        // Deploy IRM
        AdaptiveCurveIrm irm = new AdaptiveCurveIrm(address(iqLend));

        // Enable IRM and LLTV
        iqLend.enableIrm(address(irm));
        iqLend.enableLltv(Constants.LLTV);

        console.log("IQLend", address(iqLend));
        console.log("IRM", address(irm));
        vm.stopBroadcast();

        return (address(iqLend), address(irm));
    }
}
