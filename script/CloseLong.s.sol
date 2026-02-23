//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { Script, console } from "forge-std/Script.sol";

/// @notice Closes an existing leveraged long position on IQ.
contract CloseLong is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQRouter router = IQRouter(Constants.IQ_ROUTER);
        router.closeLong(0);

        console.log("Closed long position");

        vm.stopBroadcast();
    }
}
