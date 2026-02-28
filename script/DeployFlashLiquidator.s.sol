//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { FlashLiquidator } from "../src/FlashLiquidator.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployFlashLiquidator is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        FlashLiquidator liquidator = new FlashLiquidator(deployer);

        console.log("FlashLiquidator", address(liquidator));
        vm.stopBroadcast();

        return address(liquidator);
    }
}
