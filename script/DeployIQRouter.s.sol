//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQRouter } from "../src/IQRouter.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployIQRouter is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        IQRouter router = new IQRouter(deployer);

        console.log("IQRouter", address(router));
        vm.stopBroadcast();

        return address(router);
    }
}
