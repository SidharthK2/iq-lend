//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQOracle } from "../src/IQOracle.sol";
import { IFraxswapOracle } from "../src/interfaces/IFraxswapOracle.sol";
import { IFraxswapPair } from "../src/interfaces/IFraxswapPair.sol";
import { Constants } from "../src/Constants.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployIQOracle is Script {
    function run(address fraxswapOracle) external returns (address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Market 1: IQ collateral, USDC loan
        IQOracle oracleMarket1 = new IQOracle(
            deployer,
            IFraxswapOracle(fraxswapOracle),
            IFraxswapPair(Constants.FRAXSWAP_IQ_FRAX_PAIR),
            Constants.IQ,
            Constants.USDC,
            true,
            Constants.TWAP_PERIOD,
            Constants.TWAP_ROUNDS,
            Constants.MAX_DIFF_PERC
        );

        // Market 2: USDC collateral, IQ loan
        IQOracle oracleMarket2 = new IQOracle(
            deployer,
            IFraxswapOracle(fraxswapOracle),
            IFraxswapPair(Constants.FRAXSWAP_IQ_FRAX_PAIR),
            Constants.USDC,
            Constants.IQ,
            false,
            Constants.TWAP_PERIOD,
            Constants.TWAP_ROUNDS,
            Constants.MAX_DIFF_PERC
        );

        vm.stopBroadcast();

        console.log("IQOracle Market 1", address(oracleMarket1));
        console.log("IQOracle Market 2", address(oracleMarket2));

        return (address(oracleMarket1), address(oracleMarket2));
    }
}
