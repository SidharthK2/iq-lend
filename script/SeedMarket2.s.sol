//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

/// @notice Seeds Market 2 (short IQ) with IQ liquidity up to the supply cap.
contract SeedMarket2 is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQLend lend = IQLend(Constants.IQ_LEND);

        MarketParams memory market2 = MarketParams({
            loanToken: Constants.IQ,
            collateralToken: Constants.USDC,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });

        IERC20(Constants.IQ).approve(Constants.IQ_LEND, Constants.MARKET2_SUPPLY_CAP);
        lend.supply(market2, Constants.MARKET2_SUPPLY_CAP, 0, msg.sender, "");

        console.log("Supplied IQ to Market 2:", Constants.MARKET2_SUPPLY_CAP);

        vm.stopBroadcast();
    }
}
