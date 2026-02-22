//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";
import { MarketParamsLib } from "morpho-blue/src/libraries/MarketParamsLib.sol";
import { Script, console } from "forge-std/Script.sol";

contract SetCaps is Script {
    using MarketParamsLib for MarketParams;

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

        MarketParams memory market2 = MarketParams({
            loanToken: Constants.IQ,
            collateralToken: Constants.USDC,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });

        lend.setCaps(market1.id(), Constants.MARKET1_SUPPLY_CAP, Constants.MARKET1_BORROW_CAP);
        console.log("Market 1 caps set: supply=%d, borrow=%d", Constants.MARKET1_SUPPLY_CAP, Constants.MARKET1_BORROW_CAP);

        lend.setCaps(market2.id(), Constants.MARKET2_SUPPLY_CAP, Constants.MARKET2_BORROW_CAP);
        console.log("Market 2 caps set: supply=%d, borrow=%d", Constants.MARKET2_SUPPLY_CAP, Constants.MARKET2_BORROW_CAP);

        vm.stopBroadcast();
    }
}
