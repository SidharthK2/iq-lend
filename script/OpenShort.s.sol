//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

/// @notice Opens a leveraged short position on IQ.
contract OpenShort is Script {
    function run() external {
        uint256 usdcAmount = 3e6; // 3 USDC seed
        uint256 leverage = 2e18; // 2x leverage

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQRouter router = IQRouter(Constants.IQ_ROUTER);

        IERC20(Constants.USDC).approve(address(router), usdcAmount);

        // Authorization should already be set. Uncomment if first time:
        // IQLend(Constants.IQ_LEND).setAuthorization(address(router), true);

        router.openShort(usdcAmount, leverage, 0);

        console.log("Opened short with USDC:", usdcAmount);

        vm.stopBroadcast();
    }
}
