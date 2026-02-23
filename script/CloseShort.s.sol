//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { Script, console } from "forge-std/Script.sol";

/// @notice Closes an existing leveraged short position on IQ.
contract CloseShort is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQRouter router = IQRouter(Constants.IQ_ROUTER);
        router.closeShort(0);

        console.log("Closed short position");

        vm.stopBroadcast();
    }
}
