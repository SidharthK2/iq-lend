//SPDX-License-Identifier: ISC
pragma solidity >=0.8.23;

import {FraxswapOracle} from "public-frax-bamm/src/contracts/FraxswapOracle.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployFraxswapOracle is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        FraxswapOracle oracle = new FraxswapOracle();
        vm.stopBroadcast();

        console.log("FraxswapOracle deployed at:", address(oracle));
        return address(oracle);
    }
}