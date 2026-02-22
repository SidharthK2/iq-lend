//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

contract SeedLiquidity is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQLend lend = IQLend(Constants.IQ_LEND);

        MarketParams memory market1 = MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.IQ,
            oracle: Constants.IQ_ORACLE_MARKET1,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });

        IERC20(Constants.USDC).approve(Constants.IQ_LEND, Constants.MARKET1_SUPPLY_CAP);
        lend.supply(market1, Constants.MARKET1_SUPPLY_CAP, 0, msg.sender, "");

        console.log("Supplied USDC to Market 1");

        vm.stopBroadcast();
    }
}
