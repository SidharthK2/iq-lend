//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams, Id } from "morpho-blue/src/interfaces/IMorpho.sol";
import { MarketParamsLib } from "morpho-blue/src/libraries/MarketParamsLib.sol";
import { Script, console } from "forge-std/Script.sol";

contract CreateMarkets is Script {
    using MarketParamsLib for MarketParams;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        IQLend lend = IQLend(Constants.IQ_LEND);

        // Market 1: Long IQ (collateral=IQ, loan=USDC)
        MarketParams memory market1 = MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.IQ,
            oracle: Constants.IQ_ORACLE_MARKET1,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });

        // Market 2: Short IQ (collateral=USDC, loan=IQ)
        MarketParams memory market2 = MarketParams({
            loanToken: Constants.IQ,
            collateralToken: Constants.USDC,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });

        lend.createMarket(market1);
        console.log("Market 1 created");

        lend.createMarket(market2);
        console.log("Market 2 created");

        // Set caps
        lend.setCaps(market1.id(), Constants.SUPPLY_CAP, Constants.BORROW_CAP);
        lend.setCaps(market2.id(), Constants.SUPPLY_CAP, Constants.BORROW_CAP);

        vm.stopBroadcast();
    }
}
