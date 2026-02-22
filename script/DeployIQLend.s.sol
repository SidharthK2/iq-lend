//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { Script, console } from "forge-std/Script.sol";

/// @notice Deploys IQLend and enables the already-deployed IRM and LLTV.
/// @dev The AdaptiveCurveIrm is already deployed at Constants.IRM.
contract DeployIQLend is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IQLend iqLend = new IQLend(vm.addr(deployerPrivateKey));

        // Enable already-deployed IRM and LLTV
        iqLend.enableIrm(Constants.IRM);
        iqLend.enableLltv(Constants.LLTV);

        console.log("IQLend", address(iqLend));
        vm.stopBroadcast();

        return address(iqLend);
    }
}
