//SPDX-License-Identifier: ISC
pragma solidity >=0.8.23;

import {FraxswapOracle} from "public-frax-bamm/src/contracts/FraxswapOracle.sol";
import {Script} from "forge-std/Script.sol";

contract DeployFraxswapOracle is Script {
    function run() external {
        vm.broadcast();
        new FraxswapOracle();
    }
}
